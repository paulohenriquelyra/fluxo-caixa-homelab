#!/bin/bash
# ==============================================================================
# SCRIPT: test-cdc.sh
# ==============================================================================
# Propósito: Testar o CDC (Change Data Capture) fazendo alterações no RDS
#            fonte e verificando se elas são replicadas para o Aurora.
#
# Uso: ./test-cdc.sh
#
# Este script insere, atualiza e deleta registros no RDS fonte e verifica
# se as mudanças aparecem automaticamente no Aurora via DMS.

set -e

# Cores para output legível
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório do ambiente de desenvolvimento
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/dev" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TESTE DE CDC (CHANGE DATA CAPTURE)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Navega para o diretório do ambiente
cd "$ENV_DIR"

# Verifica se o psql está instalado
if ! command -v psql &> /dev/null; then
    echo -e "${RED}ERRO: psql (cliente PostgreSQL) não está instalado.${NC}"
    exit 1
fi

# Obtém endpoints
echo -e "${GREEN}Obtendo informações dos bancos de dados...${NC}"
RDS_ENDPOINT=$(terraform output -raw rds_source_instance_address 2>/dev/null)
RDS_PORT=$(terraform output -raw rds_source_instance_port 2>/dev/null)
AURORA_ENDPOINT=$(terraform output -raw aurora_cluster_endpoint 2>/dev/null)
AURORA_PORT=$(terraform output -raw aurora_cluster_port 2>/dev/null)

if [ -z "$RDS_ENDPOINT" ] || [ -z "$AURORA_ENDPOINT" ]; then
    echo -e "${RED}ERRO: Não foi possível obter os endpoints.${NC}"
    exit 1
fi

echo -e "${GREEN}RDS Fonte: ${NC}$RDS_ENDPOINT:$RDS_PORT"
echo -e "${GREEN}Aurora Destino: ${NC}$AURORA_ENDPOINT:$AURORA_PORT"
echo ""

# Solicita credenciais
read -p "Usuário do RDS fonte (padrão: postgres): " RDS_USER
RDS_USER=${RDS_USER:-postgres}
read -sp "Senha do RDS fonte: " RDS_PASSWORD
echo ""

read -p "Usuário do Aurora (padrão: masteruser): " AURORA_USER
AURORA_USER=${AURORA_USER:-masteruser}
read -sp "Senha do Aurora: " AURORA_PASSWORD
echo ""
echo ""

# Função para executar query no RDS
rds_query() {
    PGPASSWORD="$RDS_PASSWORD" psql -h "$RDS_ENDPOINT" -p "$RDS_PORT" -U "$RDS_USER" -d fluxocaixa -t -c "$1"
}

# Função para executar query no Aurora
aurora_query() {
    PGPASSWORD="$AURORA_PASSWORD" psql -h "$AURORA_ENDPOINT" -p "$AURORA_PORT" -U "$AURORA_USER" -d fluxocaixa -t -c "$1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TESTE 1: INSERT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Inserir registro no RDS
echo -e "${YELLOW}Inserindo registro no RDS fonte...${NC}"
rds_query "INSERT INTO transacoes (descricao, valor, data, tipo, conta_id, categoria_id) VALUES ('Teste CDC - INSERT', 123.45, NOW(), 'RECEITA', 1, 1) RETURNING id;"

# Aguardar replicação
echo -e "${YELLOW}Aguardando 5 segundos para replicação...${NC}"
sleep 5

# Verificar no Aurora
echo -e "${YELLOW}Verificando no Aurora...${NC}"
AURORA_COUNT=$(aurora_query "SELECT COUNT(*) FROM transacoes WHERE descricao = 'Teste CDC - INSERT';")

if [ "$AURORA_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ INSERT replicado com sucesso!${NC}"
else
    echo -e "${RED}❌ INSERT não foi replicado.${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TESTE 2: UPDATE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Atualizar registro no RDS
echo -e "${YELLOW}Atualizando registro no RDS fonte...${NC}"
rds_query "UPDATE transacoes SET valor = 999.99 WHERE descricao = 'Teste CDC - INSERT';"

# Aguardar replicação
echo -e "${YELLOW}Aguardando 5 segundos para replicação...${NC}"
sleep 5

# Verificar no Aurora
echo -e "${YELLOW}Verificando no Aurora...${NC}"
AURORA_VALUE=$(aurora_query "SELECT valor FROM transacoes WHERE descricao = 'Teste CDC - INSERT';")

if [[ "$AURORA_VALUE" == *"999.99"* ]]; then
    echo -e "${GREEN}✅ UPDATE replicado com sucesso!${NC}"
else
    echo -e "${RED}❌ UPDATE não foi replicado.${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TESTE 3: DELETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Deletar registro no RDS
echo -e "${YELLOW}Deletando registro no RDS fonte...${NC}"
rds_query "DELETE FROM transacoes WHERE descricao = 'Teste CDC - INSERT';"

# Aguardar replicação
echo -e "${YELLOW}Aguardando 5 segundos para replicação...${NC}"
sleep 5

# Verificar no Aurora
echo -e "${YELLOW}Verificando no Aurora...${NC}"
AURORA_COUNT=$(aurora_query "SELECT COUNT(*) FROM transacoes WHERE descricao = 'Teste CDC - INSERT';")

if [ "$AURORA_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ DELETE replicado com sucesso!${NC}"
else
    echo -e "${RED}❌ DELETE não foi replicado.${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TESTE DE CDC CONCLUÍDO${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "O CDC está funcionando se todos os testes passaram (✅)."
echo -e "Se algum teste falhou (❌), verifique:"
echo -e "  1. A tarefa DMS está rodando?"
echo -e "  2. O status da tarefa está 'running'?"
echo -e "  3. Há erros nos logs do DMS?"
echo ""

