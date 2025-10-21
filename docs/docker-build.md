# Guia de Build da Imagem Docker

## Problema Comum: npm ci Falha

### Erro
```
npm error The `npm ci` command can only install with an existing package-lock.json
```

### Causa
O comando `npm ci` requer um arquivo `package-lock.json` que não estava no repositório.

### Solução Aplicada
Alteramos o Dockerfile para usar `npm install --omit=dev` ao invés de `npm ci`.

---

## Build da Imagem

### Pré-requisitos
- Docker instalado
- Conta no Docker Hub (ou outro registry)

### Passo 1: Login no Docker Hub

```bash
docker login
```

Digite seu usuário e senha do Docker Hub.

### Passo 2: Build da Imagem

```bash
cd app/

# Build com sua tag
docker build -t SEU_USUARIO/fluxo-caixa-app:v1.0 .

# Exemplo:
docker build -t phfldocker/fluxo-caixa-app:v1.0 .
```

**Tempo estimado:** 2-3 minutos

### Passo 3: Testar Localmente (Opcional)

```bash
# Rodar container local
docker run -d \
  --name fluxo-caixa-test \
  -p 3000:3000 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=fluxocaixa \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres123 \
  SEU_USUARIO/fluxo-caixa-app:v1.0

# Testar
curl http://localhost:3000/health

# Ver logs
docker logs -f fluxo-caixa-test

# Parar e remover
docker stop fluxo-caixa-test
docker rm fluxo-caixa-test
```

### Passo 4: Push para Docker Hub

```bash
docker push SEU_USUARIO/fluxo-caixa-app:v1.0
```

**Tempo estimado:** 1-2 minutos (depende da conexão)

### Passo 5: Atualizar Manifesto Kubernetes

Edite `k8s/07-app-deployment.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: SEU_USUARIO/fluxo-caixa-app:v1.0  # <-- Atualizar aqui
```

Ou use `sed`:

```bash
sed -i 's|seu-registry/fluxo-caixa-app:v1.0|SEU_USUARIO/fluxo-caixa-app:v1.0|g' k8s/07-app-deployment.yaml
```

---

## Build Alternativo (Multi-arquitetura)

Para suportar ARM64 (Apple Silicon, Raspberry Pi) e AMD64:

```bash
# Criar builder
docker buildx create --name multiarch --use

# Build multi-arch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t SEU_USUARIO/fluxo-caixa-app:v1.0 \
  --push \
  .
```

---

## Troubleshooting

### Erro: "npm ci requires package-lock.json"

**Solução:** Já corrigido no Dockerfile. Use `npm install --omit=dev`.

### Erro: "Cannot connect to Docker daemon"

**Solução:**
```bash
# Verificar se Docker está rodando
sudo systemctl status docker

# Iniciar Docker
sudo systemctl start docker

# Adicionar usuário ao grupo docker (evita sudo)
sudo usermod -aG docker $USER
newgrp docker
```

### Erro: "denied: requested access to the resource is denied"

**Solução:** Fazer login no Docker Hub
```bash
docker login
```

### Build muito lento

**Solução:** Usar BuildKit
```bash
export DOCKER_BUILDKIT=1
docker build -t SEU_USUARIO/fluxo-caixa-app:v1.0 .
```

### Imagem muito grande

**Verificar tamanho:**
```bash
docker images | grep fluxo-caixa-app
```

**Tamanho esperado:** ~150-200MB (já otimizado com alpine)

---

## Otimizações Aplicadas

✅ **Multi-stage build** - Reduz tamanho final
✅ **Alpine Linux** - Base mínima (~5MB)
✅ **Layer caching** - package.json copiado antes do código
✅ **Non-root user** - Segurança
✅ **Health check** - Monitoramento automático
✅ **npm cache clean** - Remove cache desnecessário

---

## Tags Recomendadas

```bash
# Versão específica
docker build -t SEU_USUARIO/fluxo-caixa-app:v1.0 .

# Latest
docker build -t SEU_USUARIO/fluxo-caixa-app:latest .

# Com hash do commit
GIT_HASH=$(git rev-parse --short HEAD)
docker build -t SEU_USUARIO/fluxo-caixa-app:$GIT_HASH .

# Push todas as tags
docker push SEU_USUARIO/fluxo-caixa-app:v1.0
docker push SEU_USUARIO/fluxo-caixa-app:latest
docker push SEU_USUARIO/fluxo-caixa-app:$GIT_HASH
```

---

## CI/CD (GitHub Actions)

Para automatizar o build, crie `.github/workflows/docker-build.yml`:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKERHUB_USERNAME }}
        password: ${{ secrets.DOCKERHUB_TOKEN }}
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: ./app
        push: true
        tags: |
          ${{ secrets.DOCKERHUB_USERNAME }}/fluxo-caixa-app:latest
          ${{ secrets.DOCKERHUB_USERNAME }}/fluxo-caixa-app:${{ github.sha }}
```

---

## Comandos Úteis

```bash
# Ver imagens locais
docker images

# Remover imagem
docker rmi SEU_USUARIO/fluxo-caixa-app:v1.0

# Limpar imagens não usadas
docker image prune -a

# Ver histórico de layers
docker history SEU_USUARIO/fluxo-caixa-app:v1.0

# Inspecionar imagem
docker inspect SEU_USUARIO/fluxo-caixa-app:v1.0

# Escanear vulnerabilidades
docker scan SEU_USUARIO/fluxo-caixa-app:v1.0
```

---

## Checklist de Build

- [ ] Docker instalado e rodando
- [ ] Login no Docker Hub realizado
- [ ] Build concluído sem erros
- [ ] Imagem testada localmente (opcional)
- [ ] Push para registry concluído
- [ ] Manifesto K8s atualizado com nome correto da imagem
- [ ] Deploy no Kubernetes

---

## Próximos Passos

Após o build e push bem-sucedidos:

1. Atualizar `k8s/07-app-deployment.yaml` com sua imagem
2. Aplicar no Kubernetes: `kubectl apply -f k8s/07-app-deployment.yaml`
3. Verificar pods: `kubectl get pods -n fluxo-caixa -w`
4. Testar API: `./scripts/test-api.sh`

