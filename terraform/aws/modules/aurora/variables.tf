variable "project_name" {
  description = "Nome do projeto, usado para nomear recursos e tags."
  type        = string
  default     = "fluxo-caixa"
}

variable "environment" {
  description = "Ambiente de implantação (ex: dev, stg, prod)."
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Tags comuns para aplicar a todos os recursos."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID da VPC onde o cluster Aurora será implantado."
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs de sub-redes privadas para o DB Subnet Group."
  type        = list(string)
}

variable "db_name" {
  description = "Nome do banco de dados inicial a ser criado no cluster."
  type        = string
  default     = "fluxocaixa"
}

variable "db_port" {
  description = "Porta na qual o banco de dados aceitará conexões."
  type        = number
  default     = 5432
}

variable "db_username" {
  description = "Nome de usuário para o usuário mestre do banco de dados."
  type        = string
  default     = "masteruser"
}

variable "db_engine_version" {
  description = "Versão do motor PostgreSQL do Aurora."
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "Classe da instância para as instâncias do cluster Aurora (ex: db.t4g.small, db.r6g.large)."
  type        = string
  default     = "db.t4g.small"
}

variable "backup_retention_days" {
  description = "Número de dias para reter backups automáticos."
  type        = number
  default     = 3
}

variable "skip_final_snapshot" {
  description = "Se verdadeiro, um snapshot final não será criado ao excluir o cluster. Ideal para ambientes de não produção."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Se verdadeiro, o cluster não pode ser excluído. Defina como 'false' para ambientes de não produção."
  type        = bool
  default     = false
}

variable "secrets_recovery_window" {
  description = "Janela de recuperação em dias para o segredo no Secrets Manager. Use 0 para exclusão imediata em dev/test."
  type        = number
  default     = 0
}

variable "kms_key_id_for_secrets" {
  description = "O ID da chave KMS para criptografar o segredo da senha mestre. Se nulo, usa a chave padrão da AWS."
  type        = string
  default     = null
}

variable "rds_monitoring_role_arn" {
  description = "ARN da IAM Role para o Enhanced Monitoring do RDS. Se nulo, o monitoramento avançado é desativado."
  type        = string
  default     = null
}

