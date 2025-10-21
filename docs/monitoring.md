# Monitoramento com Prometheus e Grafana

## Visão Geral

Stack completa de monitoramento para o projeto Fluxo de Caixa, incluindo métricas de:

- **Kubernetes**: Cluster, nodes, pods, deployments
- **Aplicação Node.js**: Requisições HTTP, latência, throughput
- **PostgreSQL**: Conexões, queries, performance
- **MetalLB**: LoadBalancer, IPs atribuídos
- **Infraestrutura**: CPU, memória, disco, rede

---

## Componentes Instalados

### Prometheus
- **Versão**: 2.48.0
- **Porta**: 9090
- **Storage**: 10Gi (retenção 15 dias)
- **Scrape Interval**: 15s

### Grafana
- **Versão**: 10.2.2
- **Porta**: 80 (via LoadBalancer)
- **Storage**: 5Gi
- **Login padrão**: admin / admin123

### Exporters
- **PostgreSQL Exporter**: 9187
- **kube-state-metrics**: 8080
- **cAdvisor**: Integrado nos nodes
- **Node Exporter**: Integrado no RKE2

### Métricas da Aplicação
- **Endpoint**: `/metrics`
- **Biblioteca**: prom-client (Node.js)
- **Métricas customizadas**: Transações, saldo, queries

---

## Instalação

### Instalação Automatizada (Recomendado)

```bash
cd ~/projeto-migra/fluxo-caixa-homelab
git pull origin main
./scripts/install-monitoring.sh
```

O script vai:
1. ✅ Criar namespace `monitoring`
2. ✅ Instalar Prometheus com RBAC
3. ✅ Instalar kube-state-metrics
4. ✅ Instalar PostgreSQL Exporter
5. ✅ Instalar Grafana com datasource pré-configurado
6. ✅ Configurar LoadBalancer para Grafana
7. ✅ Atualizar /etc/hosts

**Tempo estimado**: 5-7 minutos

---

### Instalação Manual

#### 1. Criar Namespace

```bash
kubectl apply -f monitoring/00-namespace.yaml
```

#### 2. Instalar Prometheus

```bash
kubectl apply -f monitoring/prometheus/
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=prometheus \
  --timeout=120s
```

#### 3. Instalar Exporters

```bash
# kube-state-metrics
kubectl apply -f monitoring/exporters/kube-state-metrics.yaml

# PostgreSQL Exporter
kubectl apply -f monitoring/exporters/postgres-exporter.yaml
```

#### 4. Instalar Grafana

```bash
kubectl apply -f monitoring/grafana/
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=grafana \
  --timeout=120s
```

#### 5. Configurar Acesso

```bash
# Obter IP do Grafana
GRAFANA_IP=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Atualizar /etc/hosts
echo "$GRAFANA_IP  grafana.local" | sudo tee -a /etc/hosts
```

---

## Atualizar Aplicação com Métricas

A aplicação precisa ser reconstruída para incluir as métricas Prometheus.

### 1. Rebuild da Imagem Docker

```bash
cd ~/projeto-migra/fluxo-caixa-homelab/app

# Build
docker build -t phfldocker/fluxo-caixa-app:v1.1 .

# Push
docker push phfldocker/fluxo-caixa-app:v1.1
```

### 2. Atualizar Deployment

```bash
# Atualizar imagem
kubectl set image deployment/fluxo-caixa-app \
  app=phfldocker/fluxo-caixa-app:v1.1 \
  -n fluxo-caixa

# Aguardar rollout
kubectl rollout status deployment/fluxo-caixa-app -n fluxo-caixa
```

### 3. Verificar Métricas

```bash
# Testar endpoint de métricas
curl http://fluxo-caixa.local/metrics

# Deve retornar métricas Prometheus
# HELP http_requests_total Total de requisições HTTP
# TYPE http_requests_total counter
# http_requests_total{method="GET",route="/health",status_code="200"} 42
```

---

## Acessar Grafana

### Via Navegador

```
URL: http://grafana.local
Login: admin
Senha: admin123
```

**Primeira vez:**
1. Acesse http://grafana.local
2. Login: admin / admin123
3. Grafana pedirá para trocar a senha (recomendado)

### Via Port-Forward (Alternativo)

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80

# Acesse: http://localhost:3000
```

---

## Importar Dashboards

Grafana possui milhares de dashboards prontos da comunidade.

### Dashboards Recomendados

#### Kubernetes
| Nome | ID | Descrição |
|------|----|-----------| 
| **Kubernetes Cluster Monitoring** | 7249 | Visão geral do cluster |
| **Node Exporter Full** | 1860 | Métricas detalhadas dos nodes |
| **Kubernetes Pods** | 6417 | Monitoramento de pods |
| **Kubernetes Deployment Statefulset Daemonset** | 8588 | Workloads |

#### PostgreSQL
| Nome | ID | Descrição |
|------|----|-----------| 
| **PostgreSQL Database** | 9628 | Métricas completas do PostgreSQL |
| **PostgreSQL Exporter Quickstart** | 455 | Dashboard simplificado |

#### Application
| Nome | ID | Descrição |
|------|----|-----------| 
| **Node.js Application Dashboard** | 11159 | Métricas de aplicação Node.js |
| **Express.js Dashboard** | 11159 | HTTP, latência, throughput |

#### MetalLB
| Nome | ID | Descrição |
|------|----|-----------| 
| **MetalLB** | 14127 | Monitoramento do MetalLB |

### Como Importar

**Via UI:**
1. Acesse Grafana: http://grafana.local
2. Menu lateral → **Dashboards** → **Import**
3. Digite o **ID do dashboard** (ex: 7249)
4. Clique em **Load**
5. Selecione datasource: **Prometheus**
6. Clique em **Import**

**Via JSON:**
1. Dashboards → Import
2. **Upload JSON file**
3. Selecione arquivo `.json` de `monitoring/dashboards/`
4. Import

---

## Acessar Prometheus

### Via Port-Forward

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Acesse: http://localhost:9090
```

### Explorar Métricas

**Targets (alvos de scraping):**
```
http://localhost:9090/targets
```

Deve mostrar:
- ✅ kubernetes-apiservers
- ✅ kubernetes-nodes
- ✅ kubernetes-pods
- ✅ postgresql
- ✅ fluxo-caixa-app
- ✅ metallb-controller
- ✅ metallb-speakers
- ✅ kube-state-metrics

**Queries úteis:**

```promql
# CPU dos nodes
100 - (avg by (node) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memória dos nodes
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Requisições HTTP por segundo
rate(http_requests_total[1m])

# Latência p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Conexões ativas do banco
db_connections_active

# Total de transações
sum(fluxocaixa_transacoes_total) by (tipo)

# Saldo atual
fluxocaixa_saldo_atual
```

---

## Métricas Disponíveis

### Aplicação Node.js

#### HTTP
```promql
# Total de requisições
http_requests_total{method, route, status_code}

# Duração das requisições (histogram)
http_request_duration_seconds_bucket{method, route, status_code}
http_request_duration_seconds_sum
http_request_duration_seconds_count
```

#### Banco de Dados
```promql
# Conexões ativas
db_connections_active

# Total de queries
db_queries_total{operation, status}

# Duração das queries (histogram)
db_query_duration_seconds_bucket{operation}
db_query_duration_seconds_sum
db_query_duration_seconds_count
```

#### Negócio (Fluxo de Caixa)
```promql
# Total de transações
fluxocaixa_transacoes_total{tipo, status}

# Valor total das transações
fluxocaixa_transacoes_valor_total{tipo, status}

# Saldo atual
fluxocaixa_saldo_atual
```

#### Sistema (Node.js process)
```promql
# CPU
process_cpu_user_seconds_total
process_cpu_system_seconds_total

# Memória
process_resident_memory_bytes
nodejs_heap_size_total_bytes
nodejs_heap_size_used_bytes

# Event Loop
nodejs_eventloop_lag_seconds
```

### PostgreSQL

```promql
# Conexões
pg_stat_database_numbackends

# Transações
pg_stat_database_xact_commit
pg_stat_database_xact_rollback

# Tamanho do banco
pg_database_size_bytes

# Queries lentas
pg_stat_statements_mean_exec_time_seconds

# Tabelas
pg_stat_user_tables_seq_scan
pg_stat_user_tables_idx_scan
pg_stat_user_tables_n_tup_ins
pg_stat_user_tables_n_tup_upd
pg_stat_user_tables_n_tup_del
```

### Kubernetes

```promql
# Pods
kube_pod_status_phase{phase="Running"}
kube_pod_status_phase{phase="Failed"}
kube_pod_container_status_restarts_total

# Deployments
kube_deployment_status_replicas_available
kube_deployment_status_replicas_unavailable

# Nodes
kube_node_status_condition{condition="Ready"}
kube_node_info

# Resources
kube_pod_container_resource_requests{resource="cpu"}
kube_pod_container_resource_limits{resource="memory"}
```

### MetalLB

```promql
# IPs alocados
metallb_allocator_addresses_in_use_total

# Anúncios L2
metallb_speaker_announced

# Eventos
metallb_k8s_client_updates_total
```

---

## Alertas (Opcional)

Prometheus suporta alertas via Alertmanager. Exemplos de alertas úteis:

### Alta Latência
```yaml
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Alta latência detectada"
    description: "P95 latency is {{ $value }}s"
```

### Pod Reiniciando
```yaml
- alert: PodRestarting
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pod reiniciando frequentemente"
```

### Banco de Dados Lento
```yaml
- alert: SlowQueries
  expr: pg_stat_statements_mean_exec_time_seconds > 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Queries lentas no PostgreSQL"
```

---

## Troubleshooting

### Prometheus não coleta métricas

**Verificar targets:**
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Acesse: http://localhost:9090/targets
```

**Verificar logs:**
```bash
kubectl logs -n monitoring -l app=prometheus --tail=50
```

**Verificar RBAC:**
```bash
kubectl get clusterrolebinding prometheus
kubectl describe clusterrole prometheus
```

### Grafana não mostra dados

**Verificar datasource:**
1. Grafana → Configuration → Data Sources
2. Prometheus deve estar configurado
3. URL: `http://prometheus.monitoring.svc.cluster.local:9090`
4. Clicar em "Test" deve retornar sucesso

**Verificar conectividade:**
```bash
kubectl exec -it -n monitoring deployment/grafana -- \
  wget -O- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
```

### PostgreSQL Exporter não funciona

**Verificar conexão:**
```bash
kubectl logs -n fluxo-caixa -l app=postgres-exporter --tail=50
```

**Testar manualmente:**
```bash
kubectl exec -it postgres-0 -n fluxo-caixa -- \
  psql -U postgres -d fluxocaixa -c "SELECT 1"
```

**Verificar secret:**
```bash
kubectl get secret postgres-exporter-secret -n fluxo-caixa -o yaml
```

### Métricas da aplicação não aparecem

**Verificar endpoint:**
```bash
curl http://fluxo-caixa.local/metrics
```

**Verificar annotations:**
```bash
kubectl get pod -n fluxo-caixa -l app=fluxo-caixa -o yaml | grep -A 3 annotations
```

Deve ter:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3000"
  prometheus.io/path: "/metrics"
```

**Verificar logs:**
```bash
kubectl logs -n fluxo-caixa -l app=fluxo-caixa --tail=50
```

---

## Comandos Úteis

### Prometheus

```bash
# Port-forward
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Logs
kubectl logs -n monitoring -l app=prometheus -f

# Reload config (sem restart)
kubectl exec -n monitoring deployment/prometheus -- \
  curl -X POST http://localhost:9090/-/reload

# Restart
kubectl rollout restart deployment prometheus -n monitoring
```

### Grafana

```bash
# Port-forward
kubectl port-forward -n monitoring svc/grafana 3000:80

# Logs
kubectl logs -n monitoring -l app=grafana -f

# Restart
kubectl rollout restart deployment grafana -n monitoring

# Reset senha admin
kubectl exec -it -n monitoring deployment/grafana -- \
  grafana-cli admin reset-admin-password admin123
```

### Exporters

```bash
# PostgreSQL Exporter logs
kubectl logs -n fluxo-caixa -l app=postgres-exporter -f

# kube-state-metrics logs
kubectl logs -n monitoring -l app=kube-state-metrics -f

# Testar métricas
kubectl port-forward -n fluxo-caixa svc/postgres-exporter 9187:9187
curl http://localhost:9187/metrics
```

### Aplicação

```bash
# Testar métricas
curl http://fluxo-caixa.local/metrics

# Gerar carga (para testar)
for i in {1..100}; do curl -s http://fluxo-caixa.local/health > /dev/null; done

# Ver métricas específicas
curl http://fluxo-caixa.local/metrics | grep http_requests_total
```

---

## Backup e Restore

### Backup do Prometheus

```bash
# Criar snapshot
kubectl exec -n monitoring deployment/prometheus -- \
  curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Copiar snapshot
kubectl cp monitoring/prometheus-xxxx:/prometheus/snapshots/xxx ./prometheus-backup
```

### Backup do Grafana

```bash
# Exportar dashboards via API
GRAFANA_URL="http://grafana.local"
GRAFANA_API_KEY="xxx"  # Criar em Grafana → Configuration → API Keys

curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
  $GRAFANA_URL/api/search | jq -r '.[] | .uid' | \
  while read uid; do
    curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
      $GRAFANA_URL/api/dashboards/uid/$uid > dashboard-$uid.json
  done
```

---

## Otimizações

### Reduzir Uso de Recursos

**Prometheus:**
```yaml
# Aumentar scrape interval
scrape_interval: 30s  # Padrão: 15s

# Reduzir retenção
--storage.tsdb.retention.time=7d  # Padrão: 15d
```

**Grafana:**
```yaml
# Reduzir refresh rate dos dashboards
refresh: "1m"  # Ao invés de 30s
```

### Aumentar Performance

**Prometheus:**
```yaml
# Mais recursos
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

**PostgreSQL Exporter:**
```yaml
# Reduzir queries customizadas
# Comentar queries não usadas em postgres-exporter-queries ConfigMap
```

---

## Referências

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [prom-client (Node.js)](https://github.com/siimon/prom-client)
- [PostgreSQL Exporter](https://github.com/prometheus-community/postgres_exporter)
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)

