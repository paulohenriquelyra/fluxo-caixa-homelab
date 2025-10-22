#!/bin/bash

# ============================================
# Script - Limpar HostNetwork e Reinstalar MetalLB
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "🔄 Reset para MetalLB"
echo "========================================="
echo ""

echo -e "${YELLOW}Este script vai:${NC}"
echo "  1. Reverter configuração HostNetwork"
echo "  2. Desinstalar MetalLB antigo (se existir)"
echo "  3. Reinstalar MetalLB do zero"
echo "  4. Configurar pool de IPs na rede do Proxmox (10.0.2.0/23)"
echo ""
read -p "Deseja continuar? (s/N): " CONFIRM

if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo "Abortando..."
    exit 0
fi

echo ""
echo "========================================="
echo "Passo 1: Reverter HostNetwork"
echo "========================================="
echo ""

if kubectl get deployment ingress-nginx-controller -n ingress-nginx &> /dev/null; then
    echo -e "${BLUE}🔧 Revertendo HostNetwork no NGINX Ingress...${NC}"
    
    kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": false,
        "dnsPolicy": "ClusterFirst"
      }
    }
  }
}'
    
    echo -e "${GREEN}✅ HostNetwork revertido${NC}"
    
    # Aguardar rollout
    echo "Aguardando rollout..."
    kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=60s || {
        echo -e "${YELLOW}⚠️  Timeout no rollout. Forçando término dos pods...${NC}"
        kubectl delete pods -n ingress-nginx -l app.kubernetes.io/component=controller --force --grace-period=0
        sleep 10
    }
else
    echo -e "${YELLOW}⚠️  NGINX Ingress não encontrado${NC}"
fi

echo ""
echo "========================================="
echo "Passo 2: Limpar MetalLB Antigo"
echo "========================================="
echo ""

if kubectl get namespace metallb-system &> /dev/null; then
    echo -e "${BLUE}🗑️  Removendo MetalLB antigo...${NC}"
    kubectl delete namespace metallb-system
    echo "Aguardando namespace ser deletado..."
    sleep 10
    echo -e "${GREEN}✅ MetalLB antigo removido${NC}"
else
    echo -e "${GREEN}✅ MetalLB não estava instalado${NC}"
fi

echo ""
echo "========================================="
echo "Passo 3: Instalar MetalLB"
echo "========================================="
echo ""

echo -e "${BLUE}📦 Instalando MetalLB...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo ""
echo -e "${BLUE}⏳ Aguardando pods do MetalLB estarem prontos...${NC}"
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

echo ""
echo -e "${GREEN}✅ MetalLB instalado!${NC}"

echo ""
echo "========================================="
echo "Passo 4: Configurar Pool de IPs"
echo "========================================="
echo ""

echo -e "${BLUE}🔍 Análise da rede Proxmox (10.0.2.0/23)${NC}"
echo ""
echo "Rede: 10.0.2.0/23"
echo "Range: 10.0.2.0 - 10.0.3.255 (512 IPs)"
echo ""
echo "Seus nodes:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,IP:.status.addresses[0].address --no-headers | grep "10.0"
echo ""

# Sugerir range de IPs
echo -e "${YELLOW}📝 Sugestão de Pool de IPs:${NC}"
echo ""
echo "Opção 1 (Conservadora): 10.0.3.240 - 10.0.2.17 (11 IPs)"
echo "Opção 2 (Moderada):     10.0.3.230 - 10.0.2.17 (21 IPs)"
echo "Opção 3 (Ampla):        10.0.3.200 - 10.0.2.17 (51 IPs)"
echo ""

# Verificar IPs livres (sample)
echo "Verificando alguns IPs (pode demorar)..."
FREE_COUNT=0
for i in {240..250}; do
    IP="10.0.3.$i"
    if ! ping -c 1 -W 1 $IP > /dev/null 2>&1; then
        FREE_COUNT=$((FREE_COUNT + 1))
        echo -e "${GREEN}✅ 10.0.3.$i - LIVRE${NC}"
    else
        echo -e "${RED}❌ 10.0.3.$i - EM USO${NC}"
    fi
done

echo ""
echo "IPs livres encontrados (amostra): $FREE_COUNT/11"
echo ""

# Perguntar range
echo -e "${BLUE}Configurar Pool de IPs:${NC}"
read -p "IP inicial [10.0.3.240]: " IP_START
IP_START=${IP_START:-10.0.3.240}

read -p "IP final [10.0.2.17]: " IP_END
IP_END=${IP_END:-10.0.2.17}

echo ""
echo "Range configurado: $IP_START - $IP_END"
echo ""

# Criar configuração
echo -e "${BLUE}📝 Criando configuração do MetalLB...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: proxmox-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_START-$IP_END
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: proxmox-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - proxmox-pool
EOF

echo ""
echo -e "${GREEN}✅ Pool de IPs configurado!${NC}"

echo ""
echo "========================================="
echo "Passo 5: Converter Ingress para LoadBalancer"
echo "========================================="
echo ""

if kubectl get service ingress-nginx-controller -n ingress-nginx &> /dev/null; then
    echo -e "${BLUE}🔄 Convertendo NGINX Ingress para LoadBalancer...${NC}"
    
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
        
        # Verificar se IP está no range configurado
        if [[ "$EXTERNAL_IP" =~ ^10\.0\.[23]\. ]]; then
            echo -e "${GREEN}✅ IP está na rede do Proxmox (10.0.2.0/23)${NC}"
        else
            echo -e "${YELLOW}⚠️  IP fora da rede esperada${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}📝 Atualizando /etc/hosts...${NC}"
        
        # Remover entradas antigas
        sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
        
        # Adicionar nova entrada
        echo "$EXTERNAL_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts
        
        echo -e "${GREEN}✅ /etc/hosts atualizado!${NC}"
        echo ""
        
        # Testar conectividade
        echo -e "${BLUE}🧪 Testando conectividade...${NC}"
        echo ""
        
        echo "1. Ping para o IP do MetalLB:"
        if ping -c 3 $EXTERNAL_IP; then
            echo -e "${GREEN}✅ Ping funcionando!${NC}"
        else
            echo -e "${RED}❌ Ping falhou${NC}"
            echo "Verifique firewall ou roteamento"
        fi
        
        echo ""
        echo "2. Testando aplicação:"
        sleep 3
        
        if curl -s -o /dev/null -w "%{http_code}" http://fluxo-caixa.local/health | grep -q "200"; then
            echo -e "${GREEN}✅ Aplicação acessível!${NC}"
            echo ""
            curl -s http://fluxo-caixa.local/health | jq . 2>/dev/null || curl -s http://fluxo-caixa.local/health
        else
            echo -e "${YELLOW}⚠️  Aplicação ainda não respondeu (pode estar iniciando)${NC}"
            echo "Aguarde alguns segundos e tente:"
            echo "  curl http://fluxo-caixa.local/health"
        fi
        
    else
        echo -e "${RED}❌ Timeout aguardando IP externo${NC}"
        echo ""
        echo "Verifique:"
        echo "  kubectl get service -n ingress-nginx"
        echo "  kubectl logs -n metallb-system -l component=controller"
    fi
else
    echo -e "${YELLOW}⚠️  NGINX Ingress Controller não encontrado${NC}"
    echo "Instale primeiro:"
    echo "  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml"
fi

echo ""
echo "========================================="
echo "✅ Reset Concluído!"
echo "========================================="
echo ""

if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
    echo "🎉 Configuração bem-sucedida!"
    echo ""
    echo "IP do MetalLB: $EXTERNAL_IP"
    echo "URL: http://fluxo-caixa.local"
    echo ""
    echo "Teste:"
    echo "  curl http://fluxo-caixa.local/health"
    echo "  curl http://fluxo-caixa.local/api/transacoes"
    echo ""
fi

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
echo "# Ver logs do MetalLB"
echo "kubectl logs -n metallb-system -l component=controller"
echo ""

