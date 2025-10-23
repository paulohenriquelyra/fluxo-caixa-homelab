#!/bin/bash
# ==============================================================================
# SCRIPT: deploy.sh
# ==============================================================================
# Propósito: Inicializar e aplicar a configuração do Terraform para criar a
#            infraestrutura AWS (VPC, Aurora, DMS).
#
# Uso: ./deploy.sh
#
# Este script automatiza os passos necessários para provisionar a infraestrutura.
# Ele executa `terraform init` (se necessário) e `terraform apply`.

set -e # Interrompe o script se qualquer comando falhar.

# Cores para output legível
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório do ambiente de desenvolvimento
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/dev" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOY DA INFRAESTRUTURA AWS${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Navega para o diretório do ambiente
cd "$ENV_DIR"

# Verifica se o Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERRO: Terraform não está instalado.${NC}"
    echo "Por favor, instale o Terraform: https://www.terraform.io/downloads"
    exit 1
fi

# Verifica se o arquivo terraform.tfvars foi configurado
if grep -q "SEU_IP_PUBLICO_AQUI" terraform.tfvars || grep -q "SENHA_DO_SEU_HOMELAB_DB_AQUI" terraform.tfvars || grep -q "SENHA_GERADA_PELO_AURORA_AQUI" terraform.tfvars; then
    echo -e "${YELLOW}ATENÇÃO: Detectamos placeholders no arquivo terraform.tfvars.${NC}"
    echo -e "${YELLOW}Por favor, edite o arquivo e preencha as informações necessárias:${NC}"
    echo -e "  - ${YELLOW}source_db_server_name${NC}: IP público do seu homelab"
    echo -e "  - ${YELLOW}source_db_password${NC}: Senha do PostgreSQL do homelab"
    echo -e "  - ${YELLOW}target_db_password${NC}: Senha gerada pelo Aurora (após o primeiro apply)"
    echo ""
    echo -e "${YELLOW}Se esta é a primeira execução, você pode comentar o módulo 'dms' no main.tf.${NC}"
    read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${RED}Deploy cancelado.${NC}"
        exit 1
    fi
fi

# Inicializa o Terraform (baixa providers, configura backend)
echo -e "${GREEN}[1/3] Inicializando o Terraform...${NC}"
terraform init

# Valida a configuração
echo -e "${GREEN}[2/3] Validando a configuração...${NC}"
terraform validate

# Aplica a configuração
echo -e "${GREEN}[3/3] Aplicando a configuração (criando recursos)...${NC}"
echo -e "${YELLOW}Revise o plano de execução e confirme quando solicitado.${NC}"
terraform apply

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOY CONCLUÍDO COM SUCESSO!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Para visualizar os outputs (endpoints, ARNs, etc.):"
echo -e "  ${GREEN}terraform output${NC}"
echo ""
echo -e "Para conectar ao Aurora:"
echo -e "  ${GREEN}./scripts/connect.sh${NC}"
echo ""

