# Setup de Storage NFS Dedicado

## Visão Geral

Configuração de uma VM dedicada para servir storage NFS para o cluster Kubernetes, resolvendo limitações de espaço nos nodes e centralizando dados de monitoramento, logs e backups.

---

## 📋 Especificações da VM

### Recursos Recomendados

| Recurso | Mínimo | Recomendado | Produção |
|---------|--------|-------------|----------|
| **CPU** | 1 vCPU | 2 vCPUs | 4 vCPUs |
| **RAM** | 1GB | 2GB | 4GB |
| **Disco** | 50GB | 100GB | 200GB+ |
| **OS** | Ubuntu 22.04 | Ubuntu 22.04 | Ubuntu 22.04 |
| **Rede** | 10.0.2.0/23 | 10.0.2.0/23 | 10.0.2.0/23 |

### Para Este Projeto

- **CPU**: 2 vCPUs
- **RAM**: 2GB
- **Disco**: 100GB (SSD se possível)
- **OS**: Ubuntu Server 22.04 LTS
- **IP**: 10.0.2.17 (ou outro disponível na rede)
- **Hostname**: nfs-storage

---

## 🚀 Passo 1: Criar VM no Proxmox

### Via Interface Web

1. **Criar VM:**
   - Proxmox → Create VM
   - **VM ID**: 300 (ou próximo disponível)
   - **Name**: nfs-storage
   - **ISO**: Ubuntu Server 22.04 LTS

2. **System:**
   - BIOS: Default (SeaBIOS)
   - Machine: q35
   - SCSI Controller: VirtIO SCSI

3. **Disks:**
   - Bus/Device: SCSI 0
   - Storage: local-lvm (ou seu storage)
   - Disk size: 100 GB
   - Cache: Write back
   - Discard: ✓ (se SSD)

4. **CPU:**
   - Sockets: 1
   - Cores: 2
   - Type: host

5. **Memory:**
   - Memory: 2048 MB
   - Minimum: 1024 MB
   - Ballooning: ✓

6. **Network:**
   - Bridge: vmbr0
   - Model: VirtIO
   - Firewall: ✓

7. **Confirm** e **Start VM**

### Instalação do Ubuntu

1. **Idioma**: English
2. **Keyboard**: Brazilian (ou seu layout)
3. **Network**: 
   - Configurar IP estático: **10.0.2.17/23**
   - Gateway: 10.0.2.1 (ou seu gateway)
   - DNS: 8.8.8.8, 8.8.4.4
4. **Storage**: Use entire disk
5. **Profile**:
   - Name: admin
   - Server name: nfs-storage
   - Username: admin
   - Password: [sua senha]
6. **SSH**: Install OpenSSH server ✓
7. **Featured Server Snaps**: Nenhum
8. **Install** e aguardar
9. **Reboot**

---

## 🔧 Passo 2: Configurar VM NFS

### Script Automatizado (Recomendado)

Faça SSH na VM e execute:

```bash
ssh admin@10.0.2.17
```

Depois execute este script:

```bash
#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "🗄️  Configuração do NFS Storage Server"
echo "========================================="
echo ""

# Atualizar sistema
echo -e "${BLUE}📦 Atualizando sistema...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

# Instalar NFS Server
echo ""
echo -e "${BLUE}📦 Instalando NFS Server...${NC}"
sudo apt-get install -y nfs-kernel-server nfs-common

# Criar estrutura de diretórios
echo ""
echo -e "${BLUE}📁 Criando estrutura de diretórios...${NC}"
sudo mkdir -p /srv/nfs/k8s/{monitoring,logs,backups,data}
sudo mkdir -p /srv/nfs/k8s/monitoring/{prometheus,grafana}
sudo mkdir -p /srv/nfs/k8s/backups/{postgres,app}

# Configurar permissões
echo -e "${BLUE}🔐 Configurando permissões...${NC}"
sudo chown -R nobody:nogroup /srv/nfs/k8s
sudo chmod -R 777 /srv/nfs/k8s

# Configurar exports
echo ""
echo -e "${BLUE}📝 Configurando /etc/exports...${NC}"
cat <<EOF | sudo tee /etc/exports
# Kubernetes Storage
/srv/nfs/k8s 10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash,insecure)
EOF

# Aplicar configuração
echo ""
echo -e "${BLUE}🔄 Aplicando configuração...${NC}"
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# Configurar firewall (se UFW estiver ativo)
if sudo ufw status | grep -q "Status: active"; then
    echo ""
    echo -e "${BLUE}🔥 Configurando firewall...${NC}"
    sudo ufw allow from 10.0.0.0/16 to any port nfs
    sudo ufw allow from 10.0.0.0/16 to any port 111
    sudo ufw allow from 10.0.0.0/16 to any port 2049
fi

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
tree -L 3 /srv/nfs/k8s || ls -lR /srv/nfs/k8s
echo ""

echo "========================================="
echo "🎯 Próximos Passos"
echo "========================================="
echo ""
echo "1. Testar montagem NFS de outro node:"
echo "   sudo mount -t nfs 10.0.2.17:/srv/nfs/k8s /mnt"
echo ""
echo "2. Instalar NFS Provisioner no Kubernetes"
echo "   (Ver: docs/setup-nfs-storage.md - Passo 3)"
echo ""
echo "3. Criar PVCs usando StorageClass 'nfs-client'"
echo ""
echo "IP do servidor NFS: $(hostname -I | awk '{print $1}')"
echo "Path: /srv/nfs/k8s"
echo ""
```

Salve como `setup-nfs.sh`, dê permissão e execute:

```bash
chmod +x setup-nfs.sh
./setup-nfs.sh
```

---

## 🧪 Passo 3: Testar NFS de um Node

Antes de configurar no Kubernetes, teste se o NFS funciona:

```bash
# De qualquer node do cluster
ssh usuario@10.0.3.52  # Ou outro node

# Instalar cliente NFS
sudo apt-get update
sudo apt-get install -y nfs-common

# Criar ponto de montagem
sudo mkdir -p /mnt/nfs-test

# Montar NFS
sudo mount -t nfs 10.0.2.17:/srv/nfs/k8s /mnt/nfs-test

# Testar escrita
echo "teste" | sudo tee /mnt/nfs-test/teste.txt

# Verificar
ls -la /mnt/nfs-test/
cat /mnt/nfs-test/teste.txt

# Desmontar
sudo umount /mnt/nfs-test

# Se funcionou, está pronto!
```

---

## ☸️ Passo 4: Instalar NFS Provisioner no Kubernetes

### Opção A: Via Helm (Recomendado)

```bash
# No seu desktop (onde tem kubectl)

# Instalar Helm (se não tiver)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Adicionar repositório
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm repo update

# Instalar NFS Provisioner
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=10.0.2.17 \
  --set nfs.path=/srv/nfs/k8s \
  --set storageClass.name=nfs-client \
  --set storageClass.defaultClass=false \
  --set storageClass.reclaimPolicy=Retain

# Verificar
kubectl get pods -n kube-system | grep nfs
kubectl get storageclass
```

### Opção B: Via Manifestos YAML

Se não quiser usar Helm:

```bash
cd ~/projeto-migra/fluxo-caixa-homelab

# Criar manifestos
mkdir -p k8s/nfs-provisioner

cat > k8s/nfs-provisioner/01-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

cat > k8s/nfs-provisioner/02-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
  labels:
    app: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: nfs-storage/nfs-client
            - name: NFS_SERVER
              value: 10.0.2.17
            - name: NFS_PATH
              value: /srv/nfs/k8s
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.0.2.17
            path: /srv/nfs/k8s
EOF

cat > k8s/nfs-provisioner/03-storageclass.yaml << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: nfs-storage/nfs-client
parameters:
  archiveOnDelete: "true"
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Aplicar
kubectl apply -f k8s/nfs-provisioner/

# Verificar
kubectl get pods -n kube-system | grep nfs
kubectl get storageclass
```

---

## ✅ Passo 5: Testar StorageClass

Criar um PVC de teste:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

# Verificar
kubectl get pvc test-nfs-pvc

# Deve mostrar STATUS: Bound

# Criar pod de teste
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-nfs-pod
  namespace: default
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo 'Hello from NFS!' > /mnt/test.txt && sleep 3600"]
      volumeMounts:
        - name: nfs-volume
          mountPath: /mnt
  volumes:
    - name: nfs-volume
      persistentVolumeClaim:
        claimName: test-nfs-pvc
EOF

# Aguardar pod estar Running
kubectl wait --for=condition=ready pod/test-nfs-pod --timeout=60s

# Verificar arquivo no servidor NFS
ssh admin@10.0.2.17 "find /srv/nfs/k8s -name 'test.txt' -exec cat {} \;"

# Deve mostrar: Hello from NFS!

# Limpar teste
kubectl delete pod test-nfs-pod
kubectl delete pvc test-nfs-pvc
```

Se funcionou, está pronto! ✅

---

## 📊 Passo 6: Atualizar Monitoramento para Usar NFS

Agora que o NFS está funcionando, atualizar Prometheus e Grafana:

```bash
cd ~/projeto-migra/fluxo-caixa-homelab

# Atualizar PVCs para usar nfs-client
cat > monitoring/prometheus/03-pvc-nfs.yaml << 'EOF'
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
      storage: 20Gi  # Agora podemos usar mais espaço!
EOF

cat > monitoring/grafana/02-pvc-nfs.yaml << 'EOF'
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
      storage: 10Gi  # Agora podemos usar mais espaço!
EOF

# Aplicar
kubectl apply -f monitoring/prometheus/03-pvc-nfs.yaml
kubectl apply -f monitoring/grafana/02-pvc-nfs.yaml

# Verificar
kubectl get pvc -n monitoring

# Deletar pods para recriar com novos volumes
kubectl delete pod -n monitoring -l app=prometheus
kubectl delete pod -n monitoring -l app=grafana

# Aguardar
kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=prometheus \
  --timeout=120s

kubectl wait --namespace monitoring \
  --for=condition=ready pod \
  --selector=app=grafana \
  --timeout=120s

# Verificar
kubectl get pods -n monitoring
```

---

## 🔍 Monitoramento do NFS Server

### Verificar Uso de Espaço

```bash
# No servidor NFS
ssh admin@10.0.2.17

# Espaço total
df -h /srv/nfs/k8s

# Uso por diretório
du -sh /srv/nfs/k8s/*

# Uso detalhado
du -h --max-depth=2 /srv/nfs/k8s | sort -h
```

### Verificar Montagens Ativas

```bash
# No servidor NFS
sudo showmount -a

# Deve mostrar os nodes que estão montando
```

### Logs do NFS

```bash
# No servidor NFS
sudo journalctl -u nfs-kernel-server -f

# Ver últimas 50 linhas
sudo journalctl -u nfs-kernel-server -n 50
```

---

## 🔐 Segurança

### Firewall (Recomendado)

```bash
# No servidor NFS
sudo ufw enable
sudo ufw allow from 10.0.0.0/16 to any port 2049
sudo ufw allow from 10.0.0.0/16 to any port 111
sudo ufw allow 22/tcp  # SSH
sudo ufw status
```

### Exports Seguros

Já configurado no script, mas para referência:

```bash
# /etc/exports
/srv/nfs/k8s 10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash,insecure)
```

**Explicação:**
- `10.0.0.0/16` - Apenas rede do cluster
- `rw` - Read/Write
- `sync` - Sync writes (mais seguro)
- `no_subtree_check` - Performance
- `no_root_squash` - Kubernetes precisa disso
- `insecure` - Permite portas >1024

---

## 💾 Backup do NFS Server

### Script de Backup

```bash
#!/bin/bash
# Executar no servidor NFS

BACKUP_DIR="/backup/nfs"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup completo
tar -czf $BACKUP_DIR/nfs-k8s-$DATE.tar.gz /srv/nfs/k8s

# Manter apenas últimos 7 backups
ls -t $BACKUP_DIR/nfs-k8s-*.tar.gz | tail -n +8 | xargs rm -f

echo "Backup concluído: $BACKUP_DIR/nfs-k8s-$DATE.tar.gz"
```

### Agendar Backup (Cron)

```bash
# No servidor NFS
crontab -e

# Adicionar linha (backup diário às 2h)
0 2 * * * /usr/local/bin/backup-nfs.sh
```

---

## 🚨 Troubleshooting

### NFS não monta no Kubernetes

```bash
# Verificar se NFS está rodando
ssh admin@10.0.2.17 "sudo systemctl status nfs-kernel-server"

# Verificar exports
ssh admin@10.0.2.17 "sudo exportfs -v"

# Testar montagem manual de um node
ssh usuario@10.0.3.52 "sudo mount -t nfs 10.0.2.17:/srv/nfs/k8s /mnt"
```

### PVC fica Pending

```bash
# Ver eventos
kubectl describe pvc <pvc-name> -n monitoring

# Ver logs do provisioner
kubectl logs -n kube-system -l app=nfs-client-provisioner
```

### Performance Lenta

```bash
# Verificar latência de rede
ping -c 10 10.0.2.17

# Verificar I/O do disco no servidor NFS
ssh admin@10.0.2.17 "iostat -x 1 10"

# Considerar:
# - Usar SSD ao invés de HDD
# - Aumentar RAM da VM
# - Usar rede 10Gbps se disponível
```

---

## 📚 Referências

- [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [Ubuntu NFS Server Setup](https://ubuntu.com/server/docs/service-nfs)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

## ✅ Checklist Final

- [ ] VM criada no Proxmox (100GB, 2vCPU, 2GB RAM)
- [ ] Ubuntu Server 22.04 instalado
- [ ] IP estático configurado (10.0.2.17)
- [ ] NFS Server instalado e configurado
- [ ] Exports configurados (/srv/nfs/k8s)
- [ ] Firewall configurado
- [ ] Teste de montagem manual funcionando
- [ ] NFS Provisioner instalado no Kubernetes
- [ ] StorageClass 'nfs-client' criado
- [ ] PVC de teste funcionando
- [ ] Prometheus PVC usando NFS
- [ ] Grafana PVC usando NFS
- [ ] Pods de monitoramento Running
- [ ] Backup configurado

---

Tudo pronto! Agora você tem um storage centralizado e escalável! 🎉

