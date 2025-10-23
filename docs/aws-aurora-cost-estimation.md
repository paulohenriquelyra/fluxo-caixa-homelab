# 💰 Estimativa de Custos: AWS Aurora para Testes e Aprendizado

## 📊 Visão Geral

Este documento apresenta uma análise detalhada de custos para criar um **Amazon Aurora PostgreSQL** na AWS para **testes, aprendizado e validação de migração** usando Terraform.

**Objetivo:** Minimizar custos mantendo funcionalidade completa para:
- ✅ Testar migração com DMS
- ✅ Validar Schema Conversion Tool (SCT)
- ✅ Aprender Terraform
- ✅ Praticar AWS Secrets Manager
- ✅ Validar procedures/views com IA da AWS

**Estratégia:** Destruir recursos quando não estiver em uso (via Terraform)

---

## 💵 Componentes de Custo do Aurora

### 1. Instância de Banco de Dados (Compute)

| Tipo | vCPU | RAM | Custo/Hora (us-east-1) | Custo/Dia (8h) | Custo/Mês (20 dias) |
|------|------|-----|------------------------|----------------|---------------------|
| **db.t4g.micro** | 2 | 1 GB | $0.041 | $0.33 | $6.56 |
| **db.t4g.small** | 2 | 2 GB | $0.082 | $0.66 | $13.12 |
| **db.t3.small** | 2 | 2 GB | $0.086 | $0.69 | $13.76 |
| **db.r6g.large** | 2 | 16 GB | $0.26 | $2.08 | $41.60 |

**Recomendação para testes:** `db.t4g.small` (ARM Graviton2, melhor custo-benefício)

---

### 2. Storage (Armazenamento)

**Aurora Storage:**
- **Custo:** $0.10 por GB/mês
- **Mínimo:** 10 GB (cobrado automaticamente)
- **Seu caso:** ~1 GB de dados reais

| Cenário | Storage Alocado | Custo/Mês |
|---------|----------------|-----------|
| **Mínimo** | 10 GB | $1.00 |
| **Com crescimento** | 20 GB | $2.00 |
| **Seguro** | 50 GB | $5.00 |

**Recomendação:** 20 GB ($2.00/mês)

---

### 3. I/O (Operações de Entrada/Saída)

**Modelo Padrão:**
- **Custo:** $0.20 por 1 milhão de requisições
- **Seu caso:** ~100.000 I/O por dia (testes leves)

| Uso Diário | I/O por Mês | Custo/Mês |
|------------|-------------|-----------|
| **Leve** (testes) | 2 milhões | $0.40 |
| **Moderado** | 10 milhões | $2.00 |
| **Pesado** | 50 milhões | $10.00 |

**Recomendação:** $0.40-$1.00/mês

**Alternativa:** Aurora I/O-Optimized (sem cobrança de I/O, storage $0.14/GB)

---

### 4. Backup e Snapshots

**Backup Automático:**
- **Incluído:** Backup igual ao tamanho do banco (grátis)
- **Seu caso:** 10-20 GB incluídos (grátis)

**Snapshots Manuais:**
- **Custo:** $0.021 por GB/mês
- **Recomendação:** 1 snapshot antes de destruir ($0.21 para 10 GB)

---

### 5. Data Transfer (Transferência de Dados)

**Entrada (IN):** Grátis  
**Saída (OUT):**
- Primeiros 100 GB/mês: Grátis
- Depois: $0.09 por GB

**Seu caso:** <1 GB/mês (grátis)

---

### 6. Secrets Manager

**AWS Secrets Manager:**
- **Custo:** $0.40 por secret/mês
- **API calls:** $0.05 por 10.000 chamadas

**Seu caso:**
- 3 secrets (master password, app user, read-only user)
- Custo: $1.20/mês

**Alternativa:** SSM Parameter Store (grátis para Standard parameters)

---

## 💰 Estimativa Total de Custos

### Cenário 1: Uso Esporádico (Recomendado para Aprendizado)

**Perfil:**
- Uso: 8 horas/dia, 5 dias/semana (40h/mês)
- Instância: db.t4g.small
- Storage: 20 GB
- I/O: Leve
- Destruir quando não usar

| Item | Cálculo | Custo/Mês |
|------|---------|-----------|
| **Compute** | $0.082/h × 40h | $3.28 |
| **Storage** | 20 GB × $0.10 | $2.00 |
| **I/O** | 2M req × $0.20 | $0.40 |
| **Backup** | Incluído | $0.00 |
| **Secrets** | 3 × $0.40 | $1.20 |
| **Transfer** | <100 GB | $0.00 |
| **TOTAL** | | **$6.88/mês** |

**Custo por hora de uso:** ~$0.17/h

---

### Cenário 2: Uso Intensivo (Testes Prolongados)

**Perfil:**
- Uso: 8 horas/dia, 20 dias/mês (160h/mês)
- Instância: db.t4g.small
- Storage: 20 GB
- I/O: Moderado

| Item | Cálculo | Custo/Mês |
|------|---------|-----------|
| **Compute** | $0.082/h × 160h | $13.12 |
| **Storage** | 20 GB × $0.10 | $2.00 |
| **I/O** | 10M req × $0.20 | $2.00 |
| **Backup** | Incluído | $0.00 |
| **Secrets** | 3 × $0.40 | $1.20 |
| **Transfer** | <100 GB | $0.00 |
| **TOTAL** | | **$18.32/mês** |

---

### Cenário 3: 24/7 (Não Recomendado para Testes)

**Perfil:**
- Uso: 24/7 (730h/mês)
- Instância: db.t4g.small

| Item | Cálculo | Custo/Mês |
|------|---------|-----------|
| **Compute** | $0.082/h × 730h | $59.86 |
| **Storage** | 20 GB × $0.10 | $2.00 |
| **I/O** | 50M req × $0.20 | $10.00 |
| **Secrets** | 3 × $0.40 | $1.20 |
| **TOTAL** | | **$73.06/mês** |

❌ **Não recomendado:** Destrua quando não usar!

---

### Cenário 4: Aurora Serverless v2 (Alternativa)

**Perfil:**
- ACU mínimo: 0.5 (0.5 vCPU, 1 GB RAM)
- ACU máximo: 1.0
- Uso: 40h/mês

| Item | Cálculo | Custo/Mês |
|------|---------|-----------|
| **Compute** | $0.12/ACU-h × 0.5 ACU × 40h | $2.40 |
| **Storage** | 20 GB × $0.10 | $2.00 |
| **I/O** | 2M req × $0.20 | $0.40 |
| **Secrets** | 3 × $0.40 | $1.20 |
| **TOTAL** | | **$6.00/mês** |

✅ **Vantagem:** Escala automaticamente, pode ir para 0 ACU (mas ainda cobra storage)

---

## 🎯 Recomendação Final para Seu Caso

### Configuração Ideal

```hcl
# Terraform - Aurora PostgreSQL para Testes
resource "aws_rds_cluster" "fluxo_caixa" {
  cluster_identifier      = "fluxo-caixa-test"
  engine                  = "aurora-postgresql"
  engine_version          = "15.4"
  database_name           = "fluxocaixa"
  master_username         = "postgres"
  master_password         = data.aws_secretsmanager_secret_version.db_password.secret_string
  
  storage_encrypted       = true
  backup_retention_period = 1  # Mínimo para testes
  preferred_backup_window = "03:00-04:00"
  
  skip_final_snapshot     = true  # Para testes
  
  # Custo zero quando parado
  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }
  
  tags = {
    Environment = "test"
    Purpose     = "migration-learning"
    AutoDestroy = "true"
  }
}

resource "aws_rds_cluster_instance" "fluxo_caixa" {
  identifier         = "fluxo-caixa-test-instance"
  cluster_identifier = aws_rds_cluster.fluxo_caixa.id
  instance_class     = "db.t4g.small"  # $0.082/h
  engine             = aws_rds_cluster.fluxo_caixa.engine
  engine_version     = aws_rds_cluster.fluxo_caixa.engine_version
}
```

### Custo Estimado

| Período | Horas de Uso | Custo Estimado |
|---------|--------------|----------------|
| **Por hora** | 1h | $0.17 |
| **Por dia** (8h) | 8h | $1.36 |
| **Por semana** (5 dias × 8h) | 40h | $6.80 |
| **Por mês** (20 dias × 8h) | 160h | $18.32 |

**Custo mínimo mensal (apenas storage quando destruído):** $2.00-$3.00

---

## 💡 Estratégias de Otimização de Custos

### 1. Terraform Destroy Automático

```bash
# Criar quando precisar
terraform apply

# Trabalhar (8 horas)
# ...

# Destruir ao final do dia
terraform destroy -auto-approve
```

**Economia:** ~70% (paga apenas compute quando usa)

---

### 2. Usar AWS Free Tier (Novo Cliente)

**Se você é novo na AWS:**
- 750 horas/mês de db.t3.micro (12 meses)
- 20 GB de storage
- 20 GB de backup

**Custo:** $0.00 nos primeiros 12 meses (exceto I/O e Secrets)

❌ **Limitação:** Aurora não está no Free Tier, mas RDS PostgreSQL está!

**Alternativa:** Use RDS PostgreSQL para aprender, depois migre para Aurora

---

### 3. Usar RDS PostgreSQL ao Invés de Aurora

**RDS PostgreSQL (Free Tier):**
- db.t3.micro: Grátis (750h/mês por 12 meses)
- 20 GB storage: Grátis
- 20 GB backup: Grátis

**Custo:** $0.00 (primeiro ano)

**Depois do Free Tier:**
- db.t4g.micro: $0.018/h ($13.14/mês 24/7)
- Storage: $0.115/GB/mês
- **Total 24/7:** ~$15-20/mês

**Vantagem:** Aprende migração, Terraform, Secrets por $0 no primeiro ano

---

### 4. Usar SSM Parameter Store ao Invés de Secrets Manager

```hcl
# Grátis (até 10.000 parameters)
resource "aws_ssm_parameter" "db_password" {
  name  = "/fluxo-caixa/db/password"
  type  = "SecureString"
  value = random_password.db_password.result
}
```

**Economia:** $1.20/mês

---

### 5. Snapshot Antes de Destruir

```bash
# Criar snapshot manual antes de destruir
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier fluxo-caixa-test \
  --db-cluster-snapshot-identifier fluxo-caixa-backup-$(date +%Y%m%d)

# Destruir cluster
terraform destroy

# Restaurar quando precisar
terraform apply -var="restore_from_snapshot=fluxo-caixa-backup-20251021"
```

**Custo do snapshot:** $0.021/GB/mês (~$0.21 para 10 GB)

---

### 6. Usar Região Mais Barata

| Região | db.t4g.small/h | Economia vs us-east-1 |
|--------|----------------|----------------------|
| **us-east-1** (N. Virginia) | $0.082 | Base |
| **us-east-2** (Ohio) | $0.082 | 0% |
| **us-west-2** (Oregon) | $0.082 | 0% |
| **sa-east-1** (São Paulo) | $0.134 | -63% (mais caro!) |

**Recomendação:** us-east-1 (N. Virginia) ou us-east-2 (Ohio)

---

## 📊 Comparação: Aurora vs RDS PostgreSQL

| Aspecto | Aurora PostgreSQL | RDS PostgreSQL |
|---------|-------------------|----------------|
| **Custo mínimo/mês** | ~$18 (160h) | ~$3 (160h) ou $0 (Free Tier) |
| **Performance** | Até 3x mais rápido | Padrão PostgreSQL |
| **Escalabilidade** | Até 128 TB | Até 64 TB |
| **Réplicas** | Até 15 read replicas | Até 5 read replicas |
| **Backup** | Contínuo, até 35 dias | Snapshots, até 35 dias |
| **Failover** | <30 segundos | 1-2 minutos |
| **Free Tier** | ❌ Não | ✅ Sim (12 meses) |
| **Aprendizado** | ✅ Tecnologia AWS | ✅ PostgreSQL padrão |

**Para testes e aprendizado:** RDS PostgreSQL (Free Tier)  
**Para produção ou aprender Aurora:** Aurora (pagar)

---

## 🎯 Plano de Ação Recomendado

### Fase 1: Aprendizado Inicial (Custo: $0)

1. **Usar RDS PostgreSQL Free Tier**
   - db.t3.micro (grátis por 12 meses)
   - Aprender Terraform
   - Aprender AWS Secrets Manager (ou SSM)
   - Testar DMS e SCT

**Duração:** 1-3 meses  
**Custo:** $0.00

---

### Fase 2: Migração para Aurora (Custo: $6-18/mês)

2. **Criar Aurora para Validação**
   - db.t4g.small
   - Usar apenas quando necessário (destruir após uso)
   - Validar diferenças Aurora vs RDS
   - Testar performance

**Duração:** 1-2 meses  
**Custo:** $6-18/mês (dependendo do uso)

---

### Fase 3: Testes Avançados (Custo: $18-30/mês)

3. **Testes de Performance e IA**
   - Usar Aurora com IA da AWS
   - Converter procedures complexas
   - Testar Bedrock para otimização de queries
   - Validar migração completa

**Duração:** 1 mês  
**Custo:** $18-30/mês

---

## 💰 Custo Total Estimado do Projeto

| Fase | Duração | Custo/Mês | Custo Total |
|------|---------|-----------|-------------|
| **Fase 1** (RDS Free Tier) | 2 meses | $0 | $0 |
| **Fase 2** (Aurora Testes) | 2 meses | $12 | $24 |
| **Fase 3** (Validação Final) | 1 mês | $25 | $25 |
| **TOTAL** | **5 meses** | - | **$49** |

**Custo médio mensal:** $9.80/mês

---

## 🔧 Ferramentas de Controle de Custos

### 1. AWS Cost Explorer

```bash
# Ver custos dos últimos 30 dias
aws ce get-cost-and-usage \
  --time-period Start=2025-09-21,End=2025-10-21 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

---

### 2. AWS Budgets

```hcl
resource "aws_budgets_budget" "aurora_monthly" {
  name              = "aurora-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "20.00"  # Alerta se passar de $20
  limit_unit        = "USD"
  time_period_start = "2025-10-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80  # Alerta em 80% ($16)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["seu-email@example.com"]
  }
}
```

---

### 3. Tagging para Rastreamento

```hcl
tags = {
  Project     = "fluxo-caixa-migration"
  Environment = "test"
  CostCenter  = "learning"
  AutoDestroy = "true"
  Owner       = "seu-nome"
}
```

---

## 📋 Checklist de Controle de Custos

- [ ] Escolher RDS PostgreSQL (Free Tier) para início
- [ ] Configurar AWS Budget com alerta ($20/mês)
- [ ] Usar SSM Parameter Store ao invés de Secrets Manager
- [ ] Destruir recursos ao final de cada sessão
- [ ] Criar snapshots antes de destruir
- [ ] Usar região us-east-1 ou us-east-2
- [ ] Monitorar custos semanalmente (Cost Explorer)
- [ ] Documentar custos reais vs estimados
- [ ] Configurar tags em todos os recursos
- [ ] Revisar custos mensalmente

---

## 🎓 Aprendizados Esperados

Ao final do projeto, você terá aprendido:

✅ **Terraform:**
- Criar infraestrutura como código
- Gerenciar estado (state file)
- Usar variáveis e outputs
- Módulos reutilizáveis

✅ **AWS:**
- RDS e Aurora PostgreSQL
- Secrets Manager / SSM Parameter Store
- VPC, Security Groups, Subnets
- DMS (Database Migration Service)
- SCT (Schema Conversion Tool)
- Cost management

✅ **Migração:**
- Planejamento de migração
- Conversão de schema
- Migração de dados (Full Load + CDC)
- Validação de integridade
- Rollback strategies

✅ **Custos:**
- Estimativa de custos AWS
- Otimização de recursos
- Monitoramento de gastos
- Estratégias de economia

---

## 📚 Próximos Passos

1. ✅ **Criar conta AWS** (se não tiver)
2. ✅ **Habilitar Free Tier** (RDS PostgreSQL)
3. ✅ **Instalar AWS CLI e Terraform**
4. ✅ **Criar primeiro projeto Terraform**
5. ✅ **Provisionar RDS PostgreSQL**
6. ✅ **Testar migração com DMS**
7. ✅ **Documentar custos reais**
8. ✅ **Migrar para Aurora** (quando confortável)

---

## 🔗 Recursos Úteis

- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS Aurora Pricing](https://aws.amazon.com/rds/aurora/pricing/)
- [AWS RDS Pricing](https://aws.amazon.com/rds/postgresql/pricing/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/)
- [AWS SCT Documentation](https://docs.aws.amazon.com/SchemaConversionTool/)

---

**Criado em:** 2025-10-21  
**Última atualização:** 2025-10-21  
**Versão:** 1.0

