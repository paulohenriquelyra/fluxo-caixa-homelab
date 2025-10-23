#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "📦 Instalação do NFS Client em Todos os Nodes"
echo "========================================="
echo ""

# Obter lista de nodes
NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

if [ -z "$NODES" ]; then
    echo -e "${RED}❌ Nenhum node encontrado!${NC}"
    exit 1
fi

echo -e "${BLUE}Nodes encontrados:${NC}"
for node_ip in $NODES; do
    NODE_NAME=$(kubectl get nodes -o json | jq -r ".items[] | select(.status.addresses[].address==\"$node_ip\") | .metadata.name")
    echo "  - $NODE_NAME ($node_ip)"
done
echo ""

# Perguntar usuário SSH
echo -e "${YELLOW}Digite o usuário SSH dos nodes (ex: ubuntu, admin):${NC}"
read -r SSH_USER

if [ -z "$SSH_USER" ]; then
    echo -e "${RED}❌ Usuário não pode ser vazio!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⚠️  Certifique-se de ter acesso SSH sem senha (chave SSH) configurado!${NC}"
echo -e "${YELLOW}Pressione Enter para continuar ou Ctrl+C para cancelar...${NC}"
read

# Instalar em cada node
SUCCESS_COUNT=0
FAIL_COUNT=0

for node_ip in $NODES; do
    NODE_NAME=$(kubectl get nodes -o json | jq -r ".items[] | select(.status.addresses[].address==\"$node_ip\") | .metadata.name")
    
    echo ""
    echo "========================================="
    echo -e "${BLUE}📦 Instalando em: $NODE_NAME ($node_ip)${NC}"
    echo "========================================="
    
    # Testar conectividade SSH
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$node_ip" "echo 'SSH OK'" &>/dev/null; then
        echo -e "${RED}❌ Falha ao conectar via SSH${NC}"
        echo -e "${YELLOW}Tente manualmente:${NC}"
        echo "  ssh $SSH_USER@$node_ip"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    
    # Verificar se já está instalado
    if ssh "$SSH_USER@$node_ip" "which mount.nfs" &>/dev/null; then
        echo -e "${GREEN}✅ NFS client já está instalado${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        continue
    fi
    
    # Instalar nfs-common
    echo -e "${YELLOW}Instalando nfs-common...${NC}"
    if ssh "$SSH_USER@$node_ip" "sudo apt-get update -qq && sudo apt-get install -y nfs-common" &>/dev/null; then
        echo -e "${GREEN}✅ NFS client instalado com sucesso${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}❌ Falha ao instalar${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "========================================="
echo "📊 Resumo"
echo "========================================="
echo -e "${GREEN}✅ Sucesso: $SUCCESS_COUNT nodes${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}❌ Falhas: $FAIL_COUNT nodes${NC}"
fi
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Alguns nodes falharam. Instale manualmente:${NC}"
    echo ""
    for node_ip in $NODES; do
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$node_ip" "which mount.nfs" &>/dev/null; then
            NODE_NAME=$(kubectl get nodes -o json | jq -r ".items[] | select(.status.addresses[].address==\"$node_ip\") | .metadata.name")
            echo "  ssh $SSH_USER@$node_ip"
            echo "  sudo apt-get update && sudo apt-get install -y nfs-common"
            echo ""
        fi
    done
fi

echo "========================================="
echo "🧪 Teste de Montagem"
echo "========================================="
echo ""
echo "Teste em um node:"
echo "  ssh $SSH_USER@<node-ip>"
echo "  sudo mkdir -p /mnt/nfs-test"
echo "  sudo mount -t nfs 10.0.2.17:/srv/nfs/k8s /mnt/nfs-test"
echo "  echo 'teste' | sudo tee /mnt/nfs-test/teste.txt"
echo "  cat /mnt/nfs-test/teste.txt"
echo "  sudo umount /mnt/nfs-test"
echo ""
