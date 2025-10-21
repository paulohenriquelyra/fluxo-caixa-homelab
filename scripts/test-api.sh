#!/bin/bash

# ============================================
# Script de Teste da API - Fluxo de Caixa
# ============================================

set -e

# Configuração
API_URL="${API_URL:-http://localhost:8080}"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "🧪 Testes da API Fluxo de Caixa"
echo "========================================="
echo -e "API URL: ${YELLOW}${API_URL}${NC}"
echo ""

# Função para testar endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local description=$3
    local data=$4
    
    echo -e "${YELLOW}Testando: ${description}${NC}"
    echo "   ${method} ${endpoint}"
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X ${method} "${API_URL}${endpoint}")
    else
        response=$(curl -s -w "\n%{http_code}" -X ${method} \
            -H "Content-Type: application/json" \
            -d "${data}" \
            "${API_URL}${endpoint}")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "   ${GREEN}✅ Status: ${http_code}${NC}"
        echo "   Response: $(echo $body | jq -C '.' 2>/dev/null || echo $body)"
    else
        echo -e "   ${RED}❌ Status: ${http_code}${NC}"
        echo "   Response: $(echo $body | jq -C '.' 2>/dev/null || echo $body)"
    fi
    echo ""
}

# 1. Health Check
test_endpoint "GET" "/health" "Health Check"

# 2. Raiz da API
test_endpoint "GET" "/" "API Info"

# 3. Consultar Saldo
test_endpoint "GET" "/api/transacoes/consultas/saldo" "Consultar Saldo Atual"

# 4. Listar Transações
test_endpoint "GET" "/api/transacoes?limit=5" "Listar Transações (5 primeiras)"

# 5. Criar Transação
test_endpoint "POST" "/api/transacoes" "Criar Nova Transação" \
'{
  "descricao": "Teste API",
  "valor": 100.50,
  "tipo": "C",
  "categoria_id": 1,
  "usuario_id": 1,
  "tags": ["teste", "api"]
}'

# 6. Relatório Mensal
test_endpoint "GET" "/api/transacoes/consultas/relatorio-mensal" "Relatório Mensal"

# 7. Buscar por Tags
test_endpoint "GET" "/api/transacoes/consultas/tags?tags=salario,mensal" "Buscar por Tags"

# 8. Estatísticas de Período
DATA_INICIO=$(date -d "30 days ago" +%Y-%m-%d)
DATA_FIM=$(date +%Y-%m-%d)
test_endpoint "GET" "/api/transacoes/consultas/estatisticas?data_inicio=${DATA_INICIO}&data_fim=${DATA_FIM}" \
    "Estatísticas dos Últimos 30 Dias"

# 9. Inserção em Lote
test_endpoint "POST" "/api/transacoes/lote" "Inserção em Lote" \
'{
  "transacoes": [
    {
      "descricao": "Lote Teste 1",
      "valor": 50.00,
      "tipo": "C",
      "categoria_id": 1,
      "usuario_id": 1
    },
    {
      "descricao": "Lote Teste 2",
      "valor": 75.00,
      "tipo": "D",
      "categoria_id": 6,
      "usuario_id": 1
    }
  ]
}'

echo "========================================="
echo -e "${GREEN}✅ Testes concluídos!${NC}"
echo "========================================="

