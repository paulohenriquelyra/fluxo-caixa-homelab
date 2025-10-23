# ==============================================================================
# ARQUIVO DE CONFIGURAÇÃO PRINCIPAL (ROOT) - AMBIENTE DE DESENVOLVIMENTO
# ==============================================================================
#
# Este arquivo é o ponto de entrada para o Terraform no ambiente de desenvolvimento.
# Sua principal responsabilidade é orquestrar a criação da infraestrutura
# através da invocação de módulos reutilizáveis.
#
# A abordagem modular traz os seguintes benefícios:
# 1.  **Reutilização**: Módulos como 'network' e 'aurora' podem ser usados em
#     diferentes ambientes (dev, stg, prod) com configurações distintas.
# 2.  **Manutenibilidade**: A lógica complexa é encapsulada. Para alterar a VPC,
#     você modifica o módulo 'network'; para alterar o Aurora, o módulo 'aurora'.
# 3.  **Legibilidade**: O arquivo root se torna uma declaração de alto nível da
#     arquitetura desejada, em vez de uma lista longa e detalhada de recursos.
#
# Orquestração:
# 1.  **Provedores (Providers)**: Configura os provedores Terraform necessários (AWS, Random).
# 2.  **Módulo de Rede (Network)**: Invoca o módulo `network` para criar a base da
#     nossa infraestrutura: VPC, Subnets (públicas e privadas), Internet Gateway,
#     NAT Gateways e Route Tables.
# 3.  **Módulo do Banco de Dados (Aurora)**: Invoca o módulo `aurora`, passando os
#     IDs da VPC e das sub-redes privadas que foram criadas pelo módulo `network`.
#     Isso demonstra a passagem de dados (outputs de um módulo como inputs de outro).

# ==============================================================================
# BLOCO DE CONFIGURAÇÃO DO TERRAFORM
# ==============================================================================
# Define a versão do Terraform e os provedores necessários.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ==============================================================================
# CONFIGURAÇÃO DO PROVEDOR AWS
# ==============================================================================
# Define a região e as tags padrão que serão aplicadas a todos os recursos.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Aurora-Migration-Learning"
      Owner       = "Paulo Henrique Lyra"
      CostCenter  = "Learning"
      AutoDestroy = "true"
    }
  }
}

# ==============================================================================
# MÓDULO: REDE (VPC, Subnets, Gateways, etc.)
# ==============================================================================
#
# Invoca o módulo de rede para provisionar a infraestrutura de rede base.
# Este módulo é responsável por criar uma VPC com sub-redes públicas e privadas
# em múltiplas Zonas de Disponibilidade para garantir alta disponibilidade.

module "network" {
  # O 'source' aponta para o diretório local do módulo de rede.
  source = "../../modules/network"

  # Passa as variáveis necessárias para o módulo de rede.
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  common_tags  = var.common_tags
}

# ==============================================================================
# MÓDULO: BANCO DE DADOS (Aurora PostgreSQL)
# ==============================================================================
#
# Invoca o módulo Aurora que criamos. Note como os 'outputs' do módulo 'network'
# são usados como 'inputs' para este módulo. Isso cria uma dependência explícita
# e garante que o Terraform crie a rede ANTES de tentar criar o banco de dados.

module "aurora" {
  source = "../../modules/aurora"

  # Parâmetros de identificação e tagueamento.
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags

  # Conectando o módulo Aurora à rede criada pelo módulo 'network'.
  # `module.network.vpc_id` refere-se ao output 'vpc_id' do módulo 'network'.
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # Parâmetros específicos do banco de dados para este ambiente (dev).
  db_instance_class   = var.db_instance_class
  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection
}



# ==============================================================================
# MÓDULO: AWS DATABASE MIGRATION SERVICE (DMS)
# ==============================================================================
#
# Invoca o módulo DMS para provisionar os recursos necessários para a migração.
# Este módulo depende da rede e do cluster Aurora, então ele usa os outputs
# dos módulos `network` e `aurora` como seus inputs.

module "dms" {
  source = "../../modules/dms"

  # Parâmetros de identificação e tagueamento.
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags

  # Conecta o DMS à nossa rede.
  private_subnet_ids = module.network.private_subnet_ids

  # Configurações da instância de replicação.
  dms_instance_class = var.dms_instance_class

  # Configurações do Endpoint de Origem (Homelab PostgreSQL).
  # ATENÇÃO: `var.source_db_server_name` deve ser o IP público do seu Homelab.
  source_db_server_name = var.source_db_server_name
  source_db_port        = var.source_db_port
  source_db_name        = var.source_db_name
  source_db_username    = var.source_db_username
  source_db_password    = var.source_db_password

  # Configurações do Endpoint de Destino (AWS Aurora).
  # Note como usamos os outputs do módulo `aurora` aqui.
  target_db_server_name = module.aurora.cluster_endpoint
  target_db_port        = module.aurora.cluster_port
  target_db_name        = var.target_db_name # O nome do banco de dados é o mesmo.
  target_db_username    = var.target_db_username
  # A senha do Aurora é obtida do Secrets Manager, mas para o DMS, precisamos passá-la diretamente.
  # Em um cenário de produção, você poderia usar uma data source para ler o segredo.
  target_db_password    = var.target_db_password
}

