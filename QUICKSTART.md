# Guia de Início Rápido - Fluxo de Caixa Homelab

Este guia fornece instruções passo a passo para fazer o deploy da aplicação no seu cluster Kubernetes.

---

## Pré-requisitos

✅ Cluster Kubernetes funcional (testado com K3s, RKE, Kubeadm)
✅ `kubectl` configurado e conectado ao cluster
✅ NGINX Ingress Controller instalado (ou outro ingress controller)
✅ Pelo menos 1 vCore CPU e 1GB RAM disponíveis
✅ Docker instalado (para build da imagem)
✅ Acesso a um registry de imagens (Docker Hub, Harbor, etc.)

---

## Passo 1: Build e Push da Imagem Docker

```bash
# Navegar para o diretório da aplicação
cd app/

# Build da imagem
docker build -t seu-usuario/fluxo-caixa-app:v1.0 .

# Login no registry (exemplo: Docker Hub)
docker login

# Push da imagem
docker push seu-usuario/fluxo-caixa-app:v1.0
```

**⚠️ IMPORTANTE:** Edite o arquivo `k8s/07-app-deployment.yaml` e substitua `seu-registry/fluxo-caixa-app:v1.0` pela sua imagem.

---

## Passo 2: Ajustar Configurações

### 2.1. Ingress

Edite `k8s/09-ingress.yaml` e ajuste:
- `host`: Seu domínio ou IP (ex: `fluxo-caixa.homelab.local`)
- `ingressClassName`: Seu ingress controller (ex: `nginx`, `traefik`)

### 2.2. StorageClass (Opcional)

Se seu cluster tiver uma StorageClass específica, edite `k8s/03-postgres-pvc.yaml`:
```yaml
storageClassName: sua-storage-class  # ex: local-path, nfs-client
```

---

## Passo 3: Deploy Automatizado

Use o script de deploy automatizado:

```bash
cd scripts/
./deploy.sh
```

O script irá:
1. ✅ Criar namespace `fluxo-caixa`
2. ✅ Criar ConfigMaps e Secrets
3. ✅ Provisionar PVC (10Gi)
4. ✅ Fazer deploy do PostgreSQL
5. ✅ Inicializar banco de dados (schema, views, procedures, seed data)
6. ✅ Fazer deploy da aplicação (2 replicas)
7. ✅ Criar Ingress

---

## Passo 4: Verificar Deploy

```bash
# Ver todos os recursos
kubectl get all -n fluxo-caixa

# Ver logs do PostgreSQL
kubectl logs -f postgres-0 -n fluxo-caixa

# Ver logs da aplicação
kubectl logs -f deployment/fluxo-caixa-app -n fluxo-caixa

# Ver Ingress
kubectl get ingress -n fluxo-caixa
```

**Saída esperada:**
```
NAME                              READY   STATUS    RESTARTS   AGE
pod/postgres-0                    1/1     Running   0          2m
pod/fluxo-caixa-app-xxxxx-yyyyy   1/1     Running   0          1m
pod/fluxo-caixa-app-xxxxx-zzzzz   1/1     Running   0          1m

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/postgres-service     ClusterIP   None            <none>        5432/TCP   2m
service/fluxo-caixa-service  ClusterIP   10.43.123.456   <none>        80/TCP     1m
```

---

## Passo 5: Testar a Aplicação

### 5.1. Port Forward (Teste Local)

```bash
kubectl port-forward -n fluxo-caixa service/fluxo-caixa-service 8080:80
```

Em outro terminal:
```bash
# Health check
curl http://localhost:8080/health

# Consultar saldo
curl http://localhost:8080/api/transacoes/consultas/saldo

# Listar transações
curl http://localhost:8080/api/transacoes?limit=5
```

### 5.2. Acesso via Ingress

Adicione entrada no `/etc/hosts` (se necessário):
```bash
echo "192.168.1.100  fluxo-caixa.local" | sudo tee -a /etc/hosts
```

Teste:
```bash
curl http://fluxo-caixa.local/health
```

### 5.3. Script de Teste Automatizado

```bash
cd scripts/

# Definir URL da API
export API_URL=http://fluxo-caixa.local

# Executar testes
./test-api.sh
```

---

## Passo 6: Explorar o Banco de Dados

### 6.1. Conectar ao PostgreSQL

```bash
# Abrir shell no pod
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa
```

### 6.2. Queries de Exemplo

```sql
-- Ver saldo atual
SELECT * FROM vw_saldo_atual;

-- Ver relatório mensal
SELECT * FROM vw_relatorio_mensal ORDER BY mes DESC LIMIT 10;

-- Ver top transações
SELECT * FROM vw_top_transacoes LIMIT 10;

-- Testar procedure
CALL sp_consolidar_mes(2025, 1, NULL, NULL, NULL, NULL);

-- Testar function
SELECT * FROM fn_saldo_em_data('2025-01-15');
```

---

## Estrutura do Projeto

```
fluxo-caixa-homelab/
├── README.md              # Documentação completa
├── QUICKSTART.md          # Este guia
├── app/                   # Aplicação Node.js
│   ├── src/
│   ├── Dockerfile
│   └── package.json
├── database/              # Scripts SQL
│   ├── 01-schema.sql
│   ├── 02-views.sql
│   ├── 03-procedures.sql
│   ├── 04-functions.sql
│   └── 05-seed.sql
├── k8s/                   # Manifestos Kubernetes
│   ├── 00-namespace.yaml
│   ├── 01-postgres-configmap.yaml
│   ├── 02-postgres-secret.yaml
│   ├── 03-postgres-pvc.yaml
│   ├── 04-postgres-statefulset.yaml
│   ├── 05-postgres-service.yaml
│   ├── 06-app-configmap.yaml
│   ├── 07-app-deployment.yaml
│   ├── 08-app-service.yaml
│   └── 09-ingress.yaml
├── docs/                  # Documentação
│   ├── api.md
│   └── migracao-aws.md
└── scripts/               # Scripts auxiliares
    ├── deploy.sh
    └── test-api.sh
```

---

## Recursos Utilizados

| Componente | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|------------|-------------|-----------|----------------|--------------|---------|
| PostgreSQL | 500m | 1000m | 512Mi | 1Gi | 10Gi |
| App (2 pods) | 200m | 1000m | 256Mi | 512Mi | - |
| **Total** | **700m** | **2000m** | **768Mi** | **1.5Gi** | **10Gi** |

---

## Troubleshooting

### Pod não inicia

```bash
# Ver eventos
kubectl describe pod <pod-name> -n fluxo-caixa

# Ver logs
kubectl logs <pod-name> -n fluxo-caixa
```

### PostgreSQL não conecta

```bash
# Verificar se o pod está pronto
kubectl get pod postgres-0 -n fluxo-caixa

# Testar conexão
kubectl exec -it postgres-0 -n fluxo-caixa -- pg_isready -U postgres
```

### Aplicação não conecta ao banco

```bash
# Verificar variáveis de ambiente
kubectl exec -it <app-pod> -n fluxo-caixa -- env | grep DB_

# Verificar DNS
kubectl exec -it <app-pod> -n fluxo-caixa -- nslookup postgres-service
```

### Ingress não funciona

```bash
# Verificar ingress controller
kubectl get pods -n ingress-nginx  # ou namespace do seu controller

# Ver detalhes do ingress
kubectl describe ingress fluxo-caixa-ingress -n fluxo-caixa
```

---

## Limpeza (Remover tudo)

```bash
# Deletar namespace (remove tudo)
kubectl delete namespace fluxo-caixa

# Ou deletar recursos individualmente
kubectl delete -f k8s/
```

---

## Próximos Passos

Após ter a aplicação rodando no homelab:

1. 📊 **Explorar a API** - Use a documentação em `docs/api.md`
2. 🗄️ **Estudar o Schema** - Analise views, procedures e functions
3. ☁️ **Planejar Migração AWS** - Leia `docs/migracao-aws.md`
4. 🚀 **Provisionar AWS** - Use Terraform para criar infraestrutura
5. 🔄 **Executar Migração** - Use DMS e SCT para migrar
6. 📝 **Documentar Aprendizados** - Registre custos e lições aprendidas

---

## Suporte

Para dúvidas ou problemas:
- **Documentação Completa:** `README.md`
- **Documentação da API:** `docs/api.md`
- **Guia de Migração:** `docs/migracao-aws.md`

---

**Boa sorte com seu projeto de migração! 🚀**

