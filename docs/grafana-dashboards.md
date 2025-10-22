# Guia de Dashboards do Grafana

## 🎯 Objetivo

Importar e configurar dashboards profissionais no Grafana para monitorar:
- Kubernetes Cluster
- Nodes e Pods
- PostgreSQL
- MetalLB
- Aplicação Node.js

---

## 📊 Dashboards Recomendados

### 1. Kubernetes Cluster Monitoring (ID: 7249)
**Descrição:** Visão geral completa do cluster Kubernetes

**Métricas:**
- CPU e Memória do cluster
- Número de pods, deployments, services
- Network I/O
- Disk I/O
- Status dos nodes

**Por quê usar:** Visão macro de todo o cluster em um único dashboard

---

### 2. Node Exporter Full (ID: 1860)
**Descrição:** Métricas detalhadas dos nodes

**Métricas:**
- CPU por core
- Memória (RAM, Swap)
- Disco (uso, I/O, latência)
- Rede (tráfego, erros, drops)
- Sistema (uptime, load average)

**Por quê usar:** Troubleshooting de performance dos nodes

---

### 3. Kubernetes Pods (ID: 6417)
**Descrição:** Monitoramento detalhado de pods

**Métricas:**
- CPU e Memória por pod
- Network por pod
- Restarts
- Status (Running, Pending, Failed)

**Por quê usar:** Identificar pods com problemas ou alto consumo

---

### 4. PostgreSQL Database (ID: 9628)
**Descrição:** Métricas completas do PostgreSQL

**Métricas:**
- Conexões ativas
- Transações (commit/rollback)
- Tamanho do banco
- Queries por segundo
- Cache hit ratio
- Locks

**Por quê usar:** Monitorar saúde e performance do banco de dados

---

### 5. MetalLB (ID: 14127)
**Descrição:** Monitoramento do MetalLB LoadBalancer

**Métricas:**
- IPs alocados
- Anúncios L2
- Status dos speakers
- Eventos

**Por quê usar:** Garantir que LoadBalancer está funcionando corretamente

---

## 🚀 Como Importar Dashboards

### Método 1: Via Interface Web (Recomendado)

#### Passo 1: Acessar Grafana

```bash
# Abrir navegador
firefox http://grafana.local

# Ou
google-chrome http://grafana.local
```

**Login:**
- **Usuário:** admin
- **Senha:** admin123

**Primeira vez:**
- Grafana pode pedir para trocar a senha
- Você pode clicar em "Skip" ou definir uma nova senha

---

#### Passo 2: Navegar para Import

1. **Menu lateral esquerdo** (☰)
2. **Dashboards**
3. **Import** (ou **New** → **Import**)

---

#### Passo 3: Importar Dashboard

1. **Digite o ID** do dashboard (ex: 7249)
2. **Clique em "Load"**
3. **Aguarde carregar** (pode demorar alguns segundos)
4. **Configurar:**
   - **Name:** (pode manter o padrão ou personalizar)
   - **Folder:** (selecione "General" ou crie uma pasta)
   - **Prometheus:** Selecione "Prometheus" (datasource)
5. **Clique em "Import"**

**Pronto!** Dashboard importado e funcional! ✅

---

#### Passo 4: Repetir para Outros Dashboards

Repita os passos 2 e 3 para cada dashboard:
- ID 7249 (Kubernetes Cluster)
- ID 1860 (Node Exporter)
- ID 6417 (Kubernetes Pods)
- ID 9628 (PostgreSQL)
- ID 14127 (MetalLB)

---

### Método 2: Via API (Automatizado)

Se preferir automatizar:

```bash
# Definir variáveis
GRAFANA_URL="http://grafana.local"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"

# Lista de dashboards para importar
DASHBOARDS=(
  "7249"  # Kubernetes Cluster Monitoring
  "1860"  # Node Exporter Full
  "6417"  # Kubernetes Pods
  "9628"  # PostgreSQL Database
  "14127" # MetalLB
)

# Importar cada dashboard
for DASHBOARD_ID in "${DASHBOARDS[@]}"; do
  echo "Importando dashboard ID: $DASHBOARD_ID"
  
  # Baixar JSON do dashboard
  DASHBOARD_JSON=$(curl -s "https://grafana.com/api/dashboards/$DASHBOARD_ID/revisions/latest/download")
  
  # Preparar payload
  PAYLOAD=$(jq -n \
    --argjson dashboard "$DASHBOARD_JSON" \
    '{
      dashboard: $dashboard,
      overwrite: true,
      inputs: [{
        name: "DS_PROMETHEUS",
        type: "datasource",
        pluginId: "prometheus",
        value: "Prometheus"
      }]
    }')
  
  # Importar via API
  curl -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d "$PAYLOAD" \
    "$GRAFANA_URL/api/dashboards/import"
  
  echo "✅ Dashboard $DASHBOARD_ID importado"
  echo ""
done

echo "🎉 Todos os dashboards importados!"
```

---

## 📋 Lista Completa de Dashboards

### Kubernetes

| Nome | ID | URL | Descrição |
|------|----|----|-----------|
| Kubernetes Cluster Monitoring | 7249 | https://grafana.com/grafana/dashboards/7249 | Visão geral do cluster |
| Kubernetes / Views / Global | 15757 | https://grafana.com/grafana/dashboards/15757 | Visão global moderna |
| Kubernetes / Views / Namespaces | 15758 | https://grafana.com/grafana/dashboards/15758 | Por namespace |
| Kubernetes / Views / Pods | 15760 | https://grafana.com/grafana/dashboards/15760 | Por pod |
| Kubernetes Pods | 6417 | https://grafana.com/grafana/dashboards/6417 | Monitoramento de pods |

### Nodes

| Nome | ID | URL | Descrição |
|------|----|----|-----------|
| Node Exporter Full | 1860 | https://grafana.com/grafana/dashboards/1860 | Métricas completas dos nodes |
| Node Exporter for Prometheus | 11074 | https://grafana.com/grafana/dashboards/11074 | Alternativa moderna |

### PostgreSQL

| Nome | ID | URL | Descrição |
|------|----|----|-----------|
| PostgreSQL Database | 9628 | https://grafana.com/grafana/dashboards/9628 | Métricas completas |
| PostgreSQL Exporter Quickstart | 455 | https://grafana.com/grafana/dashboards/455 | Dashboard simplificado |

### Aplicação

| Nome | ID | URL | Descrição |
|------|----|----|-----------|
| Node.js Application Dashboard | 11159 | https://grafana.com/grafana/dashboards/11159 | Métricas de aplicação Node.js |

### LoadBalancer

| Nome | ID | URL | Descrição |
|------|----|----|-----------|
| MetalLB | 14127 | https://grafana.com/grafana/dashboards/14127 | Monitoramento do MetalLB |

---

## 🎨 Personalizar Dashboards

Após importar, você pode personalizar:

### Editar Dashboard

1. **Abrir dashboard**
2. **Clicar no ícone de engrenagem** (⚙️) no topo
3. **Dashboard settings**

**Opções:**
- **General:** Nome, descrição, tags, timezone
- **Variables:** Adicionar variáveis (namespace, pod, etc)
- **Links:** Adicionar links para outros dashboards
- **JSON Model:** Editar JSON diretamente

### Editar Painel

1. **Hover sobre o painel**
2. **Clicar no título do painel** → **Edit**

**Opções:**
- **Query:** Modificar query PromQL
- **Visualization:** Mudar tipo de gráfico
- **Panel options:** Título, descrição
- **Thresholds:** Definir limites (verde/amarelo/vermelho)
- **Overrides:** Customizações específicas

### Adicionar Novo Painel

1. **Clicar em "Add"** no topo
2. **Visualization**
3. **Selecionar tipo:** Time series, Gauge, Stat, Table, etc
4. **Configurar query PromQL**
5. **Aplicar**

---

## 📊 Queries PromQL Úteis

### Kubernetes

```promql
# CPU dos nodes (%)
100 - (avg by (node) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memória dos nodes (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pods por namespace
count(kube_pod_info) by (namespace)

# Pods por status
count(kube_pod_status_phase) by (phase)

# CPU por pod
sum(rate(container_cpu_usage_seconds_total{pod!=""}[5m])) by (pod, namespace)

# Memória por pod
sum(container_memory_working_set_bytes{pod!=""}) by (pod, namespace)
```

### Aplicação

```promql
# Requisições por segundo
rate(http_requests_total[1m])

# Latência p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Taxa de erro
rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])

# Conexões ativas do banco
db_connections_active

# Transações por tipo
sum(fluxocaixa_transacoes_total) by (tipo)
```

### PostgreSQL

```promql
# Conexões ativas
pg_stat_database_numbackends

# Transações por segundo
rate(pg_stat_database_xact_commit[1m])

# Tamanho do banco (GB)
pg_database_size_bytes / 1024 / 1024 / 1024

# Cache hit ratio (%)
(pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)) * 100
```

---

## 🔔 Configurar Alertas

### Criar Alerta em um Painel

1. **Editar painel**
2. **Aba "Alert"**
3. **Create alert rule from this panel**
4. **Configurar:**
   - **Name:** Nome do alerta
   - **Condition:** Quando alertar (ex: value > 80)
   - **Evaluate every:** Frequência de avaliação
   - **For:** Tempo antes de disparar
5. **Salvar**

### Notification Channels

1. **Menu lateral** → **Alerting** → **Contact points**
2. **Add contact point**
3. **Selecionar tipo:**
   - Email
   - Slack
   - Webhook
   - Telegram
   - etc
4. **Configurar** e **Test**
5. **Save**

---

## 📁 Organizar Dashboards

### Criar Pastas

1. **Menu lateral** → **Dashboards**
2. **New** → **New folder**
3. **Nome:** ex: "Kubernetes", "Aplicação", "Banco de Dados"
4. **Create**

### Mover Dashboard para Pasta

1. **Abrir dashboard**
2. **⚙️ Dashboard settings**
3. **General**
4. **Folder:** Selecionar pasta
5. **Save dashboard**

### Sugestão de Organização

```
📁 General (padrão)
📁 Kubernetes
   ├── Kubernetes Cluster Monitoring
   ├── Kubernetes Pods
   └── Node Exporter Full
📁 Aplicação
   ├── Node.js Application Dashboard
   └── Fluxo de Caixa (custom)
📁 Banco de Dados
   └── PostgreSQL Database
📁 Infraestrutura
   └── MetalLB
```

---

## 🎯 Dashboards Essenciais (Top 5)

Se você só puder importar 5, escolha estes:

1. **Kubernetes Cluster Monitoring (7249)** ⭐⭐⭐⭐⭐
   - Visão geral de tudo
   - Primeiro dashboard a abrir

2. **Node Exporter Full (1860)** ⭐⭐⭐⭐⭐
   - Troubleshooting de nodes
   - Identificar gargalos

3. **PostgreSQL Database (9628)** ⭐⭐⭐⭐⭐
   - Monitorar banco de dados
   - Essencial para aplicação

4. **Kubernetes Pods (6417)** ⭐⭐⭐⭐
   - Ver status de todos os pods
   - Identificar problemas

5. **MetalLB (14127)** ⭐⭐⭐
   - Garantir LoadBalancer funcionando
   - Monitorar IPs alocados

---

## 🆘 Troubleshooting

### Dashboard não carrega

**Problema:** "No data" ou gráficos vazios

**Soluções:**
1. Verificar se Prometheus está coletando métricas:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   # Acessar: http://localhost:9090/targets
   # Verificar se targets estão UP
   ```

2. Verificar datasource no Grafana:
   - **Connections** → **Data Sources** → **Prometheus**
   - Clicar em **Test** → Deve mostrar "Data source is working"

3. Ajustar time range:
   - Canto superior direito
   - Selecionar "Last 1 hour" ou "Last 6 hours"

### Variáveis não funcionam

**Problema:** Dropdowns de namespace, pod, etc não aparecem

**Solução:**
1. **⚙️ Dashboard settings** → **Variables**
2. Verificar query da variável
3. Testar query no Prometheus

### Permissões

**Problema:** Não consegue editar dashboard

**Solução:**
- Verificar se está logado como admin
- Ou criar cópia do dashboard (pode editar cópia)

---

## 📚 Recursos Adicionais

- **Grafana Dashboards:** https://grafana.com/grafana/dashboards/
- **PromQL Cheat Sheet:** https://promlabs.com/promql-cheat-sheet/
- **Grafana Documentation:** https://grafana.com/docs/grafana/latest/

---

## ✅ Checklist de Importação

- [ ] Acessar Grafana (http://grafana.local)
- [ ] Login (admin/admin123)
- [ ] Importar Kubernetes Cluster Monitoring (7249)
- [ ] Importar Node Exporter Full (1860)
- [ ] Importar Kubernetes Pods (6417)
- [ ] Importar PostgreSQL Database (9628)
- [ ] Importar MetalLB (14127)
- [ ] Criar pastas para organizar
- [ ] Mover dashboards para pastas
- [ ] Testar todos os dashboards
- [ ] Configurar alertas (opcional)
- [ ] Personalizar conforme necessidade

---

Pronto! Dashboards importados e prontos para uso! 📊🎉

