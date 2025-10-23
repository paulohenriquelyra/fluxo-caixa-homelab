# ============================================
# Configuração do Provedor AWS
# ============================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a versão mais recente compatível
    }
  }
}

provider "aws" {
  region = var.aws_region
}