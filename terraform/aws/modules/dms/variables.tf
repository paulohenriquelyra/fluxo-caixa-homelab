variable "project_name" {
  description = "Nome do projeto, usado para nomear recursos e tags."
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

variable "private_subnet_ids" {
  description = "Lista de IDs de sub-redes privadas para o DMS Replication Subnet Group."
  type        = list(string)
}

variable "dms_instance_class" {
  description = "Classe da instância para a instância de replicação DMS (ex: dms.t3.medium)."
  type        = string
  default     = "dms.t3.medium"
}

# ========================================
# Variáveis do Banco de Dados de Origem
# ========================================

variable "source_db_server_name" {
  description = "Endereço do servidor do banco de dados de origem (IP ou DNS)."
  type        = string
}

variable "source_db_port" {
  description = "Porta do banco de dados de origem."
  type        = number
}

variable "source_db_name" {
  description = "Nome do banco de dados de origem."
  type        = string
}

variable "source_db_username" {
  description = "Nome de usuário para o banco de dados de origem."
  type        = string
}

variable "source_db_password" {
  description = "Senha para o banco de dados de origem."
  type        = string
  sensitive   = true
}

# ========================================
# Variáveis do Banco de Dados de Destino
# ========================================

variable "target_db_server_name" {
  description = "Endereço do servidor do banco de dados de destino (endpoint do cluster Aurora)."
  type        = string
}

variable "target_db_port" {
  description = "Porta do banco de dados de destino."
  type        = number
}

variable "target_db_name" {
  description = "Nome do banco de dados de destino."
  type        = string
}

variable "target_db_username" {
  description = "Nome de usuário para o banco de dados de destino."
  type        = string
}

variable "target_db_password" {
  description = "Senha para o banco de dados de destino."
  type        = string
  sensitive   = true
}

