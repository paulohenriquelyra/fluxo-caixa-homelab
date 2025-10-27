# Guia Completo: Migração com RDS Fonte + DMS + CDC

Este guia detalha como usar um **RDS PostgreSQL temporário na AWS** como fonte para simular uma migração completa com DMS e CDC (Change Data Capture) para o Aurora.

---

## 🎯 Objetivo

Simular uma migração real de banco de dados usando:
- **RDS PostgreSQL** (simula seu Homelab)
- **AWS DMS** (Database Migration Service)
- **Aurora PostgreSQL** (destino final)
- **CDC** (Change Data Capture - replicação em tempo real)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌──────────────────┐                    ┌────────────────┐ │
│  │  RDS PostgreSQL  │    DMS (CDC)       │ Aurora         │ │
│  │  (Fonte)         │ ─────────────────> │ PostgreSQL     │ │
│  │                  │  Full Load + CDC   │ (Destino)      │ │
│  │  db.t4g.micro    │                    │ db.t4g.medium  │ │
│  │  $0.016/hora     │                    │ $0.073/hora    │ │
│  └──────────────────┘                    └────────────────┘ │
│         ▲                                                    │
│         │                                                    │
│         │ Restaurar dump do Homelab                         │
│         │                                                    │
└─────────┴────────────────────────────────────────────────────┘
```

---

## 💰 Custo Estimado (3 dias)

| Recurso | Custo/hora | 72h |
|---------|------------|-----|
| RDS PostgreSQL (fonte) | $0.016 | $1.15 |
| Aurora (destino) | $0.073 | $5.26 |
| DMS Replication | $0.164 | $11.81 |
| NAT Gateway | $0.045 | $3.24 |
| **TOTAL** | | **$21.46** |

---

## 📋 Pré-requisitos

1. ✅ Terraform instalado (>= 1.6.0)
2. ✅ AWS CLI configurada
3. ✅ PostgreSQL client (psql, pg_dump, pg_restore)
4. ✅ Dump do banco de dados do Homelab

---

## 🚀 Passo a Passo

### **Fase 1: Provisionar Infraestrutura Base**

#### 1.1. Configurar Variáveis

Edite `terraform/aws/environments/dev/terraform.tfvars`:

```hcl
# Configurações básicas
project_name = "fluxo-caixa"
environment = "dev"
aws_region = "us-east-1"

# Senha do RDS fonte (escolha uma senha forte)
rds_source_password = "SuaSenhaForteAqui123!"

# Senha do Aurora (será preenchida depois)
target_db_password = "PREENCHER_DEPOIS"
```

#### 1.2. Primeiro Deploy (Rede + Aurora + RDS Fonte)

**IMPORTANTE:** Comente o módulo `dms` no `main.tf` antes do primeiro deploy.

```bash
cd terraform/aws/scripts
./deploy.sh
```

Aguarde 10-15 minutos para a criação dos recursos.

#### 1.3. Obter Senha do Aurora

```bash
cd ../environments/dev
terraform output aurora_master_password_secret_arn

# Use o ARN para obter a senha
aws secretsmanager get-secret-value \
  --secret-id "ARN_AQUI" \
  --query SecretString \
  --output text
```

Atualize o `terraform.tfvars` com a senha do Aurora.

---

### **Fase 2: Restaurar Dump no RDS Fonte**

#### 2.1. Fazer Dump do Homelab

No seu Homelab:

```bash
# Dump em formato SQL (texto)
pg_dump -h 10.0.2.17 -U postgres -d fluxocaixa > fluxocaixa_backup.sql

# OU dump em formato custom (binário - mais rápido)
pg_dump -h 10.0.2.17 -U postgres -d fluxocaixa -F c -f fluxocaixa_backup.dump
```

#### 2.2. Transferir Dump para Máquina Local

```bash
scp usuario@homelab:/caminho/fluxocaixa_backup.sql ~/
```

#### 2.3. Restaurar no RDS Fonte

```bash
cd terraform/aws/scripts
./restore-to-rds.sh ~/fluxocaixa_backup.sql
```

O script irá:
- Obter o endpoint do RDS fonte automaticamente
- Solicitar a senha
- Restaurar o dump
- Validar a restauração

---

### **Fase 3: Configurar e Executar DMS**

#### 3.1. Segundo Deploy (Criar Recursos DMS)

Descomente o módulo `dms` no `main.tf` e execute:

```bash
cd terraform/aws/scripts
./deploy.sh
```

Aguarde 5-10 minutos para a criação da instância DMS.

#### 3.2. Iniciar Migração

```bash
./migrate.sh
```

O script irá:
- Obter o ARN da tarefa DMS
- Verificar o status
- Iniciar a migração (Full Load + CDC)

#### 3.3. Monitorar Migração

**Opção 1: Console da AWS**
- Acesse: AWS Console → DMS → Database migration tasks
- Clique na tarefa `fluxo-caixa-replication-task`
- Monitore o progresso na aba "Table statistics"

**Opção 2: AWS CLI**
```bash
aws dms describe-replication-tasks \
  --filters "Name=replication-task-arn,Values=ARN_DA_TAREFA" \
  --query 'ReplicationTasks[0].[Status,ReplicationTaskStats]'
```

---

### **Fase 4: Testar CDC (Change Data Capture)**

Após a migração inicial (Full Load) completar:

#### 4.1. Executar Teste Automatizado

```bash
./test-cdc.sh
```

O script irá:
1. Inserir um registro no RDS fonte
2. Aguardar 5 segundos
3. Verificar se apareceu no Aurora
4. Atualizar o registro no RDS
5. Verificar se a atualização foi replicada
6. Deletar o registro no RDS
7. Verificar se a deleção foi replicada

#### 4.2. Teste Manual

**No RDS Fonte:**
```sql
-- Conectar ao RDS fonte
psql -h RDS_ENDPOINT -U postgres -d fluxocaixa

-- Inserir registro
INSERT INTO transacoes (descricao, valor, data, tipo, conta_id, categoria_id)
VALUES ('Teste CDC Manual', 500.00, NOW(), 'RECEITA', 1, 1);
```

**No Aurora (após 5-10 segundos):**
```sql
-- Conectar ao Aurora
psql -h AURORA_ENDPOINT -U masteruser -d fluxocaixa

-- Verificar se o registro apareceu
SELECT * FROM transacoes WHERE descricao = 'Teste CDC Manual';
```

Se o registro aparecer, o CDC está funcionando! 🎉

---

### **Fase 5: Validação Completa**

#### 5.1. Comparar Contagens

```sql
-- No RDS e no Aurora, execute:
SELECT 'transacoes' AS tabela, COUNT(*) FROM transacoes
UNION ALL
SELECT 'contas', COUNT(*) FROM contas
UNION ALL
SELECT 'categorias', COUNT(*) FROM categorias;
```

Os números devem ser idênticos.

#### 5.2. Testar Views e Procedures

```sql
-- Testar view
SELECT * FROM vw_saldo_diario_por_conta LIMIT 10;

-- Testar function
SELECT * FROM fn_extrato_conta(1, '2023-01-01', '2023-12-31');

-- Testar procedure (se aplicável)
CALL sp_calcular_saldos();
```

---

### **Fase 6: Limpeza e Destruição**

#### 6.1. Parar Tarefa DMS (Opcional)

```bash
aws dms stop-replication-task --replication-task-arn ARN_DA_TAREFA
```

#### 6.2. Destruir Toda a Infraestrutura

```bash
cd terraform/aws/scripts
./destroy.sh
```

Digite `sim` para confirmar. Aguarde 15-20 minutos.

#### 6.3. Verificar Destruição

Acesse o console da AWS e confirme que todos os recursos foram removidos:
- VPC
- RDS
- Aurora
- DMS
- NAT Gateway
- Secrets Manager

---

## 🎓 O Que Você Aprendeu

✅ Provisionar infraestrutura AWS com Terraform  
✅ Criar e configurar RDS PostgreSQL para CDC  
✅ Configurar AWS DMS (endpoints, instância, tarefa)  
✅ Executar migração Full Load  
✅ Testar CDC (Change Data Capture) em tempo real  
✅ Validar integridade de dados após migração  
✅ Monitorar e troubleshoot migrações  
✅ Destruir infraestrutura de forma segura  

---

## 🔧 Troubleshooting

### Problema: Tarefa DMS falha ao conectar no RDS

**Solução:**
- Verifique se o Security Group do DMS permite acesso ao RDS na porta 5432
- Confirme que o RDS está na mesma VPC que o DMS
- Teste conectividade manualmente

### Problema: CDC não está replicando mudanças

**Solução:**
- Verifique se `wal_level = logical` está configurado no RDS
- Confirme que a tarefa DMS está com status "running"
- Verifique logs do DMS no CloudWatch

### Problema: Latência alta na replicação

**Solução:**
- Aumente a instância DMS (de t3.medium para t3.large)
- Verifique se há muitas transações simultâneas
- Monitore CPU e memória da instância DMS

---

## 📚 Próximos Passos

1. **Documentar aprendizados** em um arquivo markdown
2. **Praticar troubleshooting** causando falhas propositalmente
3. **Testar diferentes cenários** (tabelas grandes, muitas transações, etc.)
4. **Aplicar conhecimento** no projeto real da próxima semana

---

**Criado por:** Manus AI (Gemini + Grok)  
**Data:** Outubro de 2025  
**Propósito:** Preparação para migração de produção

