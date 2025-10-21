#!/bin/bash

# ============================================
# Script de Diagnóstico - Ingress
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="fluxo-caixa"

echo "========================================="
echo "🔍 Diagnóstico - Ingress"
echo "========================================="
echo ""

# Função para printar seção
print_section() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Verificar se Ingress Controller está instalado
print_section "1. Ingress Controller"

# Procurar por ingress controller comum
INGRESS_NS=""
if kubectl get namespace ingress-nginx &> /dev/null; then
    INGRESS_NS="ingress-nginx"
    print_success "NGINX Ingress Controller encontrado (namespace: ingress-nginx)"
elif kubectl get namespace traefik &> /dev/null; then
    INGRESS_NS="traefik"
    print_success "Traefik Ingress Controller encontrado (namespace: traefik)"
else
    # Procurar em kube-system
    if kubectl get pods -n kube-system | grep -q "ingress"; then
        INGRESS_NS="kube-system"
        print_warning "Ingress Controller encontrado em kube-system"
    else
        print_error "Nenhum Ingress Controller encontrado!"
        echo ""
        echo "Instale um Ingress Controller:"
        echo ""
        echo "NGINX Ingress Controller:"
        echo "  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml"
        echo ""
        echo "Ou para bare-metal:"
        echo "  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml"
        exit 1
    fi
fi

echo ""
echo "Pods do Ingress Controller:"
kubectl get pods -n $INGRESS_NS

# 2. Verificar Ingress do fluxo-caixa
print_section "2. Ingress do Fluxo de Caixa"

if kubectl get ingress -n $NAMESPACE &> /dev/null; then
    kubectl get ingress -n $NAMESPACE
    echo ""
    
    # Detalhes do Ingress
    echo "Detalhes do Ingress:"
    kubectl describe ingress -n $NAMESPACE | grep -A 5 "Rules:"
else
    print_error "Ingress não encontrado no namespace $NAMESPACE"
    exit 1
fi

# 3. Verificar Service da aplicação
print_section "3. Service da Aplicação"

if kubectl get service fluxo-caixa-service -n $NAMESPACE &> /dev/null; then
    kubectl get service fluxo-caixa-service -n $NAMESPACE
    
    # Verificar endpoints
    echo ""
    echo "Endpoints do Service:"
    kubectl get endpoints fluxo-caixa-service -n $NAMESPACE
else
    print_error "Service fluxo-caixa-service não encontrado"
fi

# 4. Verificar Pods da aplicação
print_section "4. Pods da Aplicação"

kubectl get pods -n $NAMESPACE -l app=fluxo-caixa-app

# Verificar se há pods rodando
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE -l app=fluxo-caixa-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$RUNNING_PODS" -eq 0 ]; then
    print_error "Nenhum pod da aplicação está Running!"
    echo ""
    echo "Verifique os logs dos pods:"
    echo "  kubectl describe pods -n $NAMESPACE -l app=fluxo-caixa-app"
else
    print_success "$RUNNING_PODS pod(s) da aplicação Running"
fi

# 5. Obter IP do Ingress Controller
print_section "5. IP do Ingress Controller"

# Tentar obter IP externo
EXTERNAL_IP=$(kubectl get service -n $INGRESS_NS -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" == "null" ]; then
    # Tentar NodePort
    NODE_PORT=$(kubectl get service -n $INGRESS_NS -o jsonpath='{.items[0].spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
    
    if [ -n "$NODE_PORT" ] && [ "$NODE_PORT" != "null" ]; then
        print_warning "Ingress usando NodePort: $NODE_PORT"
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "IP do Node: $NODE_IP"
        echo ""
        echo "Acesse via: http://$NODE_IP:$NODE_PORT"
    else
        print_warning "Ingress não tem IP externo nem NodePort"
        echo ""
        echo "Service do Ingress Controller:"
        kubectl get service -n $INGRESS_NS
    fi
else
    print_success "IP Externo do Ingress: $EXTERNAL_IP"
fi

# 6. Verificar /etc/hosts
print_section "6. Configuração /etc/hosts"

INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[0].host}')
echo "Host configurado no Ingress: $INGRESS_HOST"
echo ""

if grep -q "$INGRESS_HOST" /etc/hosts 2>/dev/null; then
    print_success "Entrada encontrada em /etc/hosts:"
    grep "$INGRESS_HOST" /etc/hosts
else
    print_warning "Entrada NÃO encontrada em /etc/hosts"
    echo ""
    echo "Adicione ao /etc/hosts:"
    
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo "  echo \"$EXTERNAL_IP  $INGRESS_HOST\" | sudo tee -a /etc/hosts"
    elif [ -n "$NODE_IP" ]; then
        echo "  echo \"$NODE_IP  $INGRESS_HOST\" | sudo tee -a /etc/hosts"
    else
        echo "  echo \"127.0.0.1  $INGRESS_HOST\" | sudo tee -a /etc/hosts"
    fi
fi

# 7. Testar conectividade
print_section "7. Testes de Conectividade"

# Teste 1: Port-forward direto para o service
echo "Teste 1: Port-forward para o service"
echo "Execute em outro terminal:"
echo "  kubectl port-forward -n $NAMESPACE service/fluxo-caixa-service 8080:80"
echo "  curl http://localhost:8080/health"
echo ""

# Teste 2: Curl para o pod diretamente
if [ "$RUNNING_PODS" -gt 0 ]; then
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=fluxo-caixa-app --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
    echo "Teste 2: Curl direto no pod"
    echo "  kubectl exec -it $POD_NAME -n $NAMESPACE -- wget -O- http://localhost:3000/health"
    echo ""
fi

# Teste 3: Curl via Ingress
echo "Teste 3: Curl via Ingress (após configurar /etc/hosts)"
echo "  curl http://$INGRESS_HOST/health"
echo "  curl -v http://$INGRESS_HOST/health"
echo ""

# 8. Logs do Ingress Controller
print_section "8. Logs do Ingress Controller (últimas 10 linhas)"

INGRESS_POD=$(kubectl get pods -n $INGRESS_NS -o jsonpath='{.items[0].metadata.name}')
if [ -n "$INGRESS_POD" ]; then
    kubectl logs -n $INGRESS_NS $INGRESS_POD --tail=10 2>/dev/null || echo "Não foi possível obter logs"
fi

# 9. Resumo e Recomendações
print_section "9. Resumo e Recomendações"

echo "Checklist:"
echo ""

# Check 1: Ingress Controller
if [ -n "$INGRESS_NS" ]; then
    print_success "Ingress Controller instalado"
else
    print_error "Ingress Controller NÃO instalado"
fi

# Check 2: Pods Running
if [ "$RUNNING_PODS" -gt 0 ]; then
    print_success "Pods da aplicação Running"
else
    print_error "Pods da aplicação NÃO estão Running"
fi

# Check 3: /etc/hosts
if grep -q "$INGRESS_HOST" /etc/hosts 2>/dev/null; then
    print_success "/etc/hosts configurado"
else
    print_warning "/etc/hosts NÃO configurado"
fi

echo ""
echo "========================================="
echo "📝 Próximos Passos:"
echo "========================================="
echo ""

if ! grep -q "$INGRESS_HOST" /etc/hosts 2>/dev/null; then
    echo "1. Adicionar entrada ao /etc/hosts:"
    if [ -n "$NODE_IP" ]; then
        echo "   echo \"$NODE_IP  $INGRESS_HOST\" | sudo tee -a /etc/hosts"
    else
        echo "   echo \"127.0.0.1  $INGRESS_HOST\" | sudo tee -a /etc/hosts"
    fi
    echo ""
fi

echo "2. Testar acesso:"
echo "   curl http://$INGRESS_HOST/health"
echo ""

if [ -n "$NODE_PORT" ]; then
    echo "3. Ou acessar via NodePort:"
    echo "   curl http://$NODE_IP:$NODE_PORT/health"
    echo ""
fi

echo "4. Ver logs da aplicação:"
echo "   kubectl logs -f deployment/fluxo-caixa-app -n $NAMESPACE"
echo ""

echo "5. Ver logs do Ingress:"
echo "   kubectl logs -f -n $INGRESS_NS $INGRESS_POD"
echo ""

