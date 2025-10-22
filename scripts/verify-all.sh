#!/bin/bash

# ============================================
# Script de Verificação Completa do Ambiente
# ============================================
# Testa aplicação, monitoramento, storage e rede

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "========================================="
echo "🔍 Verificação Completa do Ambiente"
echo "========================================="
echo ""
echo "Data: $(date)"
echo ""

# ============================================
# 1. KUBERNETES CLUSTER
# ============================================
echo "========================================="
echo "☸️  1. KUBERNETES CLUSTER"
echo "========================================="
echo ""

echo -n "1.1 Cluster acessível: "
if kubectl cluster-info &>/dev/null; then
    check_pass
else
    check_fail
    echo "  Erro: Não foi possível acessar o cluster"
fi

echo -n "1.2 Nodes prontos: "
NODES_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
NODES_TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$NODES_READY" -eq "$NODES_TOTAL" ] && [ "$NODES_TOTAL" -gt 0 ]; then
    check_pass
    echo "  $NODES_READY/$NODES_TOTAL nodes prontos"
else
    check_fail
    echo "  $NODES_READY/$NODES_TOTAL nodes prontos"
fi

echo ""

# ============================================
# 2. STORAGE NFS
# ============================================
echo "========================================="
echo "🗄️  2. STORAGE NFS"
echo "========================================="
echo ""

echo -n "2.1 NFS Server acessível (10.0.2.17): "
if ping -c 1 -W 2 10.0.2.17 &>/dev/null; then
    check_pass
else
    check_fail
fi

echo -n "2.2 NFS Provisioner rodando: "
NFS_PROV_READY=$(kubectl get pods -n kube-system -l app=nfs-client-provisioner --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$NFS_PROV_READY" -gt 0 ]; then
    check_pass
else
    check_fail
fi

echo -n "2.3 StorageClass 'nfs-client' existe: "
if kubectl get storageclass nfs-client &>/dev/null; then
    check_pass
else
    check_fail
fi

echo ""

# ============================================
# 3. APLICAÇÃO FLUXO DE CAIXA
# ============================================
echo "========================================="
echo "💰 3. APLICAÇÃO FLUXO DE CAIXA"
echo "========================================="
echo ""

echo -n "3.1 Namespace 'fluxo-caixa' existe: "
if kubectl get namespace fluxo-caixa &>/dev/null; then
    check_pass
else
    check_fail
fi

echo -n "3.2 PostgreSQL rodando: "
PG_READY=$(kubectl get pods -n fluxo-caixa -l app=postgres --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
if [ "$PG_READY" -gt 0 ]; then
    check_pass
else
    check_fail
fi

echo -n "3.3 Aplicação rodando: "
APP_READY=$(kubectl get pods -n fluxo-caixa -l app=fluxo-caixa-app --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
APP_TOTAL=$(kubectl get pods -n fluxo-caixa -l app=fluxo-caixa-app --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$APP_READY" -eq "$APP_TOTAL" ] && [ "$APP_TOTAL" -gt 0 ]; then
    check_pass
    echo "  $APP_READY/$APP_TOTAL replicas prontas"
else
    check_fail
    echo "  $APP_READY/$APP_TOTAL replicas prontas"
fi

echo -n "3.4 Aplicação acessível (http://fluxo-caixa.local/health): "
if curl -s -f http://fluxo-caixa.local/health &>/dev/null; then
    check_pass
    HEALTH_STATUS=$(curl -s http://fluxo-caixa.local/health | jq -r '.status' 2>/dev/null || echo "unknown")
    echo "  Status: $HEALTH_STATUS"
else
    check_fail
fi

echo -n "3.5 API funcionando (GET /api/transacoes): "
if curl -s -f http://fluxo-caixa.local/api/transacoes &>/dev/null; then
    check_pass
    TRANSACOES_COUNT=$(curl -s http://fluxo-caixa.local/api/transacoes | jq '. | length' 2>/dev/null || echo "?")
    echo "  $TRANSACOES_COUNT transações encontradas"
else
    check_fail
fi

echo ""

# ============================================
# 4. MONITORAMENTO
# ============================================
echo "========================================="
echo "📊 4. MONITORAMENTO"
echo "========================================="
echo ""

echo -n "4.1 Namespace 'monitoring' existe: "
if kubectl get namespace monitoring &>/dev/null; then
    check_pass
else
    check_fail
fi

echo -n "4.2 Prometheus rodando: "
PROM_READY=$(kubectl get pods -n monitoring -l app=prometheus --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
if [ "$PROM_READY" -gt 0 ]; then
    check_pass
else
    check_fail
fi

echo -n "4.3 Prometheus PVC usando NFS: "
PROM_PVC_SC=$(kubectl get pvc prometheus-pvc -n monitoring -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
if [ "$PROM_PVC_SC" = "nfs-client" ]; then
    check_pass
    PROM_PVC_SIZE=$(kubectl get pvc prometheus-pvc -n monitoring -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
    echo "  StorageClass: $PROM_PVC_SC, Size: $PROM_PVC_SIZE"
else
    check_fail
    echo "  StorageClass: $PROM_PVC_SC (esperado: nfs-client)"
fi

echo -n "4.4 Grafana rodando: "
GRAFANA_READY=$(kubectl get pods -n monitoring -l app=grafana --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
if [ "$GRAFANA_READY" -gt 0 ]; then
    check_pass
else
    check_fail
fi

echo -n "4.5 Grafana PVC usando NFS: "
GRAFANA_PVC_SC=$(kubectl get pvc grafana-pvc -n monitoring -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
if [ "$GRAFANA_PVC_SC" = "nfs-client" ]; then
    check_pass
    GRAFANA_PVC_SIZE=$(kubectl get pvc grafana-pvc -n monitoring -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
    echo "  StorageClass: $GRAFANA_PVC_SC, Size: $GRAFANA_PVC_SIZE"
else
    check_fail
    echo "  StorageClass: $GRAFANA_PVC_SC (esperado: nfs-client)"
fi

echo -n "4.6 Grafana acessível (http://grafana.local): "
if curl -s -f http://grafana.local &>/dev/null; then
    check_pass
else
    check_fail
fi

echo -n "4.7 kube-state-metrics rodando: "
KSM_READY=$(kubectl get pods -n monitoring -l app=kube-state-metrics --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
if [ "$KSM_READY" -gt 0 ]; then
    check_pass
else
    check_fail
fi

echo ""

# ============================================
# 5. REDE E INGRESS
# ============================================
echo "========================================="
echo "🌐 5. REDE E INGRESS"
echo "========================================="
echo ""

echo -n "5.1 MetalLB instalado: "
METALLB_PODS=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$METALLB_PODS" -gt 0 ]; then
    check_pass
    echo "  $METALLB_PODS pods"
else
    check_fail
fi

echo -n "5.2 NGINX Ingress Controller rodando: "
NGINX_READY=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -c "1/1.*Running" || echo "0")
if [ "$NGINX_READY" -gt 0 ]; then
    check_pass
else
    check_fail
fi

echo -n "5.3 Ingress tem IP externo: "
APP_INGRESS_IP=$(kubectl get ingress fluxo-caixa-ingress -n fluxo-caixa -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$APP_INGRESS_IP" ]; then
    check_pass
    echo "  IP: $APP_INGRESS_IP"
else
    check_fail
fi

echo -n "5.4 /etc/hosts configurado: "
if grep -q "fluxo-caixa.local" /etc/hosts 2>/dev/null && grep -q "grafana.local" /etc/hosts 2>/dev/null; then
    check_pass
else
    check_fail
fi

echo ""

# ============================================
# 6. TESTES FUNCIONAIS
# ============================================
echo "========================================="
echo "🧪 6. TESTES FUNCIONAIS"
echo "========================================="
echo ""

echo -n "6.1 Criar transação via API: "
CREATE_RESPONSE=$(curl -s -X POST http://fluxo-caixa.local/api/transacoes \
  -H "Content-Type: application/json" \
  -d '{
    "usuario_id": 1,
    "categoria_id": 1,
    "tipo": "receita",
    "valor": 100.00,
    "descricao": "Teste automatizado",
    "data_transacao": "2025-10-21"
  }' 2>/dev/null)

if echo "$CREATE_RESPONSE" | jq -e '.id' &>/dev/null; then
    check_pass
    TRANS_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
    echo "  ID criado: $TRANS_ID"
else
    check_fail
fi

echo -n "6.2 Consultar saldo via API: "
if curl -s -f http://fluxo-caixa.local/api/transacoes/consultas/saldo &>/dev/null; then
    check_pass
    SALDO=$(curl -s http://fluxo-caixa.local/api/transacoes/consultas/saldo | jq -r '.[0].saldo_atual' 2>/dev/null || echo "?")
    echo "  Saldo atual: R$ $SALDO"
else
    check_fail
fi

echo -n "6.3 Consultar métricas Prometheus: "
if kubectl port-forward -n monitoring svc/prometheus 9091:9090 &>/dev/null & then
    PF_PID=$!
    sleep 2
    if curl -s http://localhost:9091/-/healthy &>/dev/null; then
        check_pass
    else
        check_fail
    fi
    kill $PF_PID 2>/dev/null || true
else
    check_fail
fi

echo ""

# ============================================
# 7. STORAGE NO NFS SERVER
# ============================================
echo "========================================="
echo "💾 7. STORAGE NO NFS SERVER"
echo "========================================="
echo ""

echo -n "7.1 Verificar dados no NFS (SSH): "
if ssh -o ConnectTimeout=5 -o BatchMode=yes admin@10.0.2.17 "ls /srv/nfs/k8s/" &>/dev/null; then
    check_pass
    NFS_DIRS=$(ssh admin@10.0.2.17 "ls /srv/nfs/k8s/ | wc -l" 2>/dev/null || echo "0")
    echo "  $NFS_DIRS diretórios encontrados"
else
    check_fail
    echo "  (Requer acesso SSH ao servidor NFS)"
fi

echo ""

# ============================================
# RESUMO
# ============================================
echo "========================================="
echo "📊 RESUMO"
echo "========================================="
echo ""

TOTAL_TESTS=$((PASS_COUNT + FAIL_COUNT))
PASS_PERCENT=$((PASS_COUNT * 100 / TOTAL_TESTS))

echo -e "${GREEN}✅ Testes Passaram: $PASS_COUNT${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}❌ Testes Falharam: $FAIL_COUNT${NC}"
fi
echo "📊 Total de Testes: $TOTAL_TESTS"
echo "📈 Taxa de Sucesso: $PASS_PERCENT%"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "========================================="
    echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM!${NC}"
    echo "========================================="
    echo ""
    echo "✅ Ambiente totalmente funcional!"
    echo ""
    echo "🌐 URLs de Acesso:"
    echo "  - Aplicação: http://fluxo-caixa.local"
    echo "  - Health Check: http://fluxo-caixa.local/health"
    echo "  - API: http://fluxo-caixa.local/api/transacoes"
    echo "  - Grafana: http://grafana.local (admin/admin123)"
    echo ""
    echo "📚 Próximos Passos:"
    echo "  1. Importar dashboards no Grafana"
    echo "  2. Configurar alertas"
    echo "  3. Começar planejamento de migração AWS"
    echo ""
else
    echo "========================================="
    echo -e "${YELLOW}⚠️  ALGUNS TESTES FALHARAM${NC}"
    echo "========================================="
    echo ""
    echo "Execute para mais detalhes:"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl get pvc --all-namespaces"
    echo "  kubectl get ingress --all-namespaces"
    echo ""
fi

exit $FAIL_COUNT

