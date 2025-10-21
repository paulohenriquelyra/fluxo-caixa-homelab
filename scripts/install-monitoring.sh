#!/bin/bash

# ============================================
# Script de Instalação - Prometheus + Grafana
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "📊 Instalação do Stack de Monitoramento"
echo "========================================="
echo ""
echo "Este script vai instalar:"
echo "  • Prometheus"
echo "  • Grafana"
echo "  • PostgreSQL Exporter"
echo "  • kube-state-metrics"
echo "  • Dashboards pré-configurados"
echo ""
read -p "Deseja continuar? (s/N): " CONFIRM

if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo "Abortando..."
    exit 0
fi

echo ""
echo "========================================="
echo "Passo 1: Criar Namespace"
echo "========================================="
echo ""

kubectl apply -f monitoring/00-namespace.yaml
echo -e "${GREEN}✅ Namespace criado${NC}"

echo ""
echo "========================================="
echo "Passo 2: Instalar Prometheus"
echo "========================================="
echo ""

echo -e "${BLUE}📦 Aplicando manifestos do Prometheus...${NC}"
kubectl apply -f monitoring/prometheus/

echo ""
echo -e "${BLUE}⏳ Aguardando Prometheus estar pronto...${NC}"
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=prometheus \
  --timeout=120s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando Prometheus${NC}"
    echo "Verificando status:"
    kubectl get pods -n monitoring
  }

echo -e "${GREEN}✅ Prometheus instalado${NC}"

echo ""
echo "========================================="
echo "Passo 3: Instalar kube-state-metrics"
echo "========================================="
echo ""

echo -e "${BLUE}📦 Aplicando manifestos do kube-state-metrics...${NC}"
kubectl apply -f monitoring/exporters/kube-state-metrics.yaml

echo ""
echo -e "${BLUE}⏳ Aguardando kube-state-metrics estar pronto...${NC}"
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=kube-state-metrics \
  --timeout=90s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando kube-state-metrics${NC}"
  }

echo -e "${GREEN}✅ kube-state-metrics instalado${NC}"

echo ""
echo "========================================="
echo "Passo 4: Instalar PostgreSQL Exporter"
echo "========================================="
echo ""

echo -e "${BLUE}📦 Aplicando manifestos do PostgreSQL Exporter...${NC}"
kubectl apply -f monitoring/exporters/postgres-exporter.yaml

echo ""
echo -e "${BLUE}⏳ Aguardando PostgreSQL Exporter estar pronto...${NC}"
kubectl wait --namespace fluxo-caixa \
  --for=condition=ready pod \
  --selector=app=postgres-exporter \
  --timeout=90s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando PostgreSQL Exporter${NC}"
  }

echo -e "${GREEN}✅ PostgreSQL Exporter instalado${NC}"

echo ""
echo "========================================="
echo "Passo 5: Atualizar Aplicação com Métricas"
echo "========================================="
echo ""

echo -e "${BLUE}🔄 Atualizando deployment da aplicação...${NC}"

# Verificar se deployment existe
if kubectl get deployment fluxo-caixa-app -n fluxo-caixa &> /dev/null; then
    # Adicionar annotations ao deployment existente
    kubectl patch deployment fluxo-caixa-app -n fluxo-caixa -p '
{
  "spec": {
    "template": {
      "metadata": {
        "annotations": {
          "prometheus.io/scrape": "true",
          "prometheus.io/port": "3000",
          "prometheus.io/path": "/metrics"
        }
      }
    }
  }
}'
    echo -e "${GREEN}✅ Deployment atualizado com annotations Prometheus${NC}"
    
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
    echo "A aplicação precisa ser reconstruída com as métricas Prometheus."
    echo ""
    echo "Execute:"
    echo "  cd app/"
    echo "  docker build -t phfldocker/fluxo-caixa-app:v1.1 ."
    echo "  docker push phfldocker/fluxo-caixa-app:v1.1"
    echo ""
    echo "Depois atualize a imagem:"
    echo "  kubectl set image deployment/fluxo-caixa-app app=phfldocker/fluxo-caixa-app:v1.1 -n fluxo-caixa"
    echo ""
else
    echo -e "${YELLOW}⚠️  Deployment não encontrado${NC}"
fi

echo ""
echo "========================================="
echo "Passo 6: Instalar Grafana"
echo "========================================="
echo ""

echo -e "${BLUE}📦 Aplicando manifestos do Grafana...${NC}"
kubectl apply -f monitoring/grafana/

echo ""
echo -e "${BLUE}⏳ Aguardando Grafana estar pronto...${NC}"
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=grafana \
  --timeout=120s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando Grafana${NC}"
    echo "Verificando status:"
    kubectl get pods -n monitoring
  }

echo -e "${GREEN}✅ Grafana instalado${NC}"

echo ""
echo "========================================="
echo "Passo 7: Configurar Acesso"
echo "========================================="
echo ""

# Obter IP do Grafana (LoadBalancer)
echo -e "${BLUE}🔍 Obtendo IP do Grafana...${NC}"
sleep 10

GRAFANA_IP=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$GRAFANA_IP" ] && [ "$GRAFANA_IP" != "null" ]; then
    echo "IP do Grafana: $GRAFANA_IP"
    
    # Atualizar /etc/hosts
    echo -e "${BLUE}📝 Atualizando /etc/hosts...${NC}"
    sudo sed -i '/grafana.local/d' /etc/hosts
    echo "$GRAFANA_IP  grafana.local" | sudo tee -a /etc/hosts
    
    echo -e "${GREEN}✅ /etc/hosts atualizado${NC}"
else
    echo -e "${YELLOW}⚠️  IP do LoadBalancer não atribuído ainda${NC}"
    echo "Aguarde alguns segundos e execute:"
    echo "  kubectl get service grafana -n monitoring"
fi

echo ""
echo "========================================="
echo "✅ Instalação Concluída!"
echo "========================================="
echo ""

# Mostrar status
echo -e "${BLUE}📊 Status dos Serviços:${NC}"
echo ""
kubectl get pods -n monitoring
echo ""
kubectl get pods -n fluxo-caixa -l app=postgres-exporter
echo ""

echo -e "${BLUE}🌐 Serviços Expostos:${NC}"
echo ""
kubectl get service -n monitoring
echo ""

# Informações de acesso
echo "========================================="
echo "📝 Informações de Acesso"
echo "========================================="
echo ""

if [ -n "$GRAFANA_IP" ] && [ "$GRAFANA_IP" != "null" ]; then
    echo -e "${GREEN}Grafana:${NC}"
    echo "  URL: http://grafana.local"
    echo "  IP: $GRAFANA_IP"
    echo "  Login: admin"
    echo "  Senha: admin123"
    echo ""
fi

echo -e "${GREEN}Prometheus:${NC}"
echo "  URL (port-forward): kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "  Acesse: http://localhost:9090"
echo ""

echo "========================================="
echo "📚 Próximos Passos"
echo "========================================="
echo ""
echo "1. Acessar Grafana: http://grafana.local"
echo ""
echo "2. Importar dashboards da comunidade:"
echo "   • Kubernetes Cluster: ID 7249"
echo "   • Node Exporter: ID 1860"
echo "   • PostgreSQL: ID 9628"
echo "   • MetalLB: ID 14127"
echo ""
echo "3. Explorar métricas no Prometheus:"
echo "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   Acesse: http://localhost:9090"
echo ""
echo "4. Verificar métricas da aplicação:"
echo "   curl http://fluxo-caixa.local/metrics"
echo ""
echo "5. Ver documentação completa:"
echo "   cat docs/monitoring.md"
echo ""

echo "========================================="
echo "🔧 Comandos Úteis"
echo "========================================="
echo ""
echo "# Ver logs do Prometheus"
echo "kubectl logs -n monitoring -l app=prometheus -f"
echo ""
echo "# Ver logs do Grafana"
echo "kubectl logs -n monitoring -l app=grafana -f"
echo ""
echo "# Reiniciar Prometheus (reload config)"
echo "kubectl rollout restart deployment prometheus -n monitoring"
echo ""
echo "# Acessar Prometheus via port-forward"
echo "kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo ""
echo "# Testar métricas da aplicação"
echo "curl http://fluxo-caixa.local/metrics"
echo ""
echo "# Ver targets do Prometheus"
echo "kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "# Acesse: http://localhost:9090/targets"
echo ""

