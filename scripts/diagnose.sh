#!/bin/bash

# ============================================
# Script de Diagnóstico - Fluxo de Caixa
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
echo "🔍 Diagnóstico - Fluxo de Caixa"
echo "========================================="
echo ""

# Função para printar seção
print_section() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

# Função para printar sucesso
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Função para printar warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Função para printar erro
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Verificar se namespace existe
print_section "1. Verificando Namespace"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_success "Namespace '$NAMESPACE' existe"
else
    print_error "Namespace '$NAMESPACE' não existe"
    echo "Execute: kubectl apply -f k8s/00-namespace.yaml"
    exit 1
fi

# 2. Verificar pods
print_section "2. Status dos Pods"
kubectl get pods -n $NAMESPACE
echo ""

# Verificar se há pods pending
PENDING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PODS" -gt 0 ]; then
    print_warning "$PENDING_PODS pod(s) em estado Pending"
    echo ""
    echo "Detalhes dos pods Pending:"
    kubectl get pods -n $NAMESPACE --field-selector=status.phase=Pending
fi

# 3. Verificar PVCs
print_section "3. Status dos PVCs"
kubectl get pvc -n $NAMESPACE
echo ""

# Verificar se há PVCs pending
PENDING_PVCS=$(kubectl get pvc -n $NAMESPACE --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PVCS" -gt 0 ]; then
    print_error "$PENDING_PVCS PVC(s) em estado Pending"
    echo ""
    echo "Detalhes do PVC Pending:"
    kubectl describe pvc -n $NAMESPACE | grep -A 10 "Status:\s*Pending"
fi

# 4. Verificar StorageClasses
print_section "4. StorageClasses Disponíveis"
if kubectl get storageclass &> /dev/null; then
    kubectl get storageclass
    echo ""
    
    # Verificar se há default
    DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    if [ -n "$DEFAULT_SC" ]; then
        print_success "StorageClass padrão: $DEFAULT_SC"
    else
        print_warning "Nenhuma StorageClass padrão configurada"
    fi
else
    print_error "Nenhuma StorageClass encontrada"
fi

# 5. Verificar PVs
print_section "5. PersistentVolumes"
kubectl get pv
echo ""

# 6. Verificar recursos dos nodes
print_section "6. Recursos dos Nodes"
echo "CPU e Memória disponíveis:"
kubectl top nodes 2>/dev/null || print_warning "Metrics Server não instalado (kubectl top não disponível)"
echo ""
echo "Capacidade total dos nodes:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,STORAGE:.status.capacity.ephemeral-storage

# 7. Verificar eventos recentes
print_section "7. Eventos Recentes (últimos 10)"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -n 10

# 8. Detalhes do pod PostgreSQL (se existir)
print_section "8. Detalhes do Pod PostgreSQL"
if kubectl get pod postgres-0 -n $NAMESPACE &> /dev/null; then
    echo "Status:"
    kubectl get pod postgres-0 -n $NAMESPACE
    echo ""
    echo "Eventos do pod:"
    kubectl describe pod postgres-0 -n $NAMESPACE | grep -A 20 "Events:"
else
    print_warning "Pod postgres-0 não encontrado"
fi

# 9. Detalhes do PVC PostgreSQL (se existir)
print_section "9. Detalhes do PVC PostgreSQL"
if kubectl get pvc postgres-pvc -n $NAMESPACE &> /dev/null; then
    kubectl describe pvc postgres-pvc -n $NAMESPACE | grep -A 10 "Status:"
else
    print_warning "PVC postgres-pvc não encontrado"
fi

# 10. Verificar taints nos nodes
print_section "10. Taints nos Nodes"
TAINTS=$(kubectl get nodes -o json | jq -r '.items[] | select(.spec.taints != null) | .metadata.name + ": " + (.spec.taints | tostring)')
if [ -n "$TAINTS" ]; then
    print_warning "Nodes com taints encontrados:"
    echo "$TAINTS"
else
    print_success "Nenhum taint encontrado nos nodes"
fi

# 11. Resumo e Recomendações
print_section "11. Resumo e Recomendações"

if [ "$PENDING_PVCS" -gt 0 ]; then
    print_error "PROBLEMA DETECTADO: PVC em estado Pending"
    echo ""
    echo "Possíveis soluções:"
    echo "1. Verificar se StorageClass existe:"
    echo "   kubectl get storageclass"
    echo ""
    echo "2. Criar PV manual (homelab):"
    echo "   sudo mkdir -p /mnt/data/postgres"
    echo "   kubectl apply -f k8s/03-postgres-pv.yaml"
    echo ""
    echo "3. Instalar provisioner dinâmico:"
    echo "   kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml"
    echo ""
elif [ "$PENDING_PODS" -gt 0 ]; then
    print_error "PROBLEMA DETECTADO: Pod em estado Pending"
    echo ""
    echo "Verifique os eventos do pod para mais detalhes:"
    echo "kubectl describe pod postgres-0 -n $NAMESPACE"
else
    print_success "Nenhum problema crítico detectado"
fi

echo ""
echo "========================================="
echo "📝 Para mais detalhes, consulte:"
echo "   docs/troubleshooting.md"
echo "========================================="

