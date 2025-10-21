# Resumo dos Manifestos Kubernetes

## 📦 Manifestos Base (Obrigatórios)

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `00-namespace.yaml` | Namespace | Namespace `fluxo-caixa` |
| `01-postgres-configmap.yaml` | ConfigMap | Configurações do PostgreSQL |
| `02-postgres-secret.yaml` | Secret | Senha do PostgreSQL |
| `03-postgres-pvc.yaml` | PVC | Storage 10Gi para PostgreSQL |
| `04-postgres-statefulset.yaml` | StatefulSet | PostgreSQL 15 (1 replica) |
| `05-postgres-service.yaml` | Service | Service Headless para PostgreSQL |
| `06-app-configmap.yaml` | ConfigMap | Configurações da aplicação |
| `07-app-deployment.yaml` | Deployment | Aplicação Node.js (2 replicas) |
| `08-app-service.yaml` | Service | Service ClusterIP para aplicação |
| `09-ingress.yaml` | Ingress | Ingress NGINX |

**Total: 10 manifestos base**

---

## 🔧 Manifestos Opcionais (Produção)

| Arquivo | Tipo | Descrição | Quando Usar |
|---------|------|-----------|-------------|
| `10-app-hpa.yaml` | HPA | Auto-scaling (2-5 replicas) | Carga variável |
| `11-network-policy.yaml` | NetworkPolicy | Isolamento de rede | Segurança |
| `12-pod-disruption-budget.yaml` | PDB | Garantia de disponibilidade | Alta disponibilidade |
| `13-servicemonitor.yaml` | ServiceMonitor | Métricas Prometheus | Monitoramento |
| `14-resource-quota.yaml` | ResourceQuota | Limites de recursos | Multi-tenant |
| `15-backup-job.yaml` | CronJob | Backup automático diário | Produção |

**Total: 6 manifestos opcionais**

---

## 📁 Kustomize

| Arquivo | Descrição |
|---------|-----------|
| `kustomization.yaml` | Base Kustomize |
| `overlays/dev/` | Overlay para desenvolvimento |
| `overlays/production/` | Overlay para produção |

---

## 📚 Documentação

| Arquivo | Descrição |
|---------|-----------|
| `README.md` | Documentação completa |
| `architecture.md` | Diagramas de arquitetura |
| `MANIFEST_SUMMARY.md` | Este resumo |

---

## 🚀 Como Usar

### Deploy Básico (Homelab)
```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-postgres-configmap.yaml
kubectl apply -f 02-postgres-secret.yaml
kubectl apply -f 03-postgres-pvc.yaml
kubectl apply -f 04-postgres-statefulset.yaml
kubectl apply -f 05-postgres-service.yaml
kubectl apply -f 06-app-configmap.yaml
kubectl apply -f 07-app-deployment.yaml
kubectl apply -f 08-app-service.yaml
kubectl apply -f 09-ingress.yaml
```

### Deploy com Kustomize (Recomendado)
```bash
# Base
kubectl apply -k .

# Desenvolvimento
kubectl apply -k overlays/dev/

# Produção
kubectl apply -k overlays/production/
```

### Deploy Completo (Produção)
```bash
# Base + Opcionais
kubectl apply -f ./
```

---

## 📊 Recursos Totais

### Base (Mínimo)
- **CPU Request:** 600m (0.6 vCPU)
- **CPU Limit:** 2000m (2 vCPU)
- **Memory Request:** 768Mi
- **Memory Limit:** 1.5Gi
- **Storage:** 10Gi
- **Pods:** 3 (1 PostgreSQL + 2 App)

### Com HPA (Máximo)
- **CPU Request:** 1100m (1.1 vCPU)
- **CPU Limit:** 3500m (3.5 vCPU)
- **Memory Request:** 1280Mi
- **Memory Limit:** 2.5Gi
- **Storage:** 15Gi (10Gi + 5Gi backup)
- **Pods:** 6 (1 PostgreSQL + 5 App)

---

## ✅ Checklist de Deploy

- [ ] Editar `07-app-deployment.yaml` com sua imagem Docker
- [ ] Editar `09-ingress.yaml` com seu domínio
- [ ] Trocar senha em `02-postgres-secret.yaml` (produção)
- [ ] Ajustar `storageClassName` em `03-postgres-pvc.yaml` (se necessário)
- [ ] Verificar se NGINX Ingress Controller está instalado
- [ ] Aplicar manifestos na ordem correta
- [ ] Aguardar PostgreSQL estar pronto
- [ ] Inicializar banco de dados (scripts SQL)
- [ ] Testar aplicação
- [ ] Configurar backup (opcional)
- [ ] Configurar monitoramento (opcional)

---

## 🔍 Verificação

```bash
# Ver todos os recursos
kubectl get all -n fluxo-caixa

# Ver status dos pods
kubectl get pods -n fluxo-caixa -w

# Ver logs
kubectl logs -f deployment/fluxo-caixa-app -n fluxo-caixa

# Ver eventos
kubectl get events -n fluxo-caixa --sort-by='.lastTimestamp'
```

---

## 🗑️ Limpeza

```bash
# Remover tudo
kubectl delete namespace fluxo-caixa

# Ou remover recursos individualmente
kubectl delete -f ./
```
