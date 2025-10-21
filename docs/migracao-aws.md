# Guia de Migração para AWS Aurora

Este documento descreve o processo de migração do banco de dados PostgreSQL do homelab para AWS Aurora.

---

## Objetivo

Migrar o banco de dados PostgreSQL 15 rodando no Kubernetes do homelab para AWS Aurora PostgreSQL, utilizando:

- **AWS Database Migration Service (DMS)** para movimentação de dados
- **AWS Schema Conversion Tool (SCT)** para análise e conversão de schema
- **Ferramentas de IA da AWS** para conversão de procedures e views

---

## Arquitetura de Migração

```
┌─────────────────────────────────┐
│      Homelab (Origem)           │
│  ┌──────────────────────────┐   │
│  │  PostgreSQL 15           │   │
│  │  - Schema complexo       │   │
│  │  - Views                 │   │
│  │  - Procedures            │   │
│  │  - Functions             │   │
│  └──────────────────────────┘   │
└─────────────┬───────────────────┘
              │
              │ VPN / Direct Connect
              │ (ou Internet com SSL)
              ↓
┌─────────────────────────────────┐
│         AWS DMS                 │
│  ┌──────────────────────────┐   │
│  │  Replication Instance    │   │
│  │  - CDC (Change Data      │   │
│  │    Capture)              │   │
│  └──────────────────────────┘   │
└─────────────┬───────────────────┘
              │
              ↓
┌─────────────────────────────────┐
│      AWS (Destino)              │
│  ┌──────────────────────────┐   │
│  │  Aurora PostgreSQL 15    │   │
│  │  - Schema migrado        │   │
│  │  - Dados replicados      │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

---

## Fases da Migração

### Fase 1: Preparação (Pré-Migração)

#### 1.1. Análise do Schema com SCT

```bash
# Instalar AWS SCT
# https://docs.aws.amazon.com/SchemaConversionTool/latest/userguide/CHAP_Installing.html

# Conectar ao PostgreSQL de origem
# Analisar compatibilidade com Aurora PostgreSQL
# Gerar relatório de conversão
```

**Pontos de Atenção:**
- Views complexas com window functions
- Stored procedures com lógica de negócio
- Functions customizadas em PL/pgSQL
- Triggers e constraints

#### 1.2. Provisionar Infraestrutura AWS com Terraform

```hcl
# terraform/main.tf

# VPC e Subnets
# Aurora PostgreSQL Cluster
# DMS Replication Instance
# Security Groups
# IAM Roles
```

**Recursos Necessários:**
- VPC com subnets privadas (multi-AZ)
- Aurora PostgreSQL cluster (db.t3.medium ou maior)
- DMS Replication Instance (dms.t3.medium)
- S3 bucket para logs e backups

#### 1.3. Configurar Conectividade

**Opção 1: VPN Site-to-Site**
- Mais segura
- Baixa latência
- Custo adicional

**Opção 2: Internet com SSL**
- Mais simples
- Gratuita
- Requer exposição do PostgreSQL (com SSL obrigatório)

---

### Fase 2: Migração de Schema

#### 2.1. Exportar Schema do PostgreSQL

```bash
# Exportar schema (sem dados)
kubectl exec -it postgres-0 -n fluxo-caixa -- \
  pg_dump -U postgres -d fluxocaixa \
  --schema-only \
  --no-owner \
  --no-privileges \
  -f /tmp/schema.sql

# Copiar para local
kubectl cp fluxo-caixa/postgres-0:/tmp/schema.sql ./schema.sql
```

#### 2.2. Converter Schema com SCT

1. Importar schema no SCT
2. Analisar relatório de conversão
3. Revisar e ajustar incompatibilidades
4. Gerar script SQL para Aurora

**Incompatibilidades Comuns:**
- Tipos de dados específicos do PostgreSQL
- Extensões não suportadas
- Sintaxe de procedures

#### 2.3. Aplicar Schema no Aurora

```bash
# Conectar ao Aurora
psql -h aurora-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U postgres \
     -d fluxocaixa \
     -f schema_converted.sql
```

---

### Fase 3: Migração de Dados com DMS

#### 3.1. Configurar Endpoints no DMS

**Source Endpoint (PostgreSQL Homelab):**
```json
{
  "EndpointType": "source",
  "EngineName": "postgres",
  "ServerName": "seu-ip-publico-ou-vpn",
  "Port": 5432,
  "DatabaseName": "fluxocaixa",
  "Username": "postgres",
  "Password": "***",
  "SslMode": "require"
}
```

**Target Endpoint (Aurora):**
```json
{
  "EndpointType": "target",
  "EngineName": "aurora-postgresql",
  "ServerName": "aurora-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com",
  "Port": 5432,
  "DatabaseName": "fluxocaixa",
  "Username": "postgres",
  "Password": "***"
}
```

#### 3.2. Criar Replication Task

**Configurações:**
- **Migration Type:** Full load + CDC (Change Data Capture)
- **Table Mappings:** Selecionar todas as tabelas
- **LOB Settings:** Limited LOB mode
- **Validation:** Habilitado

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-all-tables",
      "object-locator": {
        "schema-name": "public",
        "table-name": "%"
      },
      "rule-action": "include"
    }
  ]
}
```

#### 3.3. Executar Migração

1. **Full Load:** Copiar todos os dados existentes
2. **CDC:** Replicar mudanças em tempo real
3. **Validação:** Comparar contagem de registros

**Monitoramento:**
```bash
# CloudWatch Metrics
- ReplicationInstanceCPU
- ReplicationInstanceMemory
- CDCLatencySource
- CDCLatencyTarget
```

---

### Fase 4: Conversão de Procedures com IA

#### 4.1. Usar AWS CodeWhisperer ou Bedrock

```python
# Exemplo: Converter procedure usando Bedrock
import boto3

bedrock = boto3.client('bedrock-runtime')

prompt = f"""
Converta a seguinte stored procedure PostgreSQL para ser compatível com Aurora PostgreSQL:

{procedure_code}

Mantenha a mesma lógica de negócio e otimize para performance.
"""

response = bedrock.invoke_model(
    modelId='anthropic.claude-v2',
    body=json.dumps({
        'prompt': prompt,
        'max_tokens': 2000
    })
)
```

#### 4.2. Revisar e Testar

- Comparar resultado da IA com código original
- Executar testes unitários
- Validar lógica de negócio

---

### Fase 5: Validação e Cutover

#### 5.1. Validação de Dados

```sql
-- Comparar contagem de registros
SELECT 'transacoes' as tabela, COUNT(*) FROM transacoes
UNION ALL
SELECT 'categorias', COUNT(*) FROM categorias
UNION ALL
SELECT 'usuarios', COUNT(*) FROM usuarios;

-- Comparar saldos
SELECT * FROM vw_saldo_atual;

-- Validar integridade referencial
SELECT 
    COUNT(*) as transacoes_sem_categoria
FROM transacoes 
WHERE categoria_id IS NOT NULL 
  AND categoria_id NOT IN (SELECT id FROM categorias);
```

#### 5.2. Testes de Performance

```bash
# Benchmark de queries
pgbench -h aurora-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
        -U postgres \
        -d fluxocaixa \
        -c 10 \
        -j 2 \
        -T 60
```

#### 5.3. Plano de Cutover

**Janela de Manutenção:**
1. Colocar aplicação em modo read-only
2. Aguardar CDC sincronizar últimas mudanças
3. Validar dados no Aurora
4. Atualizar connection string da aplicação
5. Reiniciar aplicação apontando para Aurora
6. Monitorar por 24-48h
7. Desativar DMS replication task

---

## Estimativa de Custos (Mensal)

| Recurso | Especificação | Custo Estimado (USD) |
|---------|---------------|----------------------|
| Aurora PostgreSQL | db.t3.medium (2 vCPU, 4GB) | ~$70 |
| DMS Replication Instance | dms.t3.medium (durante migração) | ~$50 (apenas durante migração) |
| Storage (Aurora) | 20 GB | ~$2 |
| Backup (Aurora) | 20 GB | ~$2 |
| Data Transfer | 10 GB/mês | ~$1 |
| **Total** | | **~$75/mês** (após migração) |

**Custo One-Time (Migração):** ~$50-100 (DMS por 1-2 semanas)

---

## Otimizações de Custo

1. **Usar Aurora Serverless v2** para cargas variáveis
2. **Parar cluster Aurora** quando não estiver em uso (lab)
3. **Usar Spot Instances** para DMS (se disponível)
4. **Limpar snapshots antigos** automaticamente
5. **Monitorar com AWS Cost Explorer**

---

## Rollback Plan

Em caso de problemas:

1. Manter PostgreSQL do homelab rodando por 1 semana
2. Manter DMS replication task ativa (bidirecional se necessário)
3. Ter backup do Aurora antes do cutover
4. Documentar connection strings antigas

---

## Checklist de Migração

### Pré-Migração
- [ ] Analisar schema com SCT
- [ ] Provisionar infraestrutura AWS
- [ ] Configurar conectividade (VPN ou SSL)
- [ ] Fazer backup completo do PostgreSQL origem

### Migração
- [ ] Aplicar schema no Aurora
- [ ] Configurar endpoints DMS
- [ ] Executar Full Load
- [ ] Ativar CDC
- [ ] Validar dados

### Pós-Migração
- [ ] Converter procedures com IA
- [ ] Executar testes de validação
- [ ] Realizar testes de performance
- [ ] Atualizar aplicação
- [ ] Monitorar por 48h
- [ ] Desativar DMS
- [ ] Documentar lições aprendidas

---

## Referências

- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/)
- [AWS SCT User Guide](https://docs.aws.amazon.com/SchemaConversionTool/)
- [Aurora PostgreSQL Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.BestPractices.html)
- [PostgreSQL to Aurora Migration Guide](https://docs.aws.amazon.com/dms/latest/sbs/chap-postgresql2aurora.html)

---

## Contato

Para dúvidas sobre este projeto de migração:
- **Autor:** Paulo Lyra
- **Email:** paulo.lyra@gmail.com

