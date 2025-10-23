#!/bin/bash
# ==============================================================================
# SCRIPT: destroy.sh
# ==============================================================================
# Propósito: Destruir toda a infraestrutura AWS criada pelo Terraform.
#
# Uso: ./destroy.sh
#
# ATENÇÃO: Este script remove TODOS os recursos criados, incluindo o cluster Aurora
#          e todos os dados nele contidos. Use com cuidado!

set -e

# Cores para output legível
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório do ambiente de desenvolvimento
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/dev" && pwd)"

echo -e "${RED}========================================${NC}"
echo -e "${RED}  DESTRUIÇÃO DA INFRAESTRUTURA AWS${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}ATENÇÃO: Este script irá DESTRUIR todos os recursos criados pelo Terraform.${NC}"
echo -e "${YELLOW}Isso inclui:${NC}"
echo -e "  - Cluster Aurora PostgreSQL (e todos os dados)"
echo -e "  - Instância de Replicação DMS"
echo -e "  - VPC, Subnets, Gateways"
echo -e "  - Security Groups"
echo -e "  - Secrets Manager (senha do Aurora)"
echo ""
read -p "Tem certeza que deseja continuar? Digite 'sim' para confirmar: " -r
echo
if [[ ! $REPLY == "sim" ]]; then
    echo -e "${GREEN}Operação cancelada.${NC}"
    exit 0
fi

# Navega para o diretório do ambiente
cd "$ENV_DIR"

# Executa o terraform destroy
echo -e "${RED}Destruindo recursos...${NC}"
terraform destroy

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DESTRUIÇÃO CONCLUÍDA${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Todos os recursos foram removidos."
echo -e "Você pode verificar no console da AWS para confirmar."
echo ""

