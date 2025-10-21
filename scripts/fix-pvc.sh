#!/bin/bash

# ============================================
# Script de Fix Rápido - PVC Pending
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="fluxo-caixa"

echo "========================================="
echo "🔧 Fix Rápido - PVC Pending"
echo "========================================="
echo ""

# Verificar se PVC existe e está Pending
PVC_STATUS=$(kubectl get pvc postgres-pvc -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [ "$PVC_STATUS" == "NotFound" ]; then
    echo -e "${RED}❌ PVC postgres-pvc não encontrado${NC}"
    exit 1
elif [ "$PVC_STATUS" == "Bound" ]; then
    echo -e "${GREEN}✅ PVC já está Bound. Nenhuma ação necessária.${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  PVC está em estado: $PVC_STATUS${NC}"
echo ""

# Verificar se existe StorageClass
echo "Verificando StorageClasses disponíveis..."
SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)

if [ "$SC_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Nenhuma StorageClass encontrada${NC}"
    echo ""
    echo "Opções:"
    echo "1. Criar PV manual (recomendado para homelab)"
    echo "2. Instalar provisioner dinâmico"
    echo ""
    read -p "Escolha uma opção (1 ou 2): " OPTION
    
    if [ "$OPTION" == "1" ]; then
        echo ""
        echo "Criando PV manual..."
        
        # Perguntar o node
        echo ""
        echo "Nodes disponíveis:"
        kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers
        echo ""
        read -p "Digite o nome do node onde criar o volume (ou pressione Enter para qualquer): " NODE_NAME
        
        # Criar diretório no node (se possível)
        if [ -n "$NODE_NAME" ]; then
            echo "Tentando criar diretório no node $NODE_NAME..."
            kubectl debug node/$NODE_NAME -it --image=busybox -- sh -c "mkdir -p /host/mnt/data/postgres && chmod 777 /host/mnt/data/postgres" 2>/dev/null || {
                echo -e "${YELLOW}⚠️  Não foi possível criar diretório automaticamente${NC}"
                echo "Execute manualmente no node:"
                echo "  sudo mkdir -p /mnt/data/postgres"
                echo "  sudo chmod 777 /mnt/data/postgres"
                echo ""
                read -p "Pressione Enter após criar o diretório..."
            }
        else
            echo -e "${YELLOW}⚠️  Crie o diretório manualmente em um dos nodes:${NC}"
            echo "  sudo mkdir -p /mnt/data/postgres"
            echo "  sudo chmod 777 /mnt/data/postgres"
            echo ""
            read -p "Pressione Enter após criar o diretório..."
        fi
        
        # Criar PV
        echo ""
        echo "Criando PersistentVolume..."
        kubectl apply -f k8s/03-postgres-pv-manual.yaml
        
        # Atualizar PVC
        echo "Atualizando PVC..."
        kubectl patch pvc postgres-pvc -n $NAMESPACE -p '{"spec":{"storageClassName":"manual"}}'
        
        echo ""
        echo -e "${GREEN}✅ PV manual criado e PVC atualizado${NC}"
        
    elif [ "$OPTION" == "2" ]; then
        echo ""
        echo "Instalando Local Path Provisioner..."
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
        
        echo ""
        echo "Aguardando provisioner estar pronto..."
        kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=60s
        
        echo ""
        echo "Definindo como StorageClass padrão..."
        kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        
        echo ""
        echo "Recriando PVC..."
        kubectl delete pvc postgres-pvc -n $NAMESPACE
        kubectl apply -f k8s/03-postgres-pvc.yaml
        
        echo ""
        echo -e "${GREEN}✅ Provisioner instalado e PVC recriado${NC}"
    else
        echo -e "${RED}❌ Opção inválida${NC}"
        exit 1
    fi
else
    # Existe StorageClass, usar a default
    DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    
    if [ -n "$DEFAULT_SC" ]; then
        echo -e "${GREEN}✅ StorageClass padrão encontrada: $DEFAULT_SC${NC}"
        echo ""
        echo "Recriando PVC com StorageClass padrão..."
        kubectl delete pvc postgres-pvc -n $NAMESPACE
        kubectl apply -f k8s/03-postgres-pvc.yaml
        echo -e "${GREEN}✅ PVC recriado${NC}"
    else
        echo "StorageClasses disponíveis:"
        kubectl get storageclass
        echo ""
        read -p "Digite o nome da StorageClass a usar: " SC_NAME
        
        echo ""
        echo "Atualizando PVC..."
        kubectl patch pvc postgres-pvc -n $NAMESPACE -p "{\"spec\":{\"storageClassName\":\"$SC_NAME\"}}"
        echo -e "${GREEN}✅ PVC atualizado${NC}"
    fi
fi

# Verificar resultado
echo ""
echo "Verificando status do PVC..."
sleep 3
kubectl get pvc postgres-pvc -n $NAMESPACE

echo ""
echo "Verificando pods..."
kubectl get pods -n $NAMESPACE

echo ""
echo "========================================="
echo "✅ Fix aplicado!"
echo ""
echo "Aguarde alguns segundos e verifique:"
echo "  kubectl get pvc -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE -w"
echo "========================================="

