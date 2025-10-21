# Dashboards Grafana

Este diretório contém dashboards pré-configurados para Grafana.

## Dashboards Incluídos

1. **Kubernetes Cluster Overview** - Visão geral do cluster
2. **Application Metrics** - Métricas da aplicação Node.js
3. **PostgreSQL Metrics** - Métricas do banco de dados
4. **MetalLB Metrics** - Métricas do MetalLB

## Dashboards Prontos da Comunidade

Recomendamos importar estes dashboards da comunidade Grafana:

### Kubernetes
- **Node Exporter Full**: ID 1860
- **Kubernetes Cluster Monitoring**: ID 7249
- **Kubernetes Pods**: ID 6417

### PostgreSQL
- **PostgreSQL Database**: ID 9628
- **PostgreSQL Exporter Quickstart**: ID 455

### Application
- **Node.js Application Dashboard**: ID 11159

### MetalLB
- **MetalLB**: ID 14127

## Como Importar

1. Acesse Grafana: http://grafana.local
2. Login: admin / admin123
3. Menu lateral → Dashboards → Import
4. Digite o ID do dashboard
5. Selecione datasource "Prometheus"
6. Clique em "Import"

