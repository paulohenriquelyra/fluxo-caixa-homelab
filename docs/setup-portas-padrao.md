# Configurar Portas Padrão 80 e 443 no Ingress

## Objetivo

Acessar a aplicação usando as portas padrão HTTP (80) e HTTPS (443) sem precisar especificar porta na URL:

❌ **Antes:** `http://fluxo-caixa.local:30815/health`  
✅ **Depois:** `http://fluxo-caixa.local/health`

---

## Soluções Disponíveis

Existem 3 abordagens principais para homelab/bare-metal:

1. **MetalLB** - LoadBalancer nativo (recomendado)
2. **HostNetwork** - Usar rede do host diretamente
3. **iptables** - Redirecionamento de portas no host

---

## Solução 1: MetalLB (Recomendado) ⭐

MetalLB fornece LoadBalancer para clusters bare-metal, permitindo IPs externos reais.

### Vantagens
✅ Solução profissional e escalável  
✅ Suporta múltiplos serviços com IPs diferentes  
✅ Funciona como LoadBalancer em cloud  
✅ Fácil manutenção

### Desvantagens
❌ Requer pool de IPs disponíveis na rede  
❌ Configuração inicial mais complexa

### Instalação

#### 1. Instalar MetalLB

```bash
# Aplicar manifests
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Aguardar pods estarem prontos
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

#### 2. Configurar Pool de IPs

**IMPORTANTE:** Escolha IPs **não usados** na sua rede local.

```bash
# Descobrir sua rede
ip route | grep default
# Exemplo: default via 192.168.1.1 dev eth0

# Escolher range de IPs livres (exemplo: 192.168.1.200-210)
# Verificar se estão livres:
for ip in {200..210}; do ping -c 1 -W 1 192.168.1.$ip > /dev/null 2>&1 || echo "192.168.1.$ip - LIVRE"; done
```

**Criar configuração (ajustar IPs para sua rede):**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.210  # <-- AJUSTAR PARA SUA REDE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
```

#### 3. Converter Ingress Controller para LoadBalancer

```bash
# Mudar tipo de NodePort para LoadBalancer
kubectl patch service ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'

# Aguardar IP externo ser atribuído
kubectl get service -n ingress-nginx ingress-nginx-controller -w
```

**Aguarde até ver EXTERNAL-IP:**
```
NAME                       TYPE           EXTERNAL-IP     PORT(S)
ingress-nginx-controller   LoadBalancer   192.168.1.200   80:30815/TCP,443:30342/TCP
```

#### 4. Atualizar /etc/hosts

```bash
# Obter IP externo
EXTERNAL_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Atualizar /etc/hosts (remover entrada antiga se existir)
sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
echo "$EXTERNAL_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts
```

#### 5. Testar

```bash
# Testar porta 80 (sem especificar porta!)
curl http://fluxo-caixa.local/health

# Testar API
curl http://fluxo-caixa.local/api/transacoes
```

---

## Solução 2: HostNetwork (Simples e Rápido)

Faz o Ingress Controller usar a rede do host diretamente, expondo portas 80 e 443.

### Vantagens
✅ Muito simples  
✅ Não requer IPs adicionais  
✅ Portas 80/443 nativas

### Desvantagens
❌ Apenas um Ingress Controller por node  
❌ Conflita com outros serviços na porta 80/443 do host  
❌ Menos isolamento

### Configuração

#### 1. Editar Deployment do NGINX Ingress

```bash
kubectl edit deployment ingress-nginx-controller -n ingress-nginx
```

#### 2. Adicionar `hostNetwork: true`

Encontre a seção `spec.template.spec` e adicione:

```yaml
spec:
  template:
    spec:
      hostNetwork: true  # <-- ADICIONAR ESTA LINHA
      dnsPolicy: ClusterFirstWithHostNet  # <-- ADICIONAR ESTA LINHA
      containers:
      - name: controller
        # ... resto da configuração
```

Salvar e sair (`:wq` no vim).

#### 3. Aguardar Rollout

```bash
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

#### 4. Atualizar /etc/hosts

```bash
# Obter IP do node onde o Ingress está rodando
NODE_IP=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.hostIP}')

# Atualizar /etc/hosts
sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
echo "$NODE_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts
```

#### 5. Testar

```bash
curl http://fluxo-caixa.local/health
curl http://fluxo-caixa.local/api/transacoes
```

---

## Solução 3: iptables (Port Forwarding no Host)

Redireciona portas 80/443 do host para as NodePorts do Ingress.

### Vantagens
✅ Não altera configuração do cluster  
✅ Funciona em qualquer distribuição

### Desvantagens
❌ Configuração por host  
❌ Não persiste após reboot (precisa script)  
❌ Menos elegante

### Configuração

#### 1. Obter NodePorts

```bash
kubectl get service -n ingress-nginx ingress-nginx-controller
```

**Saída exemplo:**
```
NAME                       TYPE       PORT(S)
ingress-nginx-controller   NodePort   80:30815/TCP,443:30342/TCP
```

Anote as portas: **30815** (HTTP) e **30342** (HTTPS)

#### 2. Criar Regras iptables

```bash
# Redirecionar porta 80 para NodePort HTTP (30815)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 30815

# Redirecionar porta 443 para NodePort HTTPS (30342)
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 30342

# Verificar regras
sudo iptables -t nat -L PREROUTING -n -v
```

#### 3. Persistir Regras (Ubuntu/Debian)

```bash
# Instalar iptables-persistent
sudo apt-get update
sudo apt-get install -y iptables-persistent

# Salvar regras
sudo netfilter-persistent save
```

#### 4. Atualizar /etc/hosts

```bash
# Usar localhost ou IP do node
sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
echo "127.0.0.1  fluxo-caixa.local" | sudo tee -a /etc/hosts
```

#### 5. Testar

```bash
curl http://fluxo-caixa.local/health
curl http://fluxo-caixa.local/api/transacoes
```

---

## Comparação das Soluções

| Critério | MetalLB | HostNetwork | iptables |
|----------|---------|-------------|----------|
| **Complexidade** | Média | Baixa | Baixa |
| **Profissionalismo** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Escalabilidade** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐ |
| **Requer IPs extras** | Sim | Não | Não |
| **Portas padrão** | ✅ 80/443 | ✅ 80/443 | ✅ 80/443 |
| **Multi-cluster** | ✅ | ❌ | ❌ |
| **Produção** | ✅ Sim | ⚠️ OK | ❌ Não |

---

## Recomendação por Cenário

### Homelab com IPs disponíveis → **MetalLB** ⭐
Se você tem IPs livres na sua rede (ex: 192.168.1.200-210), use MetalLB. É a solução mais profissional.

### Homelab simples / Testes → **HostNetwork**
Se quer simplicidade e não se importa com limitações, use HostNetwork.

### Rápido e sujo → **iptables**
Para testes rápidos ou quando não pode alterar o cluster.

---

## Adicionar HTTPS (Opcional)

Depois de configurar portas padrão, adicione HTTPS:

### 1. Gerar Certificado Self-Signed

```bash
# Criar certificado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=fluxo-caixa.local/O=FluxoCaixa"

# Criar secret no Kubernetes
kubectl create secret tls fluxo-caixa-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n fluxo-caixa
```

### 2. Atualizar Ingress

```bash
kubectl edit ingress fluxo-caixa-ingress -n fluxo-caixa
```

Adicionar seção `tls`:

```yaml
spec:
  tls:
  - hosts:
    - fluxo-caixa.local
    secretName: fluxo-caixa-tls
  rules:
  - host: fluxo-caixa.local
    # ... resto da configuração
```

### 3. Testar HTTPS

```bash
curl -k https://fluxo-caixa.local/health
```

---

## Scripts de Instalação Automatizada

### Script MetalLB

Salve como `scripts/install-metallb.sh`:

```bash
#!/bin/bash
set -e

echo "🔧 Instalando MetalLB..."

# Instalar MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo "⏳ Aguardando MetalLB estar pronto..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

echo "✅ MetalLB instalado!"
echo ""
echo "📝 Próximo passo: Configurar pool de IPs"
echo "   Edite o range de IPs no comando abaixo e execute:"
echo ""
echo "cat <<EOF | kubectl apply -f -"
echo "apiVersion: metallb.io/v1beta1"
echo "kind: IPAddressPool"
echo "metadata:"
echo "  name: default-pool"
echo "  namespace: metallb-system"
echo "spec:"
echo "  addresses:"
echo "  - 192.168.1.200-192.168.1.210  # <-- AJUSTAR"
echo "---"
echo "apiVersion: metallb.io/v1beta1"
echo "kind: L2Advertisement"
echo "metadata:"
echo "  name: default"
echo "  namespace: metallb-system"
echo "spec:"
echo "  ipAddressPools:"
echo "  - default-pool"
echo "EOF"
```

### Script HostNetwork

Salve como `scripts/enable-hostnetwork.sh`:

```bash
#!/bin/bash
set -e

echo "🔧 Habilitando HostNetwork no NGINX Ingress..."

kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '
{
  "spec": {
    "template": {
      "spec": {
        "hostNetwork": true,
        "dnsPolicy": "ClusterFirstWithHostNet"
      }
    }
  }
}'

echo "⏳ Aguardando rollout..."
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

echo "✅ HostNetwork habilitado!"
echo ""
echo "📝 Atualize /etc/hosts:"
NODE_IP=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.hostIP}')
echo "   echo \"$NODE_IP  fluxo-caixa.local\" | sudo tee -a /etc/hosts"
```

---

## Troubleshooting

### MetalLB: IP não é atribuído

```bash
# Verificar logs do MetalLB
kubectl logs -n metallb-system -l app=metallb -l component=controller

# Verificar configuração
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

### HostNetwork: Porta já em uso

```bash
# Verificar o que está usando porta 80
sudo netstat -tulpn | grep :80

# Parar serviço conflitante (exemplo: Apache)
sudo systemctl stop apache2
```

### iptables: Regras não funcionam

```bash
# Verificar regras
sudo iptables -t nat -L PREROUTING -n -v

# Remover regras
sudo iptables -t nat -F PREROUTING

# Recriar
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 30815
```

---

## Verificação Final

Após configurar, verifique:

```bash
# 1. Ingress tem IP/porta corretos
kubectl get service -n ingress-nginx

# 2. /etc/hosts está correto
cat /etc/hosts | grep fluxo-caixa

# 3. Porta 80 acessível
curl http://fluxo-caixa.local/health

# 4. Porta 443 acessível (se configurou HTTPS)
curl -k https://fluxo-caixa.local/health

# 5. No navegador
firefox http://fluxo-caixa.local
```

---

## Qual Solução Escolher?

**Recomendo começar com MetalLB** se você tem IPs disponíveis na rede. É a solução mais profissional e vai te preparar melhor para ambientes de produção.

Se quiser algo mais simples para começar, use **HostNetwork**.

Quer que eu crie os scripts automatizados para instalar a solução que você escolher?

