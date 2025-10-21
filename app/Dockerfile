# ============================================
# Multi-stage build para otimização
# ============================================

# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copiar apenas package files para aproveitar cache do Docker
COPY package*.json ./

# Instalar dependências
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Runtime
FROM node:18-alpine

# Metadados
LABEL maintainer="Paulo Lyra <paulo.lyra@gmail.com>"
LABEL description="API REST para sistema de fluxo de caixa"
LABEL version="1.0.0"

# Criar usuário não-root para segurança
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copiar node_modules do stage anterior
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copiar código da aplicação
COPY --chown=nodejs:nodejs package*.json ./
COPY --chown=nodejs:nodejs src ./src

# Mudar para usuário não-root
USER nodejs

# Expor porta da aplicação
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Comando de inicialização
CMD ["node", "src/server.js"]

