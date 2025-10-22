#!/bin/bash

# ============================================
# Script de Migração do Monitoramento para NFS
# ============================================
# Migra Prometheus e Grafana de storage local para NFS

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "🔄 Migração do Monitoramento para NFS"
echo "========================================="
echo ""

# Verificar se namespace existe
if ! kubectl get namespace monitoring &>/dev/null; then
    echo -e "${RED}❌ Namespace 'monitoring' não existe!${NC}"
    echo "Execute primeiro: ./scripts/install-monitoring.sh"
    exit 1
fi

# Verificar se StorageClass NFS existe
if ! kubectl get storageclass nfs-client &>/dev/null; then
    echo -e "${RED}❌ StorageClass 'nfs-client' não existe!${NC}"
    echo ""
    echo "Instale primeiro o NFS Provisioner:"
    echo "  kubectl apply -f k8s/nfs-provisioner/"
    echo ""
    exit 1
fi

echo -e "${BLUE}📊 Status Atual:${NC}"
kubectl get pods -n monitoring
echo ""
kubectl get pvc -n monitoring
echo ""

echo -e "${YELLOW}⚠️  ATENÇÃO: Esta operação vai:${NC}"
echo "  1. Fazer backup dos dados atuais (opcional)"
echo "  2. Deletar pods de Prometheus e Grafana"
echo "  3. Deletar PVCs antigos (local-path)"
echo "  4. Criar novos PVCs (nfs-client)"
echo "  5. Recriar pods (dados serão perdidos se não fizer backup)"
echo ""
echo -e "${RED}⚠️  DADOS ATUAIS SERÃO PERDIDOS se não fizer backup!${NC}"
echo ""
echo -e "${YELLOW}Deseja fazer backup dos dados antes? (s/N):${NC}"
read -r BACKUP_CHOICE

if [[ "$BACKUP_CHOICE" =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${BLUE}💾 Fazendo backup...${NC}"
    
    # Criar diretório de backup
    BACKUP_DIR="./backup-monitoring-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup do Prometheus
    echo -e "${YELLOW}Backup do Prometheus...${NC}"
    PROMETHEUS_POD=$(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$PROMETHEUS_POD" ]; then
        kubectl exec -n monitoring "$PROMETHEUS_POD" -- tar czf /tmp/prometheus-backup.tar.gz -C /prometheus . 2>/dev/null || true
        kubectl cp "monitoring/$PROMETHEUS_POD:/tmp/prometheus-backup.tar.gz" "$BACKUP_DIR/prometheus-backup.tar.gz" 2>/dev/null || true
        echo -e "${GREEN}✅ Backup do Prometheus: $BACKUP_DIR/prometheus-backup.tar.gz${NC}"
    fi
    
    # Backup do Grafana
    echo -e "${YELLOW}Backup do Grafana...${NC}"
    GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$GRAFANA_POD" ]; then
        kubectl exec -n monitoring "$GRAFANA_POD" -- tar czf /tmp/grafana-backup.tar.gz -C /var/lib/grafana . 2>/dev/null || true
        kubectl cp "monitoring/$GRAFANA_POD:/tmp/grafana-backup.tar.gz" "$BACKUP_DIR/grafana-backup.tar.gz" 2>/dev/null || true
        echo -e "${GREEN}✅ Backup do Grafana: $BACKUP_DIR/grafana-backup.tar.gz${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Backups salvos em: $BACKUP_DIR${NC}"
    echo ""
else
    echo ""
    echo -e "${YELLOW}⚠️  Pulando backup. Dados atuais serão perdidos!${NC}"
    echo ""
fi

echo -e "${YELLOW}Continuar com a migração? (s/N):${NC}"
read -r CONTINUE

if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

echo ""
echo "========================================="
echo "🔄 Iniciando Migração"
echo "========================================="
echo ""

# 1. Deletar pods
echo -e "${BLUE}1/5 Deletando pods...${NC}"
kubectl delete pod -n monitoring -l app=prometheus --ignore-not-found=true
kubectl delete pod -n monitoring -l app=grafana --ignore-not-found=true

# Aguardar pods terminarem
echo -e "${YELLOW}Aguardando pods terminarem...${NC}"
kubectl wait --for=delete pod -l app=prometheus -n monitoring --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app=grafana -n monitoring --timeout=60s 2>/dev/null || true

echo -e "${GREEN}✅ Pods deletados${NC}"
echo ""

# 2. Deletar PVCs antigos
echo -e "${BLUE}2/5 Deletando PVCs antigos...${NC}"
kubectl delete pvc prometheus-pvc -n monitoring --ignore-not-found=true
kubectl delete pvc grafana-pvc -n monitoring --ignore-not-found=true

# Aguardar PVCs serem deletados
echo -e "${YELLOW}Aguardando PVCs serem deletados...${NC}"
sleep 5

echo -e "${GREEN}✅ PVCs antigos deletados${NC}"
echo ""

# 3. Criar novos PVCs com NFS
echo -e "${BLUE}3/5 Criando novos PVCs com NFS...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: monitoring
  labels:
    app: prometheus
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
  labels:
    app: grafana
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
EOF

echo -e "${GREEN}✅ Novos PVCs criados${NC}"
echo ""

# 4. Aguardar PVCs ficarem Bound
echo -e "${BLUE}4/5 Aguardando PVCs ficarem Bound...${NC}"

kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/prometheus-pvc -n monitoring --timeout=60s || {
    echo -e "${RED}❌ Timeout aguardando prometheus-pvc${NC}"
    kubectl describe pvc prometheus-pvc -n monitoring
    exit 1
}

kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/grafana-pvc -n monitoring --timeout=60s || {
    echo -e "${RED}❌ Timeout aguardando grafana-pvc${NC}"
    kubectl describe pvc grafana-pvc -n monitoring
    exit 1
}

echo -e "${GREEN}✅ PVCs Bound${NC}"
echo ""

# 5. Recriar pods (Deployments vão recriar automaticamente)
echo -e "${BLUE}5/5 Recriando pods...${NC}"

# Forçar recriação fazendo rollout restart
kubectl rollout restart deployment prometheus -n monitoring 2>/dev/null || true
kubectl rollout restart deployment grafana -n monitoring 2>/dev/null || true

echo -e "${YELLOW}Aguardando pods ficarem Running...${NC}"

kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=prometheus \
  --timeout=120s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando Prometheus${NC}"
    echo "Verificando status..."
    kubectl get pods -n monitoring -l app=prometheus
    kubectl describe pod -n monitoring -l app=prometheus | tail -20
  }

kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=grafana \
  --timeout=120s || {
    echo -e "${YELLOW}⚠️  Timeout aguardando Grafana${NC}"
    echo "Verificando status..."
    kubectl get pods -n monitoring -l app=grafana
    kubectl describe pod -n monitoring -l app=grafana | tail -20
  }

echo ""
echo "========================================="
echo -e "${GREEN}✅ Migração Concluída!${NC}"
echo "========================================="
echo ""

echo -e "${BLUE}📊 Status Final:${NC}"
kubectl get pods -n monitoring
echo ""
kubectl get pvc -n monitoring
echo ""

# Verificar no servidor NFS
echo -e "${BLUE}📁 Verificando no servidor NFS:${NC}"
echo "Execute no servidor NFS (10.0.2.17):"
echo "  ssh admin@10.0.2.17 'ls -lh /srv/nfs/k8s/'"
echo ""

# Testar acesso
echo -e "${BLUE}🧪 Testando acesso:${NC}"
echo ""

GRAFANA_IP=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$GRAFANA_IP" ] && [ "$GRAFANA_IP" != "null" ]; then
    echo "Grafana: http://grafana.local"
    echo "  IP: $GRAFANA_IP"
    echo "  Login: admin"
    echo "  Senha: admin123"
    echo ""
    
    # Atualizar /etc/hosts se necessário
    if ! grep -q "grafana.local" /etc/hosts 2>/dev/null; then
        echo "Atualizando /etc/hosts..."
        echo "$GRAFANA_IP  grafana.local" | sudo tee -a /etc/hosts
    fi
    
    echo "Testando..."
    if curl -s http://grafana.local > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Grafana acessível!${NC}"
    else
        echo -e "${YELLOW}⚠️  Aguarde alguns segundos e tente: curl http://grafana.local${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  IP do Grafana não disponível ainda${NC}"
    echo "Aguarde e execute: kubectl get service grafana -n monitoring"
fi

echo ""
echo "========================================="
echo "📚 Próximos Passos"
echo "========================================="
echo ""
echo "1. Acessar Grafana: http://grafana.local"
echo "2. Importar dashboards (IDs: 7249, 1860, 9628, 14127)"
echo "3. Verificar métricas do Prometheus"
echo "4. Monitorar uso no NFS:"
echo "   ssh admin@10.0.2.17 '/usr/local/bin/monitor-nfs.sh'"
echo ""

if [ -d "$BACKUP_DIR" ]; then
    echo "========================================="
    echo "💾 Restaurar Backup (Opcional)"
    echo "========================================="
    echo ""
    echo "Se quiser restaurar os dados antigos:"
    echo ""
    echo "# Prometheus"
    echo "PROMETHEUS_POD=\$(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}')"
    echo "kubectl cp $BACKUP_DIR/prometheus-backup.tar.gz monitoring/\$PROMETHEUS_POD:/tmp/"
    echo "kubectl exec -n monitoring \$PROMETHEUS_POD -- tar xzf /tmp/prometheus-backup.tar.gz -C /prometheus"
    echo "kubectl delete pod -n monitoring \$PROMETHEUS_POD"
    echo ""
    echo "# Grafana"
    echo "GRAFANA_POD=\$(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}')"
    echo "kubectl cp $BACKUP_DIR/grafana-backup.tar.gz monitoring/\$GRAFANA_POD:/tmp/"
    echo "kubectl exec -n monitoring \$GRAFANA_POD -- tar xzf /tmp/grafana-backup.tar.gz -C /var/lib/grafana"
    echo "kubectl delete pod -n monitoring \$GRAFANA_POD"
    echo ""
fi

echo "========================================="
echo -e "${GREEN}🎉 Migração para NFS Concluída!${NC}"
echo "========================================="

