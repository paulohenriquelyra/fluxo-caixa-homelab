# ==============================================================================
# MÓDULO: RDS POSTGRESQL (FONTE PARA MIGRAÇÃO DMS)
# ==============================================================================
#
# Este módulo provisiona uma instância RDS PostgreSQL que será usada como FONTE
# em uma migração DMS para Aurora. É um ambiente TEMPORÁRIO para simulação e
# aprendizado.
#
# IMPORTANTE: Este RDS é apenas para TESTES. Não use em produção!

# ==============================================================================
# DB SUBNET GROUP
# ==============================================================================
#
# O Subnet Group define em quais subnets da VPC o RDS pode ser criado.
# Usamos as subnets PRIVADAS para garantir que o RDS não seja acessível
# diretamente pela internet.

resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-${var.environment}-rds-source-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-source-subnet-group"
    }
  )
}

# ==============================================================================
# DB PARAMETER GROUP (CONFIGURAÇÃO PARA CDC)
# ==============================================================================
#
# O Parameter Group permite customizar parâmetros do PostgreSQL.
# Para CDC (Change Data Capture) funcionar com DMS, precisamos configurar:
#
# 1. wal_level = logical
#    - Habilita o Write-Ahead Log (WAL) em modo lógico
#    - Permite que o DMS capture as mudanças (INSERT, UPDATE, DELETE)
#    - Sem isso, o CDC NÃO funciona!
#
# 2. max_replication_slots = 10
#    - Define quantos "slots de replicação" podem existir
#    - Cada tarefa DMS usa 1 slot
#    - 10 é suficiente para múltiplas tarefas de teste
#
# 3. max_wal_senders = 10
#    - Define quantos processos podem enviar dados do WAL
#    - Deve ser >= max_replication_slots
#    - Permite múltiplas conexões de replicação simultâneas

resource "aws_db_parameter_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-rds-source-pg-params"
  family      = "postgres15" # Família do PostgreSQL 15.x
  description = "Parâmetros otimizados para CDC com DMS"

  # Parâmetro OBRIGATÓRIO para CDC
  parameter {
    name         = "wal_level"
    value        = "logical"
    apply_method = "immediate" # Aplica imediatamente (requer reinicialização)
  }

  # Número de slots de replicação
  parameter {
    name         = "max_replication_slots"
    value        = "10"
    apply_method = "immediate"
  }

  # Número de processos WAL sender
  parameter {
    name         = "max_wal_senders"
    value        = "10"
    apply_method = "immediate"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-source-pg-params"
    }
  )
}

# ==============================================================================
# RDS POSTGRESQL INSTANCE
# ==============================================================================
#
# Instância RDS PostgreSQL configurada para ser a FONTE em uma migração DMS.
#
# DECISÕES DE ARQUITETURA:
#
# 1. INSTÂNCIA: db.t4g.micro
#    - Menor instância disponível para PostgreSQL
#    - 2 vCPUs (ARM Graviton2) + 1 GB RAM
#    - Custo: ~$0.016/hora = $11.52/mês
#    - Adequada APENAS para testes
#
# 2. STORAGE: 20 GB gp3
#    - Mínimo permitido para gp3
#    - gp3 é mais barato que io1 e adequado para testes
#    - 3000 IOPS baseline (suficiente para migração)
#
# 3. BACKUP: DESABILITADO
#    - backup_retention_period = 0
#    - Economiza custos de armazenamento
#    - Aceitável para ambiente temporário
#    - EM PRODUÇÃO: Use 7-35 dias de retenção!
#
# 4. MULTI-AZ: DESABILITADO
#    - multi_az = false
#    - Reduz custo pela metade
#    - Sem alta disponibilidade
#    - EM PRODUÇÃO: SEMPRE use multi_az = true!
#
# 5. ACESSO PÚBLICO: DESABILITADO
#    - publicly_accessible = false
#    - Segurança: RDS não é acessível pela internet
#    - Acesso apenas via VPC (DMS, bastion, etc.)
#
# 6. PROTEÇÃO: DESABILITADA
#    - deletion_protection = false
#    - skip_final_snapshot = true
#    - Facilita destruição do ambiente de teste
#    - EM PRODUÇÃO: SEMPRE habilite proteções!

resource "aws_db_instance" "default" {
  # Identificação
  identifier = "${var.project_name}-${var.environment}-rds-source"

  # Engine e versão
  engine         = "postgres"
  engine_version = "15.4" # Versão específica (compatível com Aurora 15.x)

  # Tipo de instância e armazenamento
  instance_class    = "db.t4g.micro" # Menor instância disponível
  allocated_storage = 20              # Mínimo para gp3
  storage_type      = "gp3"           # Tipo de armazenamento

  # Credenciais do banco
  db_name  = var.db_name     # Nome do banco de dados
  username = var.db_username # Usuário master
  password = var.db_password # Senha (vem de variável sensível)

  # Rede e segurança
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [var.dms_security_group_id]
  publicly_accessible    = false # Não expor para internet

  # Configuração de parâmetros
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Backup e manutenção
  backup_retention_period = 0     # Sem backups (economia)
  skip_final_snapshot     = true  # Não criar snapshot ao destruir
  deletion_protection     = false # Permitir destruição fácil

  # Alta disponibilidade
  multi_az = false # Desabilitado (economia)

  # Tags
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-rds-source"
      Purpose     = "DMS Source - Temporary"
      Environment = "Test"
    }
  )
}

# ==============================================================================
# CONSIDERAÇÕES IMPORTANTES
# ==============================================================================
#
# 1. CUSTO ESTIMADO (us-east-1):
#    - Instância db.t4g.micro: $0.016/hora = $11.52/mês
#    - Storage 20 GB gp3: $0.16/mês
#    - TOTAL: ~$11.68/mês ou $0.39/dia
#
# 2. SEGURANÇA:
#    - O Security Group (dms_security_group_id) DEVE permitir:
#      * Porta 5432 (PostgreSQL)
#      * Origem: Security Group da instância DMS
#    - NÃO use regras 0.0.0.0/0 (inseguro!)
#
# 3. CDC (CHANGE DATA CAPTURE):
#    - Os parâmetros wal_level, max_replication_slots e max_wal_senders
#      são OBRIGATÓRIOS para o DMS capturar mudanças em tempo real
#    - Após criar o RDS, o DMS criará automaticamente um slot de replicação
#
# 4. PERFORMANCE:
#    - db.t4g.micro tem CPU "burstable" (créditos de CPU)
#    - Adequado para testes leves
#    - Para cargas maiores, use db.t4g.small ou db.r6g.large
#
# 5. COMPATIBILIDADE:
#    - PostgreSQL 15.4 é compatível com Aurora PostgreSQL 15.x
#    - DMS suporta migração entre versões iguais ou próximas
#
# 6. DESTRUIÇÃO:
#    - Para destruir: terraform destroy
#    - Não haverá snapshot final (skip_final_snapshot = true)
#    - Todos os dados serão perdidos permanentemente
#
# 7. PRODUÇÃO:
#    - NÃO use esta configuração em produção!
#    - Habilite: multi_az, backup_retention_period, deletion_protection
#    - Use instâncias maiores (db.r6g.large ou superior)
#    - Configure monitoramento (CloudWatch, Enhanced Monitoring)

