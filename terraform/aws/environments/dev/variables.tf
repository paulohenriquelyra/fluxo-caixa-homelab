variable "project_name" {
  description = "Nome do projeto, usado como prefixo em todos os recursos e tags."
  type        = string
  default     = "fluxo-caixa"
}

variable "environment" {
  description = "Ambiente de implantação (ex: dev, stg, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Bloco CIDR para a VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "Classe da instância para as instâncias do cluster Aurora."
  type        = string
  default     = "db.t4g.small"
}

variable "skip_final_snapshot" {
  description = "Se verdadeiro, um snapshot final não será criado ao excluir o cluster."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Se verdadeiro, o cluster não pode ser excluído."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags comuns para aplicar a todos os recursos."
  type        = map(string)
  default     = {}
}


# ========================================
# Variáveis do Módulo DMS
# ========================================

variable "dms_instance_class" {
  description = "Classe da instância para a instância de replicação DMS."
  type        = string
  default     = "dms.t3.medium"
}

variable "source_db_server_name" {
  description = "Endereço do servidor do banco de dados de origem (IP público do Homelab)."
  type        = string
}

variable "source_db_port" {
  description = "Porta do banco de dados de origem."
  type        = number
  default     = 5432
}

variable "source_db_name" {
  description = "Nome do banco de dados de origem."
  type        = string
  default     = "fluxocaixa"
}

variable "source_db_username" {
  description = "Nome de usuário para o banco de dados de origem."
  type        = string
  default     = "postgres"
}

variable "source_db_password" {
  description = "Senha para o banco de dados de origem."
  type        = string
  sensitive   = true
}

variable "target_db_name" {
  description = "Nome do banco de dados de destino."
  type        = string
  default     = "fluxocaixa"
}

variable "target_db_username" {
  description = "Nome de usuário para o banco de dados de destino."
  type        = string
  default     = "masteruser"
}

variable "target_db_password" {
  description = "Senha para o banco de dados de destino. Deve ser a mesma gerada para o Aurora."
  type        = string
  sensitive   = true
}

