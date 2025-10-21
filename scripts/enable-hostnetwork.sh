#!/bin/bash

# ============================================
# Script - Habilitar HostNetwork no NGINX Ingress
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "🔧 Habilitar HostNetwork - NGINX Ingress"
echo "========================================="
echo ""

# Verificar se NGINX Ingress está instalado
if ! kubectl get deployment ingress-nginx-controller -n ingress-nginx &> /dev/null; then
    echo -e "${RED}❌ NGINX Ingress Controller não encontrado${NC}"
    echo ""
    echo "Instale primeiro:"
    echo "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml"
    exit 1
fi

echo -e "${GREEN}✅ NGINX Ingress Controller encontrado${NC}"
echo ""

# Avisar sobre limitações
echo -e "${YELLOW}⚠️  ATENÇÃO:${NC}"
echo "HostNetwork faz o Ingress usar a rede do host diretamente."
echo ""
echo "Vantagens:"
echo "  ✅ Portas 80 e 443 nativas (sem NodePort)"
echo "  ✅ Simples de configurar"
echo ""
echo "Desvantagens:"
echo "  ❌ Apenas um Ingress Controller por node"
echo "  ❌ Pode conflitar com outros serviços na porta 80/443"
echo ""
read -p "Deseja continuar? (s/N): " CONFIRM

if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo "Abortando..."
    exit 0
fi

echo ""

# Verificar se porta 80 está livre no node
echo -e "${BLUE}🔍 Verificando disponibilidade da porta 80...${NC}"

# Obter node onde o Ingress está rodando
NODE_NAME=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].spec.nodeName}')
echo "Node do Ingress: $NODE_NAME"

# Verificar porta 80 (se estiver no mesmo node)
if command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":80 "; then
        echo -e "${YELLOW}⚠️  Porta 80 parece estar em uso${NC}"
        netstat -tuln | grep ":80 "
        echo ""
        read -p "Continuar mesmo assim? (s/N): " FORCE
        if [ "$FORCE" != "s" ] && [ "$FORCE" != "S" ]; then
            echo "Abortando..."
            exit 0
        fi
    else
        echo -e "${GREEN}✅ Porta 80 disponível${NC}"
    fi
fi

echo ""

# Aplicar patch
echo -e "${BLUE}🔧 Aplicando configuração HostNetwork...${NC}"

kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true,
        "dnsPolicy": "ClusterFirstWithHostNet"
      }
    }
  }
}'

echo ""
echo -e "${BLUE}⏳ Aguardando rollout do deployment...${NC}"
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=120s

echo ""
echo -e "${GREEN}✅ HostNetwork habilitado!${NC}"
echo ""

# Obter IP do node
echo -e "${BLUE}📝 Configurando /etc/hosts...${NC}"
NODE_IP=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.hostIP}')

if [ -z "$NODE_IP" ]; then
    echo -e "${RED}❌ Não foi possível obter IP do node${NC}"
    echo "Obtenha manualmente: kubectl get nodes -o wide"
    exit 1
fi

echo "IP do Node: $NODE_IP"
echo ""

# Atualizar /etc/hosts
echo "Atualizando /etc/hosts..."
sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
echo "$NODE_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts

echo -e "${GREEN}✅ /etc/hosts atualizado!${NC}"
echo ""

# Testar
echo -e "${BLUE}🧪 Testando conectividade...${NC}"
sleep 3

if curl -s -o /dev/null -w "%{http_code}" http://fluxo-caixa.local/health | grep -q "200"; then
    echo -e "${GREEN}✅ Aplicação acessível em http://fluxo-caixa.local${NC}"
    echo ""
    echo "Teste completo:"
    curl -s http://fluxo-caixa.local/health | jq . || curl -s http://fluxo-caixa.local/health
else
    echo -e "${YELLOW}⚠️  Aplicação ainda não respondeu (pode estar iniciando)${NC}"
    echo ""
    echo "Aguarde alguns segundos e tente:"
    echo "  curl http://fluxo-caixa.local/health"
fi

echo ""
echo "========================================="
echo "✅ Configuração Concluída!"
echo "========================================="
echo ""
echo "Acesse a aplicação:"
echo "  http://fluxo-caixa.local/health"
echo "  http://fluxo-caixa.local/api/transacoes"
echo ""
echo "Comandos úteis:"
echo ""
echo "# Ver pods do Ingress"
echo "kubectl get pods -n ingress-nginx -o wide"
echo ""
echo "# Ver logs"
echo "kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f"
echo ""
echo "# Reverter (se necessário)"
echo "kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{\"spec\":{\"template\":{\"spec\":{\"hostNetwork\":false,\"dnsPolicy\":\"ClusterFirst\"}}}}'"
echo ""

