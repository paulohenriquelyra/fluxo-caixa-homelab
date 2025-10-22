# MetalLB na Rede Proxmox

## Contexto

Seu cluster Kubernetes (RKE2) está rodando em VMs no Proxmox com a seguinte configuração de rede:

**Rede Proxmox:** 10.0.2.0/23  
**Range de IPs:** 10.0.2.0 - 10.0.3.255 (512 IPs)

**Nodes do Cluster:**
- Control Planes: 10.0.3.52, 10.0.3.137, 10.0.3.206
- Workers: 10.0.3.173, 10.0.2.252, 10.0.3.216, 10.0.2.56, 10.0.2.158

**Máquina de Acesso (Desktop):** 10.10.10.123

---

## Problema Anterior

Inicialmente, o MetalLB foi configurado com IPs da rede **10.10.10.0/24** (rede do desktop), mas os nodes estão na rede **10.0.2.0/23** (rede do Proxmox).

Isso causou falha no L2 Advertisement porque:
- MetalLB precisa anunciar IPs via ARP
- ARP só funciona na mesma rede L2
- Nodes (10.0.x.x) não conseguem anunciar IPs da rede 10.10.10.x

---

## Solução: MetalLB na Rede Proxmox

Configurar MetalLB para usar IPs da **mesma rede dos nodes** (10.0.2.0/23).

### Vantagens

✅ **L2 Advertisement funciona** - Nodes podem anunciar IPs via ARP  
✅ **Solução profissional** - LoadBalancer nativo  
✅ **Escalável** - Suporta múltiplos serviços  
✅ **Preparação para produção** - Similar a cloud LoadBalancers

---

## Instalação Automatizada

### Script Completo

O script `reset-to-metallb.sh` faz tudo automaticamente:

```bash
cd ~/projeto-migra/fluxo-caixa-homelab
git pull origin main
./scripts/reset-to-metallb.sh
```

**O que o script faz:**

1. ✅ Reverte configuração HostNetwork (se aplicada)
2. ✅ Remove MetalLB antigo (se existir)
3. ✅ Instala MetalLB do zero
4. ✅ Configura pool de IPs na rede do Proxmox (10.0.3.240-250)
5. ✅ Converte Ingress para LoadBalancer
6. ✅ Atualiza /etc/hosts
7. ✅ Testa conectividade

---

## Configuração Manual

Se preferir fazer manualmente:

### 1. Limpar Configurações Antigas

```bash
# Reverter HostNetwork
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"hostNetwork":false,"dnsPolicy":"ClusterFirst"}}}}'

# Remover MetalLB antigo
kubectl delete namespace metallb-system
```

### 2. Instalar MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

### 3. Configurar Pool de IPs

**Escolher IPs livres na rede 10.0.2.0/23:**

```bash
# Verificar IPs livres (exemplo)
for i in {240..250}; do
    ping -c 1 -W 1 10.0.3.$i > /dev/null 2>&1 || echo "10.0.3.$i - LIVRE"
done
```

**Criar configuração:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: proxmox-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.3.240-10.0.2.17  # Ajustar IPs livres
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: proxmox-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - proxmox-pool
EOF
```

### 4. Converter Ingress para LoadBalancer

```bash
kubectl patch service ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'

# Aguardar IP
kubectl get service -n ingress-nginx -w
```

### 5. Atualizar /etc/hosts

```bash
EXTERNAL_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

sudo sed -i '/fluxo-caixa.local/d' /etc/hosts
echo "$EXTERNAL_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts
```

### 6. Testar

```bash
ping -c 3 $EXTERNAL_IP
curl http://fluxo-caixa.local/health
```

---

## Ranges de IPs Recomendados

### Opção 1: Conservadora (11 IPs)
```yaml
addresses:
- 10.0.3.240-10.0.2.17
```

**Uso:** 1-10 LoadBalancers

### Opção 2: Moderada (21 IPs)
```yaml
addresses:
- 10.0.3.230-10.0.2.17
```

**Uso:** 10-20 LoadBalancers

### Opção 3: Ampla (51 IPs)
```yaml
addresses:
- 10.0.3.200-10.0.2.17
```

**Uso:** 20-50 LoadBalancers

### Opção 4: Muito Ampla (256 IPs)
```yaml
addresses:
- 10.0.2.0-10.0.2.255
```

**Uso:** Ambiente grande com muitos serviços

---

## Roteamento

### Acesso do Desktop (10.10.10.123) para IPs do MetalLB (10.0.3.x)

Você precisa garantir que sua máquina consegue alcançar a rede 10.0.2.0/23.

**Verificar conectividade:**

```bash
ping -c 2 10.0.3.52   # Node do cluster
ping -c 2 10.0.3.240  # IP do MetalLB (após atribuído)
```

**Se não funcionar, adicionar rota:**

```bash
# Descobrir gateway
ip route | grep default

# Adicionar rota (ajustar gateway)
sudo ip route add 10.0.2.0/23 via 10.10.10.1

# Ou se o Proxmox for o gateway
sudo ip route add 10.0.2.0/23 via IP_DO_PROXMOX
```

**Persistir rota (Ubuntu/Debian):**

```bash
# Editar /etc/netplan/01-netcfg.yaml
sudo nano /etc/netplan/01-netcfg.yaml

# Adicionar:
network:
  version: 2
  ethernets:
    ens33:
      routes:
      - to: 10.0.2.0/23
        via: 10.10.10.1  # Ajustar gateway

# Aplicar
sudo netplan apply
```

---

## Troubleshooting

### IP não é atribuído

```bash
# Ver logs do MetalLB
kubectl logs -n metallb-system -l component=controller --tail=50

# Ver configuração
kubectl get ipaddresspool -n metallb-system -o yaml
kubectl get l2advertisement -n metallb-system -o yaml

# Ver eventos
kubectl get events -n metallb-system --sort-by='.lastTimestamp'
```

### IP atribuído mas não responde ping

**Causas comuns:**

1. **Firewall bloqueando** - Verificar iptables/firewalld
2. **ARP não propagado** - Aguardar alguns segundos
3. **Roteamento incorreto** - Adicionar rota estática

**Verificar ARP:**

```bash
# Ver tabela ARP
arp -a | grep 10.0.3

# Forçar ARP
arping -c 3 10.0.3.240
```

**Verificar firewall:**

```bash
# Ver regras iptables
sudo iptables -L -n -v

# Permitir tráfego (se necessário)
sudo iptables -A INPUT -s 10.0.2.0/23 -j ACCEPT
sudo iptables -A OUTPUT -d 10.0.2.0/23 -j ACCEPT
```

### Conflito de IP

Se o IP escolhido já está em uso:

```bash
# Deletar pool
kubectl delete ipaddresspool proxmox-pool -n metallb-system

# Criar novo pool com IPs diferentes
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: proxmox-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.3.245-10.0.3.254  # Novo range
EOF

# Recriar Service
kubectl delete service ingress-nginx-controller -n ingress-nginx
kubectl patch service ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'
```

---

## Verificação Final

Após configurar, verificar:

```bash
# 1. MetalLB rodando
kubectl get pods -n metallb-system
# Deve mostrar: controller e speakers Running

# 2. Pool configurado
kubectl get ipaddresspool -n metallb-system
# Deve mostrar: proxmox-pool

# 3. IP atribuído
kubectl get service -n ingress-nginx
# EXTERNAL-IP deve mostrar um IP (ex: 10.0.3.240)

# 4. Ping funciona
ping -c 3 10.0.3.240

# 5. Aplicação responde
curl http://fluxo-caixa.local/health
```

---

## Comparação: Antes vs Depois

### Antes (HostNetwork)

```
Desktop (10.10.10.123)
    ↓
Node IP (10.0.3.52:80)
    ↓
NGINX Ingress (HostNetwork)
    ↓
Aplicação
```

**Limitações:**
- Apenas 1 Ingress por node
- Conflito de portas
- Menos profissional

### Depois (MetalLB)

```
Desktop (10.10.10.123)
    ↓ (roteamento)
MetalLB IP (10.0.3.240:80)
    ↓ (L2 Advertisement)
NGINX Ingress (LoadBalancer)
    ↓
Aplicação
```

**Vantagens:**
- Múltiplos LoadBalancers
- Portas padrão (80/443)
- Solução profissional
- Escalável

---

## Próximos Passos

Após configurar MetalLB:

1. **Adicionar HTTPS**
   - Gerar certificado
   - Configurar TLS no Ingress

2. **Expor Outros Serviços**
   - Criar LoadBalancers para outros apps
   - Cada um recebe um IP do pool

3. **Monitoramento**
   - Prometheus + Grafana
   - Métricas do MetalLB

4. **Backup**
   - Documentar configuração
   - Versionar no Git

---

## Referências

- [MetalLB Documentation](https://metallb.universe.tf/)
- [MetalLB Configuration](https://metallb.universe.tf/configuration/)
- [L2 Advertisement](https://metallb.universe.tf/concepts/layer2/)
- [Proxmox Networking](https://pve.proxmox.com/wiki/Network_Configuration)

