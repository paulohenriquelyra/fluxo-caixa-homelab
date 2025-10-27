#!/bin/bash
# ==============================================================================
# SCRIPT: restore-to-rds.sh
# ==============================================================================
# Propósito: Restaurar o dump do banco de dados do Homelab no RDS PostgreSQL
#            (fonte) para simular a migração com DMS.
#
# Uso: ./restore-to-rds.sh /caminho/para/dump.sql
#
# Este script automatiza o processo de restauração do dump no RDS fonte.

set -e # Interrompe o script se qualquer comando falhar

# Cores para output legível
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório do ambiente de desenvolvimento
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/dev" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RESTAURAR DUMP NO RDS FONTE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verifica se o arquivo de dump foi fornecido
if [ -z "$1" ]; then
    echo -e "${RED}ERRO: Arquivo de dump não fornecido.${NC}"
    echo "Uso: $0 /caminho/para/dump.sql"
    echo ""
    echo "Exemplo:"
    echo "  $0 ~/fluxocaixa_backup.sql"
    exit 1
fi

DUMP_FILE="$1"

# Verifica se o arquivo existe
if [ ! -f "$DUMP_FILE" ]; then
    echo -e "${RED}ERRO: Arquivo não encontrado: $DUMP_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}Arquivo de dump: ${NC}$DUMP_FILE"
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

# Obtém o endpoint do RDS fonte a partir dos outputs do Terraform
echo -e "${GREEN}Obtendo informações do RDS fonte...${NC}"
RDS_ENDPOINT=$(terraform output -raw rds_source_instance_address 2>/dev/null)
RDS_PORT=$(terraform output -raw rds_source_instance_port 2>/dev/null)
RDS_DB_NAME=$(terraform output -raw rds_source_db_name 2>/dev/null)
RDS_USERNAME=$(terraform output -raw rds_source_db_username 2>/dev/null)

if [ -z "$RDS_ENDPOINT" ] || [ -z "$RDS_PORT" ]; then
    echo -e "${RED}ERRO: Não foi possível obter o endpoint do RDS fonte.${NC}"
    echo "Certifique-se de que o RDS foi criado com 'terraform apply'."
    exit 1
fi

echo -e "${GREEN}Endpoint: ${NC}$RDS_ENDPOINT"
echo -e "${GREEN}Porta: ${NC}$RDS_PORT"
echo -e "${GREEN}Banco: ${NC}$RDS_DB_NAME"
echo -e "${GREEN}Usuário: ${NC}$RDS_USERNAME"
echo ""

# Solicita a senha
read -sp "Senha do RDS: " RDS_PASSWORD
echo ""
echo ""

# Detecta o tipo de dump (SQL ou custom format)
DUMP_EXT="${DUMP_FILE##*.}"

echo -e "${GREEN}Restaurando dump no RDS fonte...${NC}"
echo -e "${YELLOW}Isso pode levar alguns minutos dependendo do tamanho do banco.${NC}"
echo ""

if [ "$DUMP_EXT" == "sql" ]; then
    # Dump em formato SQL (texto)
    PGPASSWORD="$RDS_PASSWORD" psql \
        -h "$RDS_ENDPOINT" \
        -p "$RDS_PORT" \
        -U "$RDS_USERNAME" \
        -d "$RDS_DB_NAME" \
        -f "$DUMP_FILE"
else
    # Dump em formato custom (binário)
    PGPASSWORD="$RDS_PASSWORD" pg_restore \
        -h "$RDS_ENDPOINT" \
        -p "$RDS_PORT" \
        -U "$RDS_USERNAME" \
        -d "$RDS_DB_NAME" \
        -v \
        "$DUMP_FILE"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RESTAURAÇÃO CONCLUÍDA${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "O dump foi restaurado no RDS fonte."
echo -e "Agora você pode iniciar a migração DMS com:"
echo -e "  ${GREEN}./migrate.sh${NC}"
echo ""

