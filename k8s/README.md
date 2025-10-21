# Manifestos Kubernetes - Fluxo de Caixa

Este diretório contém todos os manifestos Kubernetes para deploy da aplicação.

---

## 📁 Estrutura

```
k8s/
├── 00-namespace.yaml                    # Namespace fluxo-caixa
├── 01-postgres-configmap.yaml           # ConfigMap do PostgreSQL
├── 02-postgres-secret.yaml              # Secret do PostgreSQL
├── 03-postgres-pvc.yaml                 # PersistentVolumeClaim (10Gi)
├── 04-postgres-statefulset.yaml         # StatefulSet do PostgreSQL
├── 05-postgres-service.yaml             # Service do PostgreSQL
├── 06-app-configmap.yaml                # ConfigMap da aplicação
├── 07-app-deployment.yaml               # Deployment da aplicação
├── 08-app-service.yaml                  # Service da aplicação
├── 09-ingress.yaml                      # Ingress (NGINX)
├── 10-app-hpa.yaml                      # HorizontalPodAutoscaler (opcional)
├── 11-network-policy.yaml               # NetworkPolicy (opcional)
├── 12-pod-disruption-budget.yaml        # PodDisruptionBudget (opcional)
├── 13-servicemonitor.yaml               # ServiceMonitor para Prometheus (opcional)
├── 14-resource-quota.yaml               # ResourceQuota e LimitRange (opcional)
├── 15-backup-job.yaml                   # CronJob de backup (opcional)
├── kustomization.yaml                   # Kustomize base
└── overlays/                            # Overlays por ambiente
    ├── dev/
    │   ├── kustomization.yaml
    │   └── deployment-patch.yaml
    ├── staging/
    └── production/
        ├── kustomization.yaml
        └── deployment-patch.yaml
```

---

## 🚀 Deploy Básico (Método 1: kubectl apply)

### Deploy completo (base)

```bash
# Aplicar todos os manifestos base
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

# Ou aplicar tudo de uma vez
kubectl apply -f ./ --recursive
```

### Deploy com recursos opcionais

```bash
# Adicionar HPA (auto-scaling)
kubectl apply -f 10-app-hpa.yaml

# Adicionar NetworkPolicy (segurança)
kubectl apply -f 11-network-policy.yaml

# Adicionar PDB (alta disponibilidade)
kubectl apply -f 12-pod-disruption-budget.yaml

# Adicionar ResourceQuota
kubectl apply -f 14-resource-quota.yaml

# Adicionar backup automático
kubectl apply -f 15-backup-job.yaml
```

---

## 🎯 Deploy com Kustomize (Método 2: Recomendado)

### Deploy do ambiente base

```bash
# Visualizar o que será aplicado
kubectl kustomize .

# Aplicar
kubectl apply -k .
```

### Deploy por ambiente

```bash
# Desenvolvimento
kubectl apply -k overlays/dev/

# Produção
kubectl apply -k overlays/production/

# Visualizar diferenças
kubectl kustomize overlays/dev/
kubectl kustomize overlays/production/
```

---

## 📋 Ordem de Deploy Recomendada

1. **Namespace** (00)
2. **ConfigMaps e Secrets** (01, 02, 06)
3. **PVC** (03)
4. **PostgreSQL** (04, 05)
5. **Aguardar PostgreSQL estar pronto**
6. **Aplicação** (07, 08)
7. **Ingress** (09)
8. **Recursos opcionais** (10-15)

---

## ⚙️ Configurações Necessárias

### Antes do Deploy

**1. Editar `07-app-deployment.yaml`:**
```yaml
image: seu-registry/fluxo-caixa-app:v1.0  # Substituir pela sua imagem
```

**2. Editar `09-ingress.yaml`:**
```yaml
host: fluxo-caixa.local  # Substituir pelo seu domínio
ingressClassName: nginx  # Ajustar conforme seu ingress controller
```

**3. Editar `02-postgres-secret.yaml` (Produção):**
```yaml
stringData:
  POSTGRES_PASSWORD: senha-forte-aqui  # Trocar senha padrão
```

**4. Editar `03-postgres-pvc.yaml` (Opcional):**
```yaml
storageClassName: sua-storage-class  # Se necessário
```

---

## 🔍 Verificação do Deploy

```bash
# Ver todos os recursos
kubectl get all -n fluxo-caixa

# Ver status dos pods
kubectl get pods -n fluxo-caixa -w

# Ver logs do PostgreSQL
kubectl logs -f postgres-0 -n fluxo-caixa

# Ver logs da aplicação
kubectl logs -f deployment/fluxo-caixa-app -n fluxo-caixa

# Ver ingress
kubectl get ingress -n fluxo-caixa

# Ver PVCs
kubectl get pvc -n fluxo-caixa

# Ver eventos
kubectl get events -n fluxo-caixa --sort-by='.lastTimestamp'
```

---

## 🧪 Testes

### Port Forward (teste local)

```bash
# PostgreSQL
kubectl port-forward -n fluxo-caixa postgres-0 5432:5432

# Aplicação
kubectl port-forward -n fluxo-caixa service/fluxo-caixa-service 8080:80
```

### Conectar ao PostgreSQL

```bash
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa
```

### Testar API

```bash
# Health check
curl http://localhost:8080/health

# Saldo
curl http://localhost:8080/api/transacoes/consultas/saldo
```

---

## 📊 Recursos por Componente

| Componente | CPU Request | CPU Limit | Memory Request | Memory Limit | Replicas |
|------------|-------------|-----------|----------------|--------------|----------|
| PostgreSQL | 500m | 1000m | 512Mi | 1Gi | 1 |
| App | 100m | 500m | 128Mi | 256Mi | 2 |
| **Total** | **600m** | **2000m** | **768Mi** | **1.5Gi** | **3** |

---

## 🔐 Segurança

### NetworkPolicy

O arquivo `11-network-policy.yaml` implementa:
- Aplicação só pode acessar PostgreSQL
- PostgreSQL só aceita conexões da aplicação
- Tráfego externo apenas via Ingress

### Secrets

**⚠️ IMPORTANTE:** Em produção, use:
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault](https://www.vaultproject.io/)

Nunca commite secrets em plain text no Git!

---

## 📈 Auto-Scaling (HPA)

O arquivo `10-app-hpa.yaml` configura:
- **Min replicas:** 2
- **Max replicas:** 5
- **Target CPU:** 70%
- **Target Memory:** 80%

**Requisito:** Metrics Server instalado no cluster.

```bash
# Verificar se Metrics Server está instalado
kubectl top nodes
kubectl top pods -n fluxo-caixa
```

---

## 💾 Backup Automático

O arquivo `15-backup-job.yaml` configura:
- **Frequência:** Diariamente às 2h da manhã
- **Retenção:** 7 dias
- **Formato:** SQL comprimido (.sql.gz)
- **Storage:** PVC de 5Gi

### Executar backup manual

```bash
# Criar job a partir do CronJob
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%Y%m%d) -n fluxo-caixa

# Ver logs
kubectl logs -f job/manual-backup-YYYYMMDD -n fluxo-caixa
```

### Restaurar backup

```bash
# Copiar backup do pod
kubectl cp fluxo-caixa/postgres-0:/backups/backup-YYYYMMDD-HHMMSS.sql.gz ./backup.sql.gz

# Descompactar
gunzip backup.sql.gz

# Restaurar
kubectl exec -i postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa < backup.sql
```

---

## 🗑️ Limpeza

### Remover tudo

```bash
# Deletar namespace (remove todos os recursos)
kubectl delete namespace fluxo-caixa

# Ou deletar recursos individualmente
kubectl delete -f ./
```

### Remover apenas a aplicação (manter banco)

```bash
kubectl delete -f 07-app-deployment.yaml
kubectl delete -f 08-app-service.yaml
kubectl delete -f 09-ingress.yaml
```

---

## 🔧 Troubleshooting

### Pod não inicia

```bash
kubectl describe pod <pod-name> -n fluxo-caixa
kubectl logs <pod-name> -n fluxo-caixa
```

### PVC não provisiona

```bash
kubectl describe pvc postgres-pvc -n fluxo-caixa

# Verificar StorageClass
kubectl get storageclass
```

### Aplicação não conecta ao banco

```bash
# Verificar DNS
kubectl exec -it <app-pod> -n fluxo-caixa -- nslookup postgres-service

# Verificar variáveis de ambiente
kubectl exec -it <app-pod> -n fluxo-caixa -- env | grep DB_
```

### Ingress não funciona

```bash
# Verificar ingress controller
kubectl get pods -n ingress-nginx

# Ver detalhes do ingress
kubectl describe ingress fluxo-caixa-ingress -n fluxo-caixa
```

---

## 📚 Referências

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [PostgreSQL on Kubernetes](https://www.postgresql.org/docs/current/high-availability.html)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

## 🤝 Contribuindo

Para adicionar novos manifestos ou melhorias:
1. Criar branch
2. Adicionar/modificar manifestos
3. Testar em ambiente de dev
4. Criar Pull Request

