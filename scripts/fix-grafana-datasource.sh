#!/bin/bash

GRAFANA_URL="http://grafana.local"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"

echo "Verificando datasource Prometheus..."

# Ver datasources existentes
DATASOURCES=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" )

if echo "$DATASOURCES" | jq -e '.[] | select(.type=="prometheus")' > /dev/null 2>&1; then
    echo "✅ Datasource Prometheus já existe"
    
    # Testar datasource
    DS_ID=$(echo "$DATASOURCES" | jq -r '.[] | select(.type=="prometheus") | .id')
    echo "Testando datasource (ID: $DS_ID)..."
    
    HEALTH=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/$DS_ID/health")
    
    if echo "$HEALTH" | jq -e '.status == "OK"' > /dev/null 2>&1; then
        echo "✅ Datasource funcionando!"
    else
        echo "❌ Datasource com problemas:"
        echo "$HEALTH" | jq
    fi
else
    echo "❌ Datasource Prometheus não encontrado. Criando..."
    
    RESULT=$(curl -s -X POST -H "Content-Type: application/json" \
      -u "$GRAFANA_USER:$GRAFANA_PASS" \
      -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://prometheus:9090",
        "access": "proxy",
        "isDefault": true,
        "jsonData": {
          "httpMethod": "POST",
          "timeInterval": "15s"
        }
      }' \
      "$GRAFANA_URL/api/datasources" )
    
    if echo "$RESULT" | jq -e '.id' > /dev/null 2>&1; then
        echo "✅ Datasource criado com sucesso!"
        DS_ID=$(echo "$RESULT" | jq -r '.id')
        echo "ID: $DS_ID"
        
        # Testar
        sleep 2
        curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/$DS_ID/health" | jq
    else
        echo "❌ Falha ao criar datasource:"
        echo "$RESULT" | jq
    fi
fi
