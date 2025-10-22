# Guia Rápido: Storage NFS

## 🎯 Objetivo

Configurar VM NFS dedicada para storage do cluster Kubernetes.

---

## ⚡ Instalação Rápida (30 minutos)

### Passo 1: Criar VM no Proxmox (10 min)

1. **Criar VM:**
   - Nome: `nfs-storage`
   - CPU: 2 vCPUs
   - RAM: 2GB
   - Disco: 100GB
   - OS: Ubuntu Server 22.04

2. **Configurar rede:**
   - IP estático: `10.0.3.250/23`
   - Gateway: `10.0.2.1`
   - DNS: `8.8.8.8`

3. **Instalar Ubuntu:**
   - Usuário: `admin`
   - Hostname: `nfs-storage`
   - SSH: ✓ Habilitar

---

### Passo 2: Configurar NFS Server (5 min)

```bash
# SSH na VM
ssh admin@10.0.3.250

# Download do script
wget https://raw.githubusercontent.com/paulohenriquelyra/fluxo-caixa-homelab/main/scripts/nfs-server-setup.sh

# Executar
chmod +x nfs-server-setup.sh
./nfs-server-setup.sh
```

**Ou copiar script manualmente:**

```bash
# No seu desktop
cd ~/projeto-migra/fluxo-caixa-homelab
scp scripts/nfs-server-setup.sh admin@10.0.3.250:~/

# Na VM
ssh admin@10.0.3.250
chmod +x nfs-server-setup.sh
./nfs-server-setup.sh
```

---

### Passo 3: Testar NFS (2 min)

```bash
# De um node do cluster
ssh usuario@10.0.3.52

# Instalar cliente
sudo apt-get install -y nfs-common

# Testar montagem
sudo mkdir -p /mnt/nfs-test
sudo mount -t nfs 10.0.3.250:/srv/nfs/k8s /mnt/nfs-test
echo "teste" | sudo tee /mnt/nfs-test/teste.txt
cat /mnt/nfs-test/teste.txt
sudo umount /mnt/nfs-test

# Se funcionou, está OK!
```

---

### Passo 4: Instalar NFS Provisioner no K8s (5 min)

```bash
# No seu desktop
cd ~/projeto-migra/fluxo-caixa-homelab
git pull origin main

# Aplicar manifestos
kubectl apply -f k8s/nfs-provisioner/

# Verificar
kubectl get pods -n kube-system | grep nfs
kubectl get storageclass

# Deve mostrar:
# nfs-client-provisioner-xxx   1/1     Running
# nfs-client                   nfs-storage/nfs-client
```

---

### Passo 5: Testar StorageClass (3 min)

```bash
# Criar PVC de teste
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
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

# Deve mostrar: STATUS: Bound

# Limpar
kubectl delete pvc test-nfs-pvc
```

---

### Passo 6: Instalar Monitoramento com NFS (5 min)

```bash
cd ~/projeto-migra/fluxo-caixa-homelab

# Aplicar PVCs com NFS
kubectl apply -f monitoring/prometheus/03-pvc-nfs.yaml
kubectl apply -f monitoring/grafana/02-pvc-nfs.yaml

# Instalar monitoramento
./scripts/install-monitoring.sh

# Aguardar pods ficarem Running
kubectl get pods -n monitoring -w
```

---

## ✅ Verificação Final

```bash
# 1. NFS Server rodando
ssh admin@10.0.3.250 "sudo systemctl status nfs-kernel-server"

# 2. NFS Provisioner rodando
kubectl get pods -n kube-system | grep nfs

# 3. StorageClass criado
kubectl get storageclass nfs-client

# 4. PVCs Bound
kubectl get pvc -n monitoring

# 5. Pods Running
kubectl get pods -n monitoring

# 6. Grafana acessível
curl http://grafana.local
```

---

## 🔧 Troubleshooting Rápido

### PVC fica Pending

```bash
# Ver eventos
kubectl describe pvc <pvc-name> -n monitoring

# Ver logs do provisioner
kubectl logs -n kube-system -l app=nfs-client-provisioner

# Testar montagem manual
ssh usuario@10.0.3.52 "sudo mount -t nfs 10.0.3.250:/srv/nfs/k8s /mnt"
```

### NFS não monta

```bash
# Verificar NFS Server
ssh admin@10.0.3.250 "sudo systemctl status nfs-kernel-server"

# Verificar exports
ssh admin@10.0.3.250 "sudo exportfs -v"

# Verificar firewall
ssh admin@10.0.3.250 "sudo ufw status"
```

---

## 📚 Documentação Completa

Ver: `docs/setup-nfs-storage.md`

---

## 🎯 Resumo

| Passo | Tempo | Status |
|-------|-------|--------|
| 1. Criar VM | 10 min | [ ] |
| 2. Configurar NFS | 5 min | [ ] |
| 3. Testar NFS | 2 min | [ ] |
| 4. Instalar Provisioner | 5 min | [ ] |
| 5. Testar StorageClass | 3 min | [ ] |
| 6. Instalar Monitoramento | 5 min | [ ] |
| **Total** | **30 min** | |

---

Pronto! Storage NFS configurado e funcionando! 🎉

