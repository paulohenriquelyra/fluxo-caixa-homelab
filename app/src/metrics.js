const promClient = require('prom-client');

// Criar registry
const register = new promClient.Registry();

// Adicionar métricas padrão (CPU, memória, etc)
promClient.collectDefaultMetrics({ register });

// Métricas customizadas da aplicação

// Contador de requisições HTTP
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total de requisições HTTP',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Histograma de duração das requisições
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duração das requisições HTTP em segundos',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Gauge de conexões ativas do banco
const dbConnectionsActive = new promClient.Gauge({
  name: 'db_connections_active',
  help: 'Número de conexões ativas com o banco de dados',
  registers: [register]
});

// Contador de queries do banco
const dbQueriesTotal = new promClient.Counter({
  name: 'db_queries_total',
  help: 'Total de queries executadas no banco',
  labelNames: ['operation', 'status'],
  registers: [register]
});

// Histograma de duração das queries
const dbQueryDuration = new promClient.Histogram({
  name: 'db_query_duration_seconds',
  help: 'Duração das queries do banco em segundos',
  labelNames: ['operation'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Métricas de negócio - Transações

const transacoesTotal = new promClient.Counter({
  name: 'fluxocaixa_transacoes_total',
  help: 'Total de transações criadas',
  labelNames: ['tipo', 'status'],
  registers: [register]
});

const transacoesValor = new promClient.Counter({
  name: 'fluxocaixa_transacoes_valor_total',
  help: 'Valor total das transações',
  labelNames: ['tipo', 'status'],
  registers: [register]
});

const saldoAtual = new promClient.Gauge({
  name: 'fluxocaixa_saldo_atual',
  help: 'Saldo atual do fluxo de caixa',
  registers: [register]
});

// Middleware para coletar métricas de requisições HTTP
function metricsMiddleware(req, res, next) {
  const start = Date.now();
  
  // Capturar a resposta
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    const method = req.method;
    const statusCode = res.statusCode;
    
    // Incrementar contador
    httpRequestsTotal.labels(method, route, statusCode).inc();
    
    // Registrar duração
    httpRequestDuration.labels(method, route, statusCode).observe(duration);
  });
  
  next();
}

// Função para atualizar métricas do pool de conexões
function updateDbPoolMetrics(pool) {
  if (pool) {
    dbConnectionsActive.set(pool.totalCount - pool.idleCount);
  }
}

// Função para registrar query do banco
function recordDbQuery(operation, duration, success = true) {
  const status = success ? 'success' : 'error';
  dbQueriesTotal.labels(operation, status).inc();
  dbQueryDuration.labels(operation).observe(duration);
}

// Função para registrar transação de negócio
function recordTransacao(tipo, valor, status = 'confirmado') {
  transacoesTotal.labels(tipo, status).inc();
  transacoesValor.labels(tipo, status).inc(valor);
}

// Função para atualizar saldo
function updateSaldo(valor) {
  saldoAtual.set(valor);
}

// Endpoint de métricas
async function metricsHandler(req, res) {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
}

module.exports = {
  register,
  metricsMiddleware,
  metricsHandler,
  updateDbPoolMetrics,
  recordDbQuery,
  recordTransacao,
  updateSaldo,
  // Exportar métricas individuais para uso direto
  httpRequestsTotal,
  httpRequestDuration,
  dbConnectionsActive,
  dbQueriesTotal,
  dbQueryDuration,
  transacoesTotal,
  transacoesValor,
  saldoAtual
};

