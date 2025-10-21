# Troubleshooting - Fluxo de Caixa Kubernetes

## Problema: Pod PostgreSQL em Estado "Pending"

### Sintoma
```bash
$ kubectl get pods -n fluxo-caixa
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   0/1     Pending   0          7m55s
```

### Causa Raiz

Um pod fica em estado **Pending** quando o Kubernetes **não consegue agendar** (schedule) o pod em nenhum node. As causas mais comuns são:

1. ❌ **PVC não pode ser provisionado** (mais comum)
2. ❌ Recursos insuficientes (CPU/Memory)
3. ❌ Node selector/affinity não satisfeito
4. ❌ Taints nos nodes

---

## Diagnóstico Passo a Passo

### 1. Ver Detalhes do Pod

```bash
kubectl describe pod postgres-0 -n fluxo-caixa
```

**O que procurar na saída:**
- Seção `Events` no final (mostra o motivo)
- Mensagens como:
  - `FailedScheduling`
  - `FailedMount`
  - `Insufficient cpu/memory`

### 2. Verificar PVC (Causa Mais Comum)

```bash
# Ver status do PVC
kubectl get pvc -n fluxo-caixa

# Ver detalhes do PVC
kubectl describe pvc postgres-pvc -n fluxo-caixa
```

**Status esperado:** `Bound`

**Se estiver `Pending`:**
- O PVC não conseguiu provisionar o volume
- Problema com StorageClass

---

## Soluções por Causa

### Solução 1: PVC Pending (Mais Comum)

#### Problema: StorageClass não existe ou não está configurada

**Verificar StorageClasses disponíveis:**
```bash
kubectl get storageclass
```

**Saída esperada (exemplo):**
```
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```

#### Solução A: Usar StorageClass Existente

Se você tem uma StorageClass disponível, edite o PVC:

```bash
kubectl edit pvc postgres-pvc -n fluxo-caixa
```

Adicione ou modifique:
```yaml
spec:
  storageClassName: local-path  # Substituir pelo nome da sua StorageClass
```

Ou edite o arquivo `k8s/03-postgres-pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: fluxo-caixa
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path  # <-- Adicionar esta linha
  resources:
    requests:
      storage: 10Gi
```

Reaplique:
```bash
kubectl delete pvc postgres-pvc -n fluxo-caixa
kubectl apply -f k8s/03-postgres-pvc.yaml
```

#### Solução B: Criar PersistentVolume Manual (Homelab)

Se não tem StorageClass dinâmica, crie um PV manual:

**Criar arquivo `k8s/03-postgres-pv.yaml`:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/postgres"  # Ajustar para seu caminho
    type: DirectoryOrCreate
```

**Atualizar PVC `k8s/03-postgres-pvc.yaml`:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: fluxo-caixa
spec:
  storageClassName: manual  # <-- Mesmo nome do PV
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Aplicar:**
```bash
# Criar diretório no node (se necessário)
sudo mkdir -p /mnt/data/postgres
sudo chmod 777 /mnt/data/postgres

# Aplicar PV e PVC
kubectl apply -f k8s/03-postgres-pv.yaml
kubectl apply -f k8s/03-postgres-pvc.yaml

# Verificar
kubectl get pv
kubectl get pvc -n fluxo-caixa
```

#### Solução C: Instalar Provisioner Dinâmico (Recomendado)

Para clusters sem StorageClass dinâmica, instale um provisioner:

**Opção 1: Local Path Provisioner (K3s, RKE2)**
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

**Opção 2: NFS Provisioner (se tem NFS)**
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=SEU_NFS_SERVER \
  --set nfs.path=/exported/path
```

**Opção 3: Longhorn (Storage distribuído)**
```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml
```

---

### Solução 2: Recursos Insuficientes

#### Verificar recursos disponíveis nos nodes:

```bash
kubectl top nodes
kubectl describe nodes
```

**Se CPU/Memory insuficientes:**

Reduzir recursos do PostgreSQL em `k8s/04-postgres-statefulset.yaml`:

```yaml
resources:
  requests:
    cpu: 250m      # Reduzido de 500m
    memory: 256Mi  # Reduzido de 512Mi
  limits:
    cpu: 500m      # Reduzido de 1000m
    memory: 512Mi  # Reduzido de 1Gi
```

Reaplicar:
```bash
kubectl delete statefulset postgres -n fluxo-caixa
kubectl apply -f k8s/04-postgres-statefulset.yaml
```

---

### Solução 3: Node Selector/Affinity

Se o StatefulSet tem node selector que não é satisfeito:

```bash
# Ver labels dos nodes
kubectl get nodes --show-labels

# Remover node selector (se existir)
kubectl edit statefulset postgres -n fluxo-caixa
```

---

### Solução 4: Taints nos Nodes

Verificar se nodes têm taints:

```bash
kubectl describe nodes | grep -i taint
```

**Se houver taints:**

Adicionar tolerations no StatefulSet:
```yaml
spec:
  template:
    spec:
      tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
```

---

## Comandos de Diagnóstico Rápido

```bash
# 1. Ver eventos do namespace
kubectl get events -n fluxo-caixa --sort-by='.lastTimestamp'

# 2. Ver detalhes do pod
kubectl describe pod postgres-0 -n fluxo-caixa

# 3. Ver status do PVC
kubectl get pvc -n fluxo-caixa
kubectl describe pvc postgres-pvc -n fluxo-caixa

# 4. Ver StorageClasses
kubectl get storageclass

# 5. Ver recursos dos nodes
kubectl top nodes
kubectl describe nodes

# 6. Ver logs do scheduler (se necessário)
kubectl logs -n kube-system -l component=kube-scheduler
```

---

## Solução Rápida para Homelab (Sem StorageClass)

Se você quer resolver rapidamente para testar:

**1. Criar PV e PVC manual:**

```bash
# Criar diretório
sudo mkdir -p /mnt/data/postgres
sudo chmod 777 /mnt/data/postgres

# Criar PV
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/postgres"
    type: DirectoryOrCreate
EOF

# Atualizar PVC
kubectl patch pvc postgres-pvc -n fluxo-caixa -p '{"spec":{"storageClassName":"manual"}}'
```

**2. Verificar:**
```bash
kubectl get pv
kubectl get pvc -n fluxo-caixa
kubectl get pods -n fluxo-caixa -w
```

---

## Checklist de Verificação

- [ ] PVC está `Bound`?
- [ ] StorageClass existe?
- [ ] Node tem espaço em disco?
- [ ] Node tem CPU/Memory suficiente?
- [ ] Pod não tem node selector incompatível?
- [ ] Nodes não têm taints bloqueando?

---

## Próximos Passos Após Resolver

Depois que o pod estiver `Running`:

```bash
# Verificar logs
kubectl logs -f postgres-0 -n fluxo-caixa

# Testar conexão
kubectl exec -it postgres-0 -n fluxo-caixa -- pg_isready -U postgres

# Continuar com inicialização do banco
kubectl exec -it postgres-0 -n fluxo-caixa -- psql -U postgres -c "CREATE DATABASE fluxocaixa;"
```

---

## Precisa de Ajuda?

Execute estes comandos e me envie a saída:

```bash
kubectl describe pod postgres-0 -n fluxo-caixa
kubectl get pvc -n fluxo-caixa
kubectl get storageclass
kubectl get nodes
```

