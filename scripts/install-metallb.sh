#!/bin/bash

# ============================================
# Script de Instalação - MetalLB
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "🔧 Instalação do MetalLB"
echo "========================================="
echo ""

# Verificar se já está instalado
if kubectl get namespace metallb-system &> /dev/null; then
    echo -e "${YELLOW}⚠️  MetalLB já está instalado${NC}"
    read -p "Deseja reinstalar? (s/N): " REINSTALL
    if [ "$REINSTALL" != "s" ] && [ "$REINSTALL" != "S" ]; then
        echo "Abortando..."
        exit 0
    fi
    echo "Removendo instalação anterior..."
    kubectl delete namespace metallb-system
    sleep 5
fi

# Instalar MetalLB
echo -e "${BLUE}📦 Instalando MetalLB...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo ""
echo -e "${BLUE}⏳ Aguardando pods do MetalLB estarem prontos...${NC}"
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

echo ""
echo -e "${GREEN}✅ MetalLB instalado com sucesso!${NC}"
echo ""

# Detectar rede
echo -e "${BLUE}🔍 Detectando configuração de rede...${NC}"
DEFAULT_ROUTE=$(ip route | grep default | head -n1)
echo "Rota padrão: $DEFAULT_ROUTE"
echo ""

# Obter gateway
GATEWAY=$(echo $DEFAULT_ROUTE | awk '{print $3}')
echo "Gateway: $GATEWAY"

# Sugerir range de IPs
IFS='.' read -r -a IP_PARTS <<< "$GATEWAY"
NETWORK_PREFIX="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}"
SUGGESTED_START="$NETWORK_PREFIX.200"
SUGGESTED_END="$NETWORK_PREFIX.210"

echo ""
echo -e "${YELLOW}📝 Configuração do Pool de IPs${NC}"
echo "========================================="
echo ""
echo "Você precisa escolher um range de IPs LIVRES na sua rede."
echo "Esses IPs serão usados pelo LoadBalancer."
echo ""
echo "Rede detectada: $NETWORK_PREFIX.0/24"
echo "Range sugerido: $SUGGESTED_START - $SUGGESTED_END"
echo ""

# Verificar IPs livres
echo "Verificando IPs disponíveis (pode demorar alguns segundos)..."
echo ""
FREE_IPS=()
for i in {200..210}; do
    IP="$NETWORK_PREFIX.$i"
    if ! ping -c 1 -W 1 $IP > /dev/null 2>&1; then
        FREE_IPS+=("$IP")
        echo -e "${GREEN}✅ $IP - LIVRE${NC}"
    else
        echo -e "${RED}❌ $IP - EM USO${NC}"
    fi
done

echo ""
if [ ${#FREE_IPS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Nenhum IP livre encontrado no range 200-210${NC}"
    echo "Você precisará escolher outro range manualmente."
    IP_START=""
    IP_END=""
else
    echo -e "${GREEN}✅ ${#FREE_IPS[@]} IPs livres encontrados${NC}"
    IP_START="${FREE_IPS[0]}"
    IP_END="${FREE_IPS[-1]}"
fi

echo ""
echo "========================================="
echo "Configurar Pool de IPs"
echo "========================================="
echo ""

# Perguntar range
read -p "IP inicial [$IP_START]: " INPUT_START
IP_START=${INPUT_START:-$IP_START}

read -p "IP final [$IP_END]: " INPUT_END
IP_END=${INPUT_END:-$IP_END}

echo ""
echo "Range configurado: $IP_START - $IP_END"
echo ""

# Criar configuração
echo -e "${BLUE}📝 Criando configuração do MetalLB...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_START-$IP_END
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

echo ""
echo -e "${GREEN}✅ Pool de IPs configurado!${NC}"
echo ""

# Converter Ingress Controller para LoadBalancer
echo -e "${BLUE}🔄 Convertendo NGINX Ingress para LoadBalancer...${NC}"

if kubectl get service ingress-nginx-controller -n ingress-nginx &> /dev/null; then
    kubectl patch service ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'
    
    echo ""
    echo -e "${BLUE}⏳ Aguardando IP externo ser atribuído...${NC}"
    echo "Isso pode levar alguns segundos..."
    echo ""
    
    # Aguardar IP ser atribuído (timeout 60s)
    for i in {1..60}; do
        EXTERNAL_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo ""
        echo -e "${GREEN}✅ IP externo atribuído: $EXTERNAL_IP${NC}"
        echo ""
        
        # Atualizar /etc/hosts
        echo -e "${BLUE}📝 Atualizando /etc/hosts...${NC}"
        
        # Remover entrada antiga
        sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
        
        # Adicionar nova entrada
        echo "$EXTERNAL_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts
        
        echo -e "${GREEN}✅ /etc/hosts atualizado!${NC}"
        echo ""
        
        # Testar
        echo -e "${BLUE}🧪 Testando conectividade...${NC}"
        sleep 3
        
        if curl -s -o /dev/null -w "%{http_code}" http://fluxo-caixa.local/health | grep -q "200"; then
            echo -e "${GREEN}✅ Aplicação acessível em http://fluxo-caixa.local${NC}"
        else
            echo -e "${YELLOW}⚠️  Aplicação ainda não respondeu (pode estar iniciando)${NC}"
            echo "Tente: curl http://fluxo-caixa.local/health"
        fi
    else
        echo -e "${RED}❌ Timeout aguardando IP externo${NC}"
        echo "Verifique: kubectl get service -n ingress-nginx"
    fi
else
    echo -e "${YELLOW}⚠️  NGINX Ingress Controller não encontrado${NC}"
    echo "Instale primeiro: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml"
fi

echo ""
echo "========================================="
echo "✅ Instalação Concluída!"
echo "========================================="
echo ""
echo "Comandos úteis:"
echo ""
echo "# Ver status do MetalLB"
echo "kubectl get pods -n metallb-system"
echo ""
echo "# Ver pool de IPs"
echo "kubectl get ipaddresspool -n metallb-system"
echo ""
echo "# Ver IP do Ingress"
echo "kubectl get service -n ingress-nginx"
echo ""
echo "# Testar aplicação"
echo "curl http://fluxo-caixa.local/health"
echo ""

