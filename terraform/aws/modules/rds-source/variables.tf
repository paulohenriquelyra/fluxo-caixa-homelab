# ==============================================================================
# VARIÁVEIS DO MÓDULO RDS-SOURCE
# ==============================================================================

variable "project_name" {
  type        = string
  description = "Nome do projeto. Usado para nomear recursos."
}

variable "environment" {
  type        = string
  description = "Ambiente (dev, staging, prod). Usado para nomear recursos e aplicar configurações específicas."
}

variable "vpc_id" {
  type        = string
  description = "ID da VPC onde o RDS será criado."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Lista de IDs das subnets privadas onde o RDS pode ser criado. Deve haver pelo menos 2 subnets em AZs diferentes."
}

variable "dms_security_group_id" {
  type        = string
  description = "ID do Security Group da instância DMS. Este SG será anexado ao RDS para permitir que o DMS se conecte."
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados que será criado na instância RDS."
  default     = "fluxocaixa"
}

variable "db_username" {
  type        = string
  description = "Nome de usuário master do banco de dados RDS."
  default     = "postgres"
}

variable "db_password" {
  type        = string
  description = "Senha do usuário master do banco de dados RDS. IMPORTANTE: Esta senha deve ser forte e mantida em segredo."
  sensitive   = true # Marca a variável como sensível para não exibir no console ou logs
}

variable "common_tags" {
  type        = map(string)
  description = "Tags comuns a serem aplicadas a todos os recursos criados por este módulo."
  default     = {}
}

