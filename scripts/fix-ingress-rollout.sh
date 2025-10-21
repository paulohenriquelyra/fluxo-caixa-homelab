#!/bin/bash

# ============================================
# Script - Fix Rollout Travado do NGINX Ingress
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "🔧 Fix - Rollout Travado NGINX Ingress"
echo "========================================="
echo ""

echo -e "${BLUE}📊 Status atual dos pods...${NC}"
kubectl get pods -n ingress-nginx

echo ""
echo -e "${YELLOW}⚠️  Forçando término dos pods antigos...${NC}"

# Deletar pods antigos forçadamente
kubectl delete pods -n ingress-nginx -l app.kubernetes.io/component=controller --force --grace-period=0

echo ""
echo -e "${BLUE}⏳ Aguardando novos pods subirem...${NC}"
sleep 5

# Aguardar novos pods estarem prontos
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando pods. Verificando status...${NC}"
    kubectl get pods -n ingress-nginx
    kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller | tail -50
}

echo ""
echo -e "${GREEN}✅ Pods atualizados!${NC}"
kubectl get pods -n ingress-nginx

echo ""
echo -e "${BLUE}📝 Verificando Service...${NC}"
kubectl get service -n ingress-nginx

echo ""
echo -e "${BLUE}🔍 Obtendo IP do node...${NC}"
NODE_IP=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.hostIP}')

if [ -z "$NODE_IP" ]; then
    echo -e "${RED}❌ Não foi possível obter IP do node${NC}"
    echo "Pods atuais:"
    kubectl get pods -n ingress-nginx -o wide
    exit 1
fi

echo "IP do Node: $NODE_IP"

echo ""
echo -e "${BLUE}📝 Atualizando /etc/hosts...${NC}"
sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
echo "$NODE_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts

echo ""
echo -e "${GREEN}✅ /etc/hosts atualizado!${NC}"
cat /etc/hosts | grep fluxo-caixa

echo ""
echo -e "${BLUE}🧪 Testando conectividade...${NC}"
sleep 3

echo "Ping para o node:"
ping -c 3 $NODE_IP

echo ""
echo "Testando aplicação:"
if curl -s -o /dev/null -w "%{http_code}" http://fluxo-caixa.local/health | grep -q "200"; then
    echo -e "${GREEN}✅ Aplicação acessível!${NC}"
    curl -s http://fluxo-caixa.local/health | jq . || curl -s http://fluxo-caixa.local/health
else
    echo -e "${YELLOW}⚠️  Aplicação ainda não respondeu${NC}"
    echo "Aguarde alguns segundos e tente:"
    echo "  curl http://fluxo-caixa.local/health"
fi

echo ""
echo "========================================="
echo "✅ Fix Concluído!"
echo "========================================="
echo ""
echo "Acesse: http://fluxo-caixa.local/health"
echo ""

