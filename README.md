# Fluxo de Caixa - Homelab

Sistema de fluxo de caixa simplificado para laboratório de migração de banco de dados para AWS Aurora.

## Objetivo

Este projeto tem como objetivo criar um ambiente de origem completo e funcional no homelab (Kubernetes) para simular um cenário real de migração de banco de dados PostgreSQL para AWS Aurora, utilizando:

- **AWS Database Migration Service (DMS)**
- **AWS Schema Conversion Tool (SCT)**
- **Ferramentas de IA da AWS** para conversão de procedures e views

## Arquitetura

```
┌─────────────┐
│   Usuário   │
└──────┬──────┘
       │ HTTP/HTTPS
       ↓
┌─────────────────────────────────────┐
│         NGINX Ingress               │
└──────┬──────────────────────────────┘
       │ HTTP
       ↓
┌─────────────────────────────────────┐
│      Node.js API (2 replicas)       │
│  - API REST para fluxo de caixa     │
└──────┬──────────────────────────────┘
       │ PostgreSQL (5432)
       ↓
┌─────────────────────────────────────┐
│    PostgreSQL 15 (StatefulSet)      │
│  - Schema complexo                  │
│  - Views e Stored Procedures        │
└─────────────────────────────────────┘
```

## Stack Tecnológica

- **Frontend/Proxy:** NGINX Ingress Controller
- **Backend:** Node.js 18 + Express
- **Banco de Dados:** PostgreSQL 15
- **Orquestração:** Kubernetes
- **IaC:** Manifestos YAML

## Estrutura do Projeto

```
fluxo-caixa-homelab/
├── app/                    # Aplicação Node.js
│   ├── src/
│   │   ├── server.js
│   │   ├── routes/
│   │   ├── controllers/
│   │   ├── models/
│   │   └── config/
│   ├── package.json
│   └── Dockerfile
├── database/               # Scripts de banco de dados
│   ├── 01-schema.sql
│   ├── 02-views.sql
│   ├── 03-procedures.sql
│   ├── 04-functions.sql
│   └── 05-seed.sql
├── k8s/                    # Manifestos Kubernetes
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
├── docs/                   # Documentação
└── scripts/                # Scripts auxiliares
```

## API Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/transacoes` | Criar nova transação |
| GET | `/api/transacoes` | Listar todas as transações |
| GET | `/api/transacoes/:id` | Buscar transação por ID |
| GET | `/api/saldo` | Consultar saldo atual |
| GET | `/api/relatorio/mensal` | Relatório mensal (usa VIEW) |
| POST | `/api/transacoes/lote` | Inserção em lote (usa PROCEDURE) |
| GET | `/health` | Health check |

## Requisitos

- Cluster Kubernetes funcional
- NGINX Ingress Controller instalado
- `kubectl` configurado
- Pelo menos 1 vCore e 1GB RAM disponíveis

## Deploy

### 1. Criar namespace e recursos

```bash
cd k8s
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-postgres-configmap.yaml
kubectl apply -f 02-postgres-secret.yaml
kubectl apply -f 03-postgres-pvc.yaml
```

### 2. Deploy do PostgreSQL

```bash
kubectl apply -f 04-postgres-statefulset.yaml
kubectl apply -f 05-postgres-service.yaml

# Aguardar o pod estar pronto
kubectl wait --for=condition=ready pod -l app=postgres -n fluxo-caixa --timeout=120s
```

### 3. Inicializar o banco de dados

```bash
# Copiar scripts SQL para o pod
kubectl cp ../database/01-schema.sql fluxo-caixa/postgres-0:/tmp/
kubectl cp ../database/02-views.sql fluxo-caixa/postgres-0:/tmp/
kubectl cp ../database/03-procedures.sql fluxo-caixa/postgres-0:/tmp/
kubectl cp ../database/04-functions.sql fluxo-caixa/postgres-0:/tmp/
kubectl cp ../database/05-seed.sql fluxo-caixa/postgres-0:/tmp/

# Executar scripts
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/01-schema.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/02-views.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/03-procedures.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/04-functions.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/05-seed.sql
```

### 4. Build e push da imagem da aplicação

```bash
cd ../app

# Ajustar para seu registry (Docker Hub, Harbor, etc.)
docker build -t seu-registry/fluxo-caixa-app:v1.0 .
docker push seu-registry/fluxo-caixa-app:v1.0
```

### 5. Deploy da aplicação

```bash
cd ../k8s

# Editar 07-app-deployment.yaml para usar sua imagem
kubectl apply -f 06-app-configmap.yaml
kubectl apply -f 07-app-deployment.yaml
kubectl apply -f 08-app-service.yaml
kubectl apply -f 09-ingress.yaml
```

### 6. Verificar deployment

```bash
kubectl get all -n fluxo-caixa
kubectl get ingress -n fluxo-caixa
```

## Testes

### Health Check

```bash
curl http://seu-dominio/health
```

### Criar transação

```bash
curl -X POST http://seu-dominio/api/transacoes \
  -H "Content-Type: application/json" \
  -d '{
    "descricao": "Salário",
    "valor": 5000.00,
    "tipo": "C",
    "categoria": "Receita"
  }'
```

### Consultar saldo

```bash
curl http://seu-dominio/api/saldo
```

### Listar transações

```bash
curl http://seu-dominio/api/transacoes
```

## Complexidade do Banco de Dados

O schema foi projetado para desafiar as ferramentas de migração:

- **3 tabelas relacionadas** (transacoes, categorias, usuarios)
- **3 views complexas** com agregações e window functions
- **3 stored procedures** com lógica de negócio
- **2 funções customizadas** em PL/pgSQL
- **Índices estratégicos** para performance

## Próximos Passos (Migração AWS)

1. Provisionar infraestrutura AWS com Terraform (VPC, Aurora, DMS)
2. Executar AWS SCT para análise do schema
3. Configurar DMS para migração com CDC
4. Testar ferramentas de IA para conversão de procedures
5. Validar integridade dos dados
6. Documentar custos e lições aprendidas

## Recursos Utilizados

| Componente | CPU Request | Memory Request | Storage |
|------------|-------------|----------------|---------|
| PostgreSQL | 500m | 512Mi | 10Gi |
| Node.js (2 pods) | 200m | 256Mi | - |
| **Total** | **700m** | **768Mi** | **10Gi** |

## Licença

MIT

## Autor

Paulo Lyra - Projeto de laboratório para aprendizado de migração de banco de dados

