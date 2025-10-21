#!/bin/bash

# ============================================
# Script de Deploy - Fluxo de Caixa Homelab
# ============================================

set -e  # Parar em caso de erro

echo "========================================="
echo "🚀 Deploy Fluxo de Caixa - Homelab"
echo "========================================="

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="${BASE_DIR}/k8s"
DB_DIR="${BASE_DIR}/database"

echo -e "${YELLOW}📁 Diretório base: ${BASE_DIR}${NC}"

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl não encontrado. Instale o kubectl primeiro.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ kubectl encontrado${NC}"

# Verificar conexão com cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Não foi possível conectar ao cluster Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Conectado ao cluster Kubernetes${NC}"

# 1. Criar namespace
echo ""
echo -e "${YELLOW}📦 Criando namespace...${NC}"
kubectl apply -f "${K8S_DIR}/00-namespace.yaml"

# 2. Criar ConfigMaps e Secrets
echo ""
echo -e "${YELLOW}🔧 Criando ConfigMaps e Secrets...${NC}"
kubectl apply -f "${K8S_DIR}/01-postgres-configmap.yaml"
kubectl apply -f "${K8S_DIR}/02-postgres-secret.yaml"
kubectl apply -f "${K8S_DIR}/06-app-configmap.yaml"

# 3. Criar PVC
echo ""
echo -e "${YELLOW}💾 Criando PersistentVolumeClaim...${NC}"
kubectl apply -f "${K8S_DIR}/03-postgres-pvc.yaml"

# 4. Deploy PostgreSQL
echo ""
echo -e "${YELLOW}🐘 Fazendo deploy do PostgreSQL...${NC}"
kubectl apply -f "${K8S_DIR}/04-postgres-statefulset.yaml"
kubectl apply -f "${K8S_DIR}/05-postgres-service.yaml"

# Aguardar PostgreSQL estar pronto
echo ""
echo -e "${YELLOW}⏳ Aguardando PostgreSQL estar pronto...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n fluxo-caixa --timeout=120s

echo -e "${GREEN}✅ PostgreSQL pronto!${NC}"

# 5. Inicializar banco de dados
echo ""
echo -e "${YELLOW}🗄️  Inicializando banco de dados...${NC}"

# Copiar scripts SQL para o pod
echo "   Copiando scripts SQL..."
kubectl cp "${DB_DIR}/01-schema.sql" fluxo-caixa/postgres-0:/tmp/
kubectl cp "${DB_DIR}/02-views.sql" fluxo-caixa/postgres-0:/tmp/
kubectl cp "${DB_DIR}/03-procedures.sql" fluxo-caixa/postgres-0:/tmp/
kubectl cp "${DB_DIR}/04-functions.sql" fluxo-caixa/postgres-0:/tmp/
kubectl cp "${DB_DIR}/05-seed.sql" fluxo-caixa/postgres-0:/tmp/

# Executar scripts
echo "   Executando scripts SQL..."
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/01-schema.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/02-views.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/03-procedures.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/04-functions.sql
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -d fluxocaixa -f /tmp/05-seed.sql

echo -e "${GREEN}✅ Banco de dados inicializado!${NC}"

# 6. Deploy da aplicação
echo ""
echo -e "${YELLOW}🚀 Fazendo deploy da aplicação...${NC}"
echo -e "${YELLOW}⚠️  ATENÇÃO: Certifique-se de ter feito o build e push da imagem Docker!${NC}"
read -p "Continuar com o deploy da aplicação? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    kubectl apply -f "${K8S_DIR}/07-app-deployment.yaml"
    kubectl apply -f "${K8S_DIR}/08-app-service.yaml"
    kubectl apply -f "${K8S_DIR}/09-ingress.yaml"
    
    echo ""
    echo -e "${YELLOW}⏳ Aguardando aplicação estar pronta...${NC}"
    kubectl wait --for=condition=available deployment/fluxo-caixa-app -n fluxo-caixa --timeout=120s
    
    echo -e "${GREEN}✅ Aplicação pronta!${NC}"
else
    echo -e "${YELLOW}⏭️  Deploy da aplicação pulado${NC}"
fi

# 7. Exibir status
echo ""
echo "========================================="
echo -e "${GREEN}✅ Deploy concluído!${NC}"
echo "========================================="
echo ""
echo "📊 Status dos recursos:"
kubectl get all -n fluxo-caixa

echo ""
echo "🌐 Ingress:"
kubectl get ingress -n fluxo-caixa

echo ""
echo "========================================="
echo "📝 Próximos passos:"
echo "========================================="
echo "1. Verificar logs do PostgreSQL:"
echo "   kubectl logs -f postgres-0 -n fluxo-caixa"
echo ""
echo "2. Verificar logs da aplicação:"
echo "   kubectl logs -f deployment/fluxo-caixa-app -n fluxo-caixa"
echo ""
echo "3. Testar health check:"
echo "   kubectl port-forward -n fluxo-caixa service/fluxo-caixa-service 8080:80"
echo "   curl http://localhost:8080/health"
echo ""
echo "4. Acessar via Ingress (ajustar /etc/hosts se necessário):"
echo "   curl http://fluxo-caixa.local/health"
echo "========================================="

