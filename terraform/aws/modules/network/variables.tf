variable "project_name" {
  description = "Nome do projeto, usado para nomear recursos e tags."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR para a VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "common_tags" {
  description = "Tags comuns para aplicar a todos os recursos."
  type        = map(string)
  default     = {}
}

