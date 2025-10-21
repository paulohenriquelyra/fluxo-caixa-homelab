# Arquitetura Kubernetes - Fluxo de Caixa

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Internet / Usuários                         │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      NGINX Ingress Controller                        │
│                    (fluxo-caixa.local → Service)                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Namespace: fluxo-caixa                            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Service: fluxo-caixa-service                    │   │
│  │                    (ClusterIP: 80)                           │   │
│  └────────────────────────┬────────────────────────────────────┘   │
│                           │                                          │
│                           ↓                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │         Deployment: fluxo-caixa-app (2 replicas)            │   │
│  │  ┌──────────────────┐         ┌──────────────────┐         │   │
│  │  │   Pod 1          │         │   Pod 2          │         │   │
│  │  │  Node.js + API   │         │  Node.js + API   │         │   │
│  │  │  CPU: 100m-500m  │         │  CPU: 100m-500m  │         │   │
│  │  │  Mem: 128Mi-256Mi│         │  Mem: 128Mi-256Mi│         │   │
│  │  │  Port: 3000      │         │  Port: 3000      │         │   │
│  │  └────────┬─────────┘         └────────┬─────────┘         │   │
│  └───────────┼──────────────────────────────┼──────────────────┘   │
│              │                              │                       │
│              └──────────────┬───────────────┘                       │
│                             │                                       │
│                             ↓                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │           Service: postgres-service (Headless)              │   │
│  │                    (ClusterIP: None)                        │   │
│  └────────────────────────┬────────────────────────────────────┘   │
│                           │                                          │
│                           ↓                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │         StatefulSet: postgres (1 replica)                   │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │   Pod: postgres-0                                    │   │   │
│  │  │   PostgreSQL 15                                      │   │   │
│  │  │   CPU: 500m-1000m                                    │   │   │
│  │  │   Mem: 512Mi-1Gi                                     │   │   │
│  │  │   Port: 5432                                         │   │   │
│  │  │                                                       │   │   │
│  │  │   ┌──────────────────────────────────────────────┐   │   │   │
│  │  │   │  PVC: postgres-pvc (10Gi)                   │   │   │   │
│  │  │   │  /var/lib/postgresql/data                   │   │   │   │
│  │  │   └──────────────────────────────────────────────┘   │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              ConfigMaps & Secrets                           │   │
│  │  • postgres-config                                          │   │
│  │  • postgres-secret                                          │   │
│  │  • app-config                                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Recursos Opcionais                             │   │
│  │  • HorizontalPodAutoscaler (2-5 replicas)                   │   │
│  │  • NetworkPolicy (isolamento de rede)                       │   │
│  │  • PodDisruptionBudget (HA)                                 │   │
│  │  • ResourceQuota (limites)                                  │   │
│  │  • CronJob: backup (diário às 2h)                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

## Fluxo de Requisição

```
1. Usuário → http://fluxo-caixa.local/api/transacoes
                    ↓
2. NGINX Ingress → fluxo-caixa-service:80
                    ↓
3. Service → Pod (fluxo-caixa-app):3000
                    ↓
4. Node.js API → postgres-service:5432
                    ↓
5. PostgreSQL (postgres-0)
                    ↓
6. Resposta ← PostgreSQL
                    ↓
7. Resposta ← Node.js API
                    ↓
8. Resposta ← Service
                    ↓
9. Resposta ← NGINX Ingress
                    ↓
10. Resposta → Usuário
```

## Componentes e Responsabilidades

| Componente | Tipo | Responsabilidade |
|------------|------|------------------|
| **NGINX Ingress** | Ingress Controller | Roteamento HTTP/HTTPS externo |
| **fluxo-caixa-service** | Service (ClusterIP) | Load balancing entre pods da aplicação |
| **fluxo-caixa-app** | Deployment | API REST Node.js + Express |
| **postgres-service** | Service (Headless) | DNS para StatefulSet |
| **postgres** | StatefulSet | Banco de dados PostgreSQL 15 |
| **postgres-pvc** | PVC | Armazenamento persistente (10Gi) |
| **HPA** | HorizontalPodAutoscaler | Auto-scaling (2-5 replicas) |
| **NetworkPolicy** | NetworkPolicy | Isolamento de rede |
| **PDB** | PodDisruptionBudget | Garantia de disponibilidade |
| **CronJob** | CronJob | Backup automático diário |

## Recursos de Rede

```
Namespace: fluxo-caixa
├── Ingress: fluxo-caixa-ingress
│   └── Host: fluxo-caixa.local
│       └── Path: / → fluxo-caixa-service:80
│
├── Service: fluxo-caixa-service (ClusterIP)
│   └── Port: 80 → TargetPort: 3000
│       └── Selector: app=fluxo-caixa-app
│
└── Service: postgres-service (Headless)
    └── Port: 5432 → TargetPort: 5432
        └── Selector: app=postgres
```

## Armazenamento

```
PersistentVolumeClaims:
├── postgres-pvc (10Gi)
│   └── MountPath: /var/lib/postgresql/data
│   └── Used by: postgres-0
│
└── postgres-backup-pvc (5Gi) [opcional]
    └── MountPath: /backups
    └── Used by: postgres-backup CronJob
```

## Configuração e Secrets

```
ConfigMaps:
├── postgres-config
│   ├── POSTGRES_DB: fluxocaixa
│   ├── POSTGRES_USER: postgres
│   └── PGDATA: /var/lib/postgresql/data/pgdata
│
└── app-config
    ├── NODE_ENV: production
    ├── PORT: 3000
    ├── DB_HOST: postgres-service.fluxo-caixa.svc.cluster.local
    ├── DB_PORT: 5432
    └── DB_NAME: fluxocaixa

Secrets:
└── postgres-secret
    └── POSTGRES_PASSWORD: postgres123 (trocar em produção!)
```

## Segurança (NetworkPolicy)

```
NetworkPolicy: fluxo-caixa-network-policy
├── Ingress:
│   ├── From: ingress-nginx namespace → Port 3000
│   └── From: same namespace → Port 3000
│
└── Egress:
    ├── To: postgres (app=postgres) → Port 5432
    ├── To: kube-system (DNS) → Port 53
    └── To: internet → Ports 80, 443

NetworkPolicy: postgres-network-policy
├── Ingress:
│   └── From: fluxo-caixa-app → Port 5432
│
└── Egress:
    └── To: kube-system (DNS) → Port 53
```

## Auto-Scaling (HPA)

```
HorizontalPodAutoscaler: fluxo-caixa-app-hpa
├── Min Replicas: 2
├── Max Replicas: 5
├── Metrics:
│   ├── CPU: 70% utilization
│   └── Memory: 80% utilization
└── Behavior:
    ├── Scale Up: +100% ou +2 pods (max) a cada 30s
    └── Scale Down: -50% a cada 60s (após 5min estável)
```

## Backup (CronJob)

```
CronJob: postgres-backup
├── Schedule: "0 2 * * *" (diariamente às 2h)
├── Command: pg_dump | gzip
├── Output: /backups/backup-YYYYMMDD-HHMMSS.sql.gz
├── Retention: 7 dias
└── Storage: postgres-backup-pvc (5Gi)
```
