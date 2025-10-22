# Informações do Servidor NFS

## 🗄️ Servidor NFS Dedicado

### Informações de Conexão

| Propriedade | Valor |
|-------------|-------|
| **Hostname** | nfs-server01 |
| **IP** | 10.0.2.17 |
| **Rede** | 10.0.2.0/23 |
| **Path NFS** | /srv/nfs/k8s |
| **Porta** | 2049 (NFS) |
| **Protocolo** | NFSv4 |

### Especificações da VM

| Recurso | Valor |
|---------|-------|
| **CPU** | 2 vCPUs |
| **RAM** | 2GB |
| **Disco** | 100GB |
| **OS** | Ubuntu Server 22.04 LTS |
| **Usuário** | admin |

---

## 📁 Estrutura de Diretórios

```
/srv/nfs/k8s/
├── monitoring/
│   ├── prometheus/  (20Gi - métricas do Prometheus)
│   └── grafana/     (10Gi - dashboards e configurações)
├── logs/
│   ├── application/ (logs da aplicação)
│   └── system/      (logs do sistema)
├── backups/
│   ├── postgres/    (backups do PostgreSQL)
│   └── app/         (backups da aplicação)
└── data/
    (reservado para crescimento futuro)
```

---

## 🔌 Exports Configurados

```bash
/srv/nfs/k8s 10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash,insecure)
```

**Permite acesso de:**
- Toda a rede 10.0.0.0/16 (inclui todos os nodes do cluster)

---

## ✅ Comandos de Verificação

### Testar Conectividade

```bash
# Ping
ping -c 3 10.0.2.17

# Verificar porta NFS
nc -zv 10.0.2.17 2049

# Verificar exports
showmount -e 10.0.2.17
```

### Testar Montagem

```bash
# Criar ponto de montagem
sudo mkdir -p /mnt/nfs-test

# Montar
sudo mount -t nfs 10.0.2.17:/srv/nfs/k8s /mnt/nfs-test

# Testar escrita
echo "teste" | sudo tee /mnt/nfs-test/teste.txt

# Verificar
cat /mnt/nfs-test/teste.txt

# Desmontar
sudo umount /mnt/nfs-test
```

---

## 🔧 Acesso SSH

```bash
# SSH no servidor
ssh admin@10.0.2.17

# Monitorar status
/usr/local/bin/monitor-nfs.sh

# Ver logs
sudo journalctl -u nfs-kernel-server -f

# Ver espaço usado
df -h /srv/nfs/k8s
du -sh /srv/nfs/k8s/*
```

---

## 📊 Monitoramento

### Espaço em Disco

```bash
# Via SSH
ssh admin@10.0.2.17 "df -h /srv/nfs/k8s"

# Uso por diretório
ssh admin@10.0.2.17 "du -sh /srv/nfs/k8s/*"
```

### Montagens Ativas

```bash
# Ver quem está montando
ssh admin@10.0.2.17 "sudo showmount -a"
```

### Status do Serviço

```bash
# Status do NFS Server
ssh admin@10.0.2.17 "sudo systemctl status nfs-kernel-server"

# Reiniciar se necessário
ssh admin@10.0.2.17 "sudo systemctl restart nfs-kernel-server"
```

---

## 💾 Backup

### Backup Manual

```bash
# Executar backup
ssh admin@10.0.2.17 "/usr/local/bin/backup-nfs.sh"

# Ver backups
ssh admin@10.0.2.17 "ls -lh /backup/nfs/"
```

### Backup Automático (Cron)

```bash
# Configurar cron
ssh admin@10.0.2.17
crontab -e

# Adicionar linha (backup diário às 2h)
0 2 * * * /usr/local/bin/backup-nfs.sh
```

---

## 🔐 Segurança

### Firewall (UFW)

```bash
# Ver regras
ssh admin@10.0.2.17 "sudo ufw status"

# Regras configuradas:
# - 2049/tcp (NFS) - de 10.0.0.0/16
# - 111/tcp (RPC) - de 10.0.0.0/16
# - 22/tcp (SSH) - de qualquer lugar
```

### Permissões

```bash
# Verificar permissões
ssh admin@10.0.2.17 "ls -la /srv/nfs/k8s"

# Deve mostrar:
# drwxrwxrwx nobody nogroup
```

---

## 🚨 Troubleshooting

### NFS não responde

```bash
# 1. Verificar se VM está ligada
ping 10.0.2.17

# 2. Verificar serviço NFS
ssh admin@10.0.2.17 "sudo systemctl status nfs-kernel-server"

# 3. Reiniciar serviço
ssh admin@10.0.2.17 "sudo systemctl restart nfs-kernel-server"

# 4. Verificar logs
ssh admin@10.0.2.17 "sudo journalctl -u nfs-kernel-server -n 50"
```

### Montagem falha no Kubernetes

```bash
# 1. Verificar NFS Provisioner
kubectl get pods -n kube-system | grep nfs

# 2. Ver logs
kubectl logs -n kube-system -l app=nfs-client-provisioner --tail=50

# 3. Testar montagem manual de um node
ssh usuario@10.0.3.52 "sudo mount -t nfs 10.0.2.17:/srv/nfs/k8s /mnt"
```

### Espaço cheio

```bash
# Ver uso
ssh admin@10.0.2.17 "df -h /srv/nfs/k8s"

# Limpar backups antigos
ssh admin@10.0.2.17 "ls -lht /backup/nfs/ | head -20"

# Ou aumentar disco da VM no Proxmox
```

---

## 📚 Referências

- **Guia de Setup**: `docs/setup-nfs-storage.md`
- **Guia Rápido**: `docs/QUICKSTART-NFS.md`
- **Script de Setup**: `scripts/nfs-server-setup.sh`
- **Manifestos K8s**: `k8s/nfs-provisioner/`

---

## ✅ Status Atual

- [x] VM criada (nfs-server01)
- [x] IP configurado (10.0.2.17/23)
- [x] NFS Server instalado
- [x] Exports configurados
- [x] Firewall configurado
- [x] Scripts de backup criados
- [x] Documentação atualizada

---

**Última atualização:** 2025-10-21

