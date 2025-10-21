# Troubleshooting - Ingress não Acessível

## Problema: Não Consigo Acessar via Ingress

### Sintoma
```bash
$ curl http://fluxo-caixa.local/health
curl: (6) Could not resolve host: fluxo-caixa.local
```

Ou:

```bash
$ curl http://fluxo-caixa.local/health
curl: (7) Failed to connect to fluxo-caixa.local port 80: Connection refused
```

---

## Diagnóstico Rápido

Execute o script de diagnóstico:

```bash
./scripts/diagnose-ingress.sh
```

Ou siga os passos manuais abaixo.

---

## Causas Comuns

1. ❌ **Ingress Controller não instalado**
2. ❌ **`/etc/hosts` não configurado**
3. ❌ **Pods da aplicação não estão Running**
4. ❌ **Service sem endpoints**
5. ❌ **Ingress mal configurado**

---

## Solução Passo a Passo

### 1. Verificar se Ingress Controller Está Instalado

```bash
# Verificar NGINX Ingress Controller
kubectl get pods -n ingress-nginx

# Ou Traefik
kubectl get pods -n traefik

# Ou em kube-system
kubectl get pods -n kube-system | grep ingress
```

**Se não estiver instalado:**

#### Instalar NGINX Ingress Controller

**Para clusters com LoadBalancer (cloud):**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

**Para bare-metal/homelab:**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
```

**Para K3s (já vem com Traefik):**
```bash
# K3s já tem Traefik instalado
kubectl get pods -n kube-system | grep traefik
```

**Aguardar estar pronto:**
```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

---

### 2. Verificar IP do Ingress Controller

```bash
# Ver service do Ingress
kubectl get service -n ingress-nginx
```

**Saída esperada (LoadBalancer):**
```
NAME                                 TYPE           EXTERNAL-IP
ingress-nginx-controller             LoadBalancer   192.168.1.100
```

**Saída esperada (NodePort - homelab):**
```
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
ingress-nginx-controller             NodePort    10.43.123.456   <none>        80:30080/TCP,443:30443/TCP
```

**Obter IP:**

```bash
# Se LoadBalancer
INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Se NodePort (homelab)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')

echo "Acesse via: http://$NODE_IP:$NODE_PORT"
```

---

### 3. Configurar /etc/hosts

**Obter host do Ingress:**
```bash
kubectl get ingress -n fluxo-caixa -o jsonpath='{.items[0].spec.rules[0].host}'
```

**Adicionar ao /etc/hosts:**

```bash
# Se LoadBalancer
echo "192.168.1.100  fluxo-caixa.local" | sudo tee -a /etc/hosts

# Se NodePort (homelab) - usar IP do node
echo "192.168.1.50  fluxo-caixa.local" | sudo tee -a /etc/hosts

# Se localhost (teste)
echo "127.0.0.1  fluxo-caixa.local" | sudo tee -a /etc/hosts
```

**Verificar:**
```bash
cat /etc/hosts | grep fluxo-caixa
ping fluxo-caixa.local
```

---

### 4. Verificar Pods da Aplicação

```bash
kubectl get pods -n fluxo-caixa
```

**Devem estar `Running` e `1/1` Ready:**
```
NAME                               READY   STATUS    RESTARTS   AGE
fluxo-caixa-app-xxxxx-yyyyy        1/1     Running   0          5m
fluxo-caixa-app-xxxxx-zzzzz        1/1     Running   0          5m
```

**Se não estiverem Running:**
```bash
kubectl describe pod -n fluxo-caixa -l app=fluxo-caixa-app
kubectl logs -n fluxo-caixa -l app=fluxo-caixa-app
```

---

### 5. Verificar Service e Endpoints

```bash
# Ver service
kubectl get service fluxo-caixa-service -n fluxo-caixa

# Ver endpoints (deve ter IPs dos pods)
kubectl get endpoints fluxo-caixa-service -n fluxo-caixa
```

**Endpoints devem mostrar IPs:**
```
NAME                  ENDPOINTS                         AGE
fluxo-caixa-service   10.42.0.10:3000,10.42.0.11:3000   5m
```

**Se não tiver endpoints:**
- Verificar se pods estão Running
- Verificar se selector do Service está correto

---

### 6. Verificar Ingress

```bash
kubectl get ingress -n fluxo-caixa
kubectl describe ingress -n fluxo-caixa
```

**Verificar:**
- ✅ Host está correto (`fluxo-caixa.local`)
- ✅ Backend aponta para `fluxo-caixa-service:80`
- ✅ IngressClass está correto (`nginx` ou `traefik`)

**Editar se necessário:**
```bash
kubectl edit ingress fluxo-caixa-ingress -n fluxo-caixa
```

---

## Testes de Conectividade

### Teste 1: Port-Forward Direto (Bypass Ingress)

```bash
# Port-forward para o service
kubectl port-forward -n fluxo-caixa service/fluxo-caixa-service 8080:80

# Em outro terminal
curl http://localhost:8080/health
```

**Se funcionar:** Problema está no Ingress
**Se não funcionar:** Problema está na aplicação/service

---

### Teste 2: Curl Direto no Pod

```bash
# Obter nome do pod
POD_NAME=$(kubectl get pods -n fluxo-caixa -l app=fluxo-caixa-app -o jsonpath='{.items[0].metadata.name}')

# Testar dentro do pod
kubectl exec -it $POD_NAME -n fluxo-caixa -- wget -O- http://localhost:3000/health
```

**Se funcionar:** Aplicação está OK, problema está no Service ou Ingress

---

### Teste 3: Curl via ClusterIP

```bash
# Obter ClusterIP do service
CLUSTER_IP=$(kubectl get service fluxo-caixa-service -n fluxo-caixa -o jsonpath='{.spec.clusterIP}')

# Testar de dentro do cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://$CLUSTER_IP/health
```

**Se funcionar:** Service está OK, problema está no Ingress

---

### Teste 4: Curl via Ingress

```bash
# Testar com verbose
curl -v http://fluxo-caixa.local/health

# Testar com IP direto (bypass DNS)
curl -H "Host: fluxo-caixa.local" http://192.168.1.50/health
```

---

## Soluções por Cenário

### Cenário 1: K3s com Traefik

K3s já vem com Traefik instalado. Ajuste o Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fluxo-caixa-ingress
  namespace: fluxo-caixa
spec:
  ingressClassName: traefik  # <-- Usar traefik
  rules:
  - host: fluxo-caixa.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: fluxo-caixa-service
            port:
              number: 80
```

**Obter IP:**
```bash
kubectl get service -n kube-system traefik -o wide
```

---

### Cenário 2: Bare-Metal sem LoadBalancer

Use NodePort:

```bash
# Obter NodePort
kubectl get service -n ingress-nginx

# Acessar via NodePort
curl http://NODE_IP:NODE_PORT/health
```

Ou configure MetalLB para LoadBalancer:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
```

---

### Cenário 3: Proxmox Homelab

**Opção A: Port-Forward do Proxmox Host**

No host Proxmox, redirecionar porta 80 para NodePort:

```bash
# No host Proxmox
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination NODE_IP:NODE_PORT
```

**Opção B: Usar IP do Node Diretamente**

```bash
# Adicionar ao /etc/hosts do seu desktop
echo "NODE_IP  fluxo-caixa.local" | sudo tee -a /etc/hosts

# Acessar
curl http://fluxo-caixa.local:NODE_PORT/health
```

---

## Logs e Debug

### Ver Logs do Ingress Controller

```bash
# NGINX Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f
```

### Ver Logs da Aplicação

```bash
kubectl logs -f deployment/fluxo-caixa-app -n fluxo-caixa
```

### Ver Eventos

```bash
kubectl get events -n fluxo-caixa --sort-by='.lastTimestamp'
```

---

## Solução Rápida (Homelab)

Se você só quer testar rapidamente:

```bash
# 1. Port-forward
kubectl port-forward -n fluxo-caixa service/fluxo-caixa-service 8080:80 &

# 2. Testar
curl http://localhost:8080/health
curl http://localhost:8080/api/transacoes/consultas/saldo

# 3. Usar no navegador
firefox http://localhost:8080
```

---

## Checklist de Verificação

- [ ] Ingress Controller instalado e Running
- [ ] Pods da aplicação Running (1/1)
- [ ] Service tem endpoints
- [ ] Ingress criado e configurado
- [ ] IngressClass correto (nginx/traefik)
- [ ] /etc/hosts configurado
- [ ] IP do Ingress acessível
- [ ] Port-forward funciona (teste de bypass)

---

## Comandos Úteis

```bash
# Status completo
kubectl get all -n fluxo-caixa
kubectl get ingress -n fluxo-caixa
kubectl get service -n ingress-nginx

# Diagnóstico completo
./scripts/diagnose-ingress.sh

# Recriar Ingress
kubectl delete ingress fluxo-caixa-ingress -n fluxo-caixa
kubectl apply -f k8s/09-ingress.yaml

# Reiniciar Ingress Controller
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

---

## Precisa de Ajuda?

Execute e me envie a saída:

```bash
./scripts/diagnose-ingress.sh > ingress-debug.txt
cat ingress-debug.txt
```

Ou:

```bash
kubectl get ingress -n fluxo-caixa -o yaml
kubectl get service -n ingress-nginx
kubectl get pods -n fluxo-caixa
```

