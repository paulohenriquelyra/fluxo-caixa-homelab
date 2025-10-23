# ============================================
# Variáveis do Projeto
# ============================================

variable "aws_region" {
  description = "Região da AWS onde os recursos serão provisionados."
  type        = string
  default     = "us-east-1" # Exemplo: Virginia
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo para recursos."
  type        = string
  default     = "fluxo-caixa"
}

# ============================================
# Variáveis da VPC
# ============================================

variable "vpc_cidr_block" {
  description = "Bloco CIDR para a VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_a_cidr_block" {
  description = "Bloco CIDR para a primeira subnet privada."
  type        = string
  default     = "10.10.1.0/24"
}

variable "subnet_b_cidr_block" {
  description = "Bloco CIDR para a segunda subnet privada."
  type        = string
  default     = "10.10.2.0/24"
}

# ============================================
# Variáveis do Aurora
# ============================================

variable "aurora_engine_version" {
  description = "Versão do motor PostgreSQL para o Aurora."
  type        = string
  default     = "15.3" # Verifique a versão mais recente compatível
}

variable "aurora_database_name" {
  description = "Nome do banco de dados a ser criado no Aurora."
  type        = string
  default     = "fluxocaixa"
}

variable "aurora_master_username" {
  description = "Nome de usuário mestre para o Aurora PostgreSQL."
  type        = string
  default     = "postgres"
}

variable "aurora_instance_class" {
  description = "Classe da instância para o Aurora Provisionado (ex: db.t4g.micro, db.t3.medium)."
  type        = string
  default     = "db.t4g.micro" # Instância Graviton, geralmente elegível para o Free Tier.
}