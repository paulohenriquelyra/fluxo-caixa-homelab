variable "project_name" {
  description = "Nome do projeto, usado como prefixo em todos os recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente de implantação (ex: dev, stg, prod)."
  type        = string
}

variable "common_tags" {
  description = "Tags comuns para aplicar a todos os recursos."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID da VPC onde o cluster Aurora será criado."
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs das sub-redes privadas para o cluster Aurora."
  type        = list(string)
}

variable "vpc_cidr_block_for_sg" {
  description = "Bloco CIDR da VPC para ser usado nas regras de Security Group."
  type        = string
}

variable "db_port" {
  description = "Porta para o cluster Aurora PostgreSQL."
  type        = number
  default     = 5432
}

variable "db_engine_version" {
  description = "Versão do motor do Aurora PostgreSQL."
  type        = string
  default     = "15.4" # Baseado no documento de migração
}

variable "db_name" {
  description = "Nome do banco de dados inicial a ser criado no cluster Aurora."
  type        = string
  default     = "fluxocaixa" # Baseado no documento de migração
}

variable "db_username" {
  description = "Nome de usuário mestre para o cluster Aurora."
  type        = string
  default     = "postgres" # Baseado no documento de migração
}

variable "db_instance_class" {
  description = "Classe da instância para as instâncias do cluster Aurora."
  type        = string
}

variable "skip_final_snapshot" {
  description = "Se verdadeiro, um snapshot final não será criado ao excluir o cluster."
  type        = bool
}

variable "deletion_protection" {
  description = "Se verdadeiro, o cluster não pode ser excluído."
  type        = bool
}

variable "rds_monitoring_role_arn" {
  description = "ARN da IAM Role para o RDS Enhanced Monitoring."
  type        = string
}

variable "secrets_recovery_window" {
  description = "Número de dias para a janela de recuperação do segredo no Secrets Manager."
  type        = number
  default     = 0 # Para ambientes de dev, 0 dias para exclusão imediata.
}

variable "backup_retention_days" {
  description = "Número de dias para reter backups automáticos do cluster Aurora."
  type        = number
  default     = 1 # Para ambientes de dev, 1 dia para economizar custos.
}