#!/bin/bash

# ============================================
# Script de Configuração do NFS Storage Server
# ============================================
# Executar na VM NFS (10.0.2.17)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "🗄️  Configuração do NFS Storage Server"
echo "========================================="
echo ""

# Verificar se é root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Não execute como root. Use seu usuário normal.${NC}"
    echo "O script usará sudo quando necessário."
    exit 1
fi

# Atualizar sistema
echo -e "${BLUE}📦 Atualizando sistema...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

# Instalar NFS Server
echo ""
echo -e "${BLUE}📦 Instalando NFS Server...${NC}"
sudo apt-get install -y nfs-kernel-server nfs-common tree

# Criar estrutura de diretórios
echo ""
echo -e "${BLUE}📁 Criando estrutura de diretórios...${NC}"
sudo mkdir -p /srv/nfs/k8s/{monitoring,logs,backups,data}
sudo mkdir -p /srv/nfs/k8s/monitoring/{prometheus,grafana}
sudo mkdir -p /srv/nfs/k8s/backups/{postgres,app}
sudo mkdir -p /srv/nfs/k8s/logs/{application,system}

# Configurar permissões
echo -e "${BLUE}🔐 Configurando permissões...${NC}"
sudo chown -R nobody:nogroup /srv/nfs/k8s
sudo chmod -R 777 /srv/nfs/k8s

# Configurar exports
echo ""
echo -e "${BLUE}📝 Configurando /etc/exports...${NC}"
cat <<EOF | sudo tee /etc/exports
# Kubernetes Storage
# Permite acesso de toda a rede 10.0.0.0/16
/srv/nfs/k8s 10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash,insecure)
EOF

# Aplicar configuração
echo ""
echo -e "${BLUE}🔄 Aplicando configuração...${NC}"
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# Configurar firewall (se UFW estiver ativo)
if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    echo ""
    echo -e "${BLUE}🔥 Configurando firewall...${NC}"
    sudo ufw allow from 10.0.0.0/16 to any port nfs
    sudo ufw allow from 10.0.0.0/16 to any port 111
    sudo ufw allow from 10.0.0.0/16 to any port 2049
    sudo ufw allow 22/tcp
    echo -e "${GREEN}✅ Firewall configurado${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  UFW não está ativo. Considere habilitar:${NC}"
    echo "   sudo ufw enable"
    echo "   sudo ufw allow from 10.0.0.0/16 to any port 2049"
fi

# Criar script de backup
echo ""
echo -e "${BLUE}💾 Criando script de backup...${NC}"
cat <<'BACKUP_SCRIPT' | sudo tee /usr/local/bin/backup-nfs.sh
#!/bin/bash
BACKUP_DIR="/backup/nfs"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/nfs-k8s-$DATE.tar.gz /srv/nfs/k8s 2>/dev/null
ls -t $BACKUP_DIR/nfs-k8s-*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
echo "$(date): Backup concluído - $BACKUP_DIR/nfs-k8s-$DATE.tar.gz" >> /var/log/nfs-backup.log
BACKUP_SCRIPT

sudo chmod +x /usr/local/bin/backup-nfs.sh

echo -e "${GREEN}✅ Script de backup criado: /usr/local/bin/backup-nfs.sh${NC}"
echo ""
echo -e "${YELLOW}Para agendar backup diário às 2h:${NC}"
echo "   crontab -e"
echo "   # Adicionar: 0 2 * * * /usr/local/bin/backup-nfs.sh"

# Criar script de monitoramento
echo ""
echo -e "${BLUE}📊 Criando script de monitoramento...${NC}"
cat <<'MONITOR_SCRIPT' | sudo tee /usr/local/bin/monitor-nfs.sh
#!/bin/bash
echo "========================================="
echo "📊 Status do NFS Storage"
echo "========================================="
echo ""
echo "🗄️  Serviço NFS:"
sudo systemctl status nfs-kernel-server --no-pager | head -5
echo ""
echo "💾 Espaço em disco:"
df -h /srv/nfs/k8s
echo ""
echo "📁 Uso por diretório:"
du -sh /srv/nfs/k8s/* 2>/dev/null
echo ""
echo "🔌 Montagens ativas:"
sudo showmount -a
echo ""
echo "📊 Exports configurados:"
sudo exportfs -v
MONITOR_SCRIPT

sudo chmod +x /usr/local/bin/monitor-nfs.sh

echo -e "${GREEN}✅ Script de monitoramento criado: /usr/local/bin/monitor-nfs.sh${NC}"

# Verificar status
echo ""
echo "========================================="
echo -e "${GREEN}✅ Configuração Concluída!${NC}"
echo "========================================="
echo ""

echo -e "${BLUE}📊 Status do NFS Server:${NC}"
sudo systemctl status nfs-kernel-server --no-pager | head -5
echo ""

echo -e "${BLUE}📁 Exports configurados:${NC}"
sudo exportfs -v
echo ""

echo -e "${BLUE}💾 Espaço em disco:${NC}"
df -h /srv/nfs/k8s
echo ""

echo -e "${BLUE}📂 Estrutura de diretórios:${NC}"
tree -L 3 /srv/nfs/k8s
echo ""

# Informações de conexão
MY_IP=$(hostname -I | awk '{print $1}')

echo "========================================="
echo "🎯 Informações de Conexão"
echo "========================================="
echo ""
echo "IP do servidor NFS: $MY_IP"
echo "Path: /srv/nfs/k8s"
echo "Rede permitida: 10.0.0.0/16"
echo ""

echo "========================================="
echo "🧪 Teste de Montagem"
echo "========================================="
echo ""
echo "Execute de um node do cluster:"
echo ""
echo "  # Instalar cliente NFS"
echo "  sudo apt-get install -y nfs-common"
echo ""
echo "  # Criar ponto de montagem"
echo "  sudo mkdir -p /mnt/nfs-test"
echo ""
echo "  # Montar"
echo "  sudo mount -t nfs $MY_IP:/srv/nfs/k8s /mnt/nfs-test"
echo ""
echo "  # Testar escrita"
echo "  echo 'teste' | sudo tee /mnt/nfs-test/teste.txt"
echo ""
echo "  # Verificar"
echo "  cat /mnt/nfs-test/teste.txt"
echo ""
echo "  # Desmontar"
echo "  sudo umount /mnt/nfs-test"
echo ""

echo "========================================="
echo "📚 Próximos Passos"
echo "========================================="
echo ""
echo "1. Testar montagem NFS de um node (comandos acima)"
echo ""
echo "2. Instalar NFS Provisioner no Kubernetes:"
echo "   cd ~/projeto-migra/fluxo-caixa-homelab"
echo "   kubectl apply -f k8s/nfs-provisioner/"
echo ""
echo "3. Verificar StorageClass:"
echo "   kubectl get storageclass"
echo ""
echo "4. Atualizar PVCs do monitoramento:"
echo "   kubectl apply -f monitoring/prometheus/03-pvc-nfs.yaml"
echo "   kubectl apply -f monitoring/grafana/02-pvc-nfs.yaml"
echo ""
echo "5. Monitorar NFS:"
echo "   /usr/local/bin/monitor-nfs.sh"
echo ""

echo "========================================="
echo "🔧 Comandos Úteis"
echo "========================================="
echo ""
echo "# Ver status do NFS"
echo "sudo systemctl status nfs-kernel-server"
echo ""
echo "# Ver montagens ativas"
echo "sudo showmount -a"
echo ""
echo "# Ver logs"
echo "sudo journalctl -u nfs-kernel-server -f"
echo ""
echo "# Monitorar uso"
echo "/usr/local/bin/monitor-nfs.sh"
echo ""
echo "# Fazer backup manual"
echo "/usr/local/bin/backup-nfs.sh"
echo ""

