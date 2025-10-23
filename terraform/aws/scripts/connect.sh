#!/bin/bash
# ==============================================================================
# SCRIPT: connect.sh
# ==============================================================================
# Propósito: Conectar ao cluster Aurora PostgreSQL usando psql.
#
# Uso: ./connect.sh
#
# Este script obtém o endpoint e a porta do cluster Aurora a partir dos outputs
# do Terraform e se conecta usando o cliente psql.

set -e

# Cores para output legível
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório do ambiente de desenvolvimento
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/dev" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  CONECTAR AO AURORA POSTGRESQL${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Navega para o diretório do ambiente
cd "$ENV_DIR"

# Verifica se o psql está instalado
if ! command -v psql &> /dev/null; then
    echo -e "${RED}ERRO: psql (cliente PostgreSQL) não está instalado.${NC}"
    echo "Por favor, instale o PostgreSQL client:"
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  macOS: brew install postgresql"
    exit 1
fi

# Obtém o endpoint do cluster Aurora a partir dos outputs do Terraform
echo -e "${GREEN}Obtendo informações do cluster Aurora...${NC}"
AURORA_ENDPOINT=$(terraform output -raw aurora_cluster_endpoint 2>/dev/null)
AURORA_PORT=$(terraform output -raw aurora_cluster_port 2>/dev/null)

if [ -z "$AURORA_ENDPOINT" ] || [ -z "$AURORA_PORT" ]; then
    echo -e "${RED}ERRO: Não foi possível obter o endpoint do Aurora.${NC}"
    echo "Certifique-se de que a infraestrutura foi criada com 'terraform apply'."
    exit 1
fi

echo -e "${GREEN}Endpoint: ${NC}$AURORA_ENDPOINT"
echo -e "${GREEN}Porta: ${NC}$AURORA_PORT"
echo ""

# Solicita o nome de usuário e a senha
read -p "Nome de usuário (padrão: masteruser): " DB_USER
DB_USER=${DB_USER:-masteruser}

echo -e "${YELLOW}Para obter a senha, acesse o AWS Secrets Manager ou use:${NC}"
echo -e "  aws secretsmanager get-secret-value --secret-id <ARN_DO_SEGREDO> --query SecretString --output text"
echo ""
read -sp "Senha: " DB_PASSWORD
echo ""

# Conecta ao Aurora
echo -e "${GREEN}Conectando ao Aurora...${NC}"
PGPASSWORD="$DB_PASSWORD" psql -h "$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$DB_USER" -d fluxocaixa

echo ""
echo -e "${GREEN}Conexão encerrada.${NC}"

