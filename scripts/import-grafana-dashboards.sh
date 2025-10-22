#!/bin/bash

# ============================================
# Script de Importação de Dashboards Grafana
# ============================================
# Importa automaticamente dashboards do Grafana.com

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configurações
GRAFANA_URL="${GRAFANA_URL:-http://grafana.local}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin123}"

echo "========================================="
echo "📊 Importação de Dashboards Grafana"
echo "========================================="
echo ""

# Verificar se Grafana está acessível
echo -n "Verificando Grafana ($GRAFANA_URL)... "
if curl -s -f "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FALHOU${NC}"
    echo ""
    echo "Grafana não está acessível em: $GRAFANA_URL"
    echo ""
    echo "Verifique:"
    echo "  1. Grafana está rodando: kubectl get pods -n monitoring"
    echo "  2. Service tem IP: kubectl get service grafana -n monitoring"
    echo "  3. /etc/hosts configurado: cat /etc/hosts | grep grafana"
    echo ""
    exit 1
fi
echo ""

# Verificar credenciais
echo -n "Verificando credenciais... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/org")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FALHOU (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo "Credenciais inválidas!"
    echo "Usuário: $GRAFANA_USER"
    echo "Senha: $GRAFANA_PASS"
    echo ""
    echo "Para usar credenciais diferentes:"
    echo "  export GRAFANA_USER=seu_usuario"
    echo "  export GRAFANA_PASS=sua_senha"
    echo "  ./scripts/import-grafana-dashboards.sh"
    echo ""
    exit 1
fi
echo ""

# Obter UID do datasource Prometheus
echo -n "Obtendo datasource Prometheus... "
PROMETHEUS_UID=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
  "$GRAFANA_URL/api/datasources" | \
  jq -r '.[] | select(.type=="prometheus") | .uid' | head -1)

if [ -z "$PROMETHEUS_UID" ] || [ "$PROMETHEUS_UID" = "null" ]; then
    echo -e "${RED}❌ NÃO ENCONTRADO${NC}"
    echo ""
    echo "Datasource Prometheus não configurado!"
    echo "Configure manualmente:"
    echo "  1. Acessar: $GRAFANA_URL"
    echo "  2. Connections → Data Sources → Add data source"
    echo "  3. Selecionar Prometheus"
    echo "  4. URL: http://prometheus:9090"
    echo "  5. Save & Test"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ OK (UID: $PROMETHEUS_UID)${NC}"
fi
echo ""

# Lista de dashboards para importar
declare -A DASHBOARDS
DASHBOARDS=(
  ["7249"]="Kubernetes Cluster Monitoring"
  ["1860"]="Node Exporter Full"
  ["6417"]="Kubernetes Pods"
  ["9628"]="PostgreSQL Database"
  ["14127"]="MetalLB"
)

echo "========================================="
echo "📥 Importando Dashboards"
echo "========================================="
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for DASHBOARD_ID in "${!DASHBOARDS[@]}"; do
    DASHBOARD_NAME="${DASHBOARDS[$DASHBOARD_ID]}"
    
    echo "----------------------------------------"
    echo -e "${BLUE}Dashboard: $DASHBOARD_NAME (ID: $DASHBOARD_ID)${NC}"
    echo "----------------------------------------"
    
    # Baixar JSON do dashboard
    echo -n "1/3 Baixando JSON... "
    DASHBOARD_JSON=$(curl -s "https://grafana.com/api/dashboards/$DASHBOARD_ID/revisions/latest/download")
    
    if [ -z "$DASHBOARD_JSON" ] || [ "$DASHBOARD_JSON" = "null" ]; then
        echo -e "${RED}❌ FALHOU${NC}"
        echo "  Não foi possível baixar dashboard"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    echo -e "${GREEN}✅ OK${NC}"
    
    # Preparar payload
    echo -n "2/3 Preparando payload... "
    
    # Salvar JSON em arquivo temporário para evitar "Argument list too long"
    TMP_FILE="/tmp/dashboard_${DASHBOARD_ID}.json"
    echo "$DASHBOARD_JSON" > "$TMP_FILE"
    
    # Substituir datasource UID usando arquivo
    jq --arg uid "$PROMETHEUS_UID" '
      walk(
        if type == "object" and has("datasource") then
          if .datasource | type == "string" then
            .datasource = $uid
          elif .datasource | type == "object" then
            .datasource.uid = $uid
          else
            .
          end
        else
          .
        end
      )
    ' "$TMP_FILE" > "${TMP_FILE}.processed"
    
    # Criar payload de importação
    PAYLOAD=$(jq -n \
      --slurpfile dashboard "${TMP_FILE}.processed" \
      --arg uid "$PROMETHEUS_UID" \
      '{
        dashboard: $dashboard[0],
        overwrite: true,
        inputs: []
      }')
    
    # Limpar arquivos temporários
    rm -f "$TMP_FILE" "${TMP_FILE}.processed"
    
    echo -e "${GREEN}✅ OK${NC}"
    
    # Importar via API
    echo -n "3/3 Importando... "
    IMPORT_RESPONSE=$(curl -s --max-time 60 -X POST \
      -H "Content-Type: application/json" \
      -u "$GRAFANA_USER:$GRAFANA_PASS" \
      -d "$PAYLOAD" \
      "$GRAFANA_URL/api/dashboards/import" 2>&1)
    
    CURL_EXIT_CODE=$?
    
    # Verificar se curl teve timeout ou erro
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        echo -e "${RED}❌ FALHOU${NC}"
        echo "  Erro: Timeout ou falha na conexão (exit code: $CURL_EXIT_CODE)"
        echo "  Tente importar manualmente: ID $DASHBOARD_ID"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    
    # Verificar se importou com sucesso
    if echo "$IMPORT_RESPONSE" | jq -e '.uid' > /dev/null 2>&1; then
        IMPORTED_UID=$(echo "$IMPORT_RESPONSE" | jq -r '.uid')
        IMPORTED_URL=$(echo "$IMPORT_RESPONSE" | jq -r '.url')
        echo -e "${GREEN}✅ OK${NC}"
        echo "  UID: $IMPORTED_UID"
        echo "  URL: $GRAFANA_URL$IMPORTED_URL"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}❌ FALHOU${NC}"
        ERROR_MSG=$(echo "$IMPORT_RESPONSE" | jq -r '.message // .error // "Erro desconhecido"' 2>/dev/null || echo "Erro desconhecido")
        echo "  Erro: $ERROR_MSG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    echo ""
done

echo "========================================="
echo "📊 Resumo"
echo "========================================="
echo ""
echo -e "${GREEN}✅ Sucesso: $SUCCESS_COUNT dashboards${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}❌ Falhas: $FAIL_COUNT dashboards${NC}"
fi
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "========================================="
    echo -e "${GREEN}🎉 Dashboards Importados!${NC}"
    echo "========================================="
    echo ""
    echo "Acesse o Grafana:"
    echo "  URL: $GRAFANA_URL"
    echo "  Usuário: $GRAFANA_USER"
    echo "  Senha: $GRAFANA_PASS"
    echo ""
    echo "Dashboards importados:"
    for DASHBOARD_ID in "${!DASHBOARDS[@]}"; do
        echo "  - ${DASHBOARDS[$DASHBOARD_ID]}"
    done
    echo ""
    echo "📚 Próximos Passos:"
    echo "  1. Explorar dashboards"
    echo "  2. Personalizar conforme necessidade"
    echo "  3. Criar pastas para organizar"
    echo "  4. Configurar alertas"
    echo ""
fi

if [ $FAIL_COUNT -gt 0 ]; then
    echo "========================================="
    echo -e "${YELLOW}⚠️  Algumas Importações Falharam${NC}"
    echo "========================================="
    echo ""
    echo "Você pode importar manualmente:"
    echo "  1. Acessar: $GRAFANA_URL"
    echo "  2. Menu → Dashboards → Import"
    echo "  3. Digite o ID do dashboard"
    echo "  4. Load → Import"
    echo ""
    echo "IDs para importar manualmente:"
    for DASHBOARD_ID in "${!DASHBOARDS[@]}"; do
        echo "  - $DASHBOARD_ID (${DASHBOARDS[$DASHBOARD_ID]})"
    done
    echo ""
fi

exit $FAIL_COUNT

