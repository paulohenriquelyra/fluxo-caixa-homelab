require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const db = require('./models/db');
const transacoesRoutes = require('./routes/transacoes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middlewares de segurança e otimização
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Middleware de log de requisições
app.use((req, res, next) => {
    console.log(`📨 ${req.method} ${req.path}`);
    next();
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: '1.0.0'
    });
});

// Rota raiz
app.get('/', (req, res) => {
    res.json({
        message: 'API Fluxo de Caixa',
        version: '1.0.0',
        endpoints: {
            health: '/health',
            transacoes: '/api/transacoes',
            saldo: '/api/transacoes/consultas/saldo',
            relatorio: '/api/transacoes/consultas/relatorio-mensal'
        }
    });
});

// Rotas da API
app.use('/api/transacoes', transacoesRoutes);

// Middleware de erro 404
app.use((req, res) => {
    res.status(404).json({
        success: false,
        error: 'Rota não encontrada',
        path: req.path
    });
});

// Middleware de tratamento de erros global
app.use((err, req, res, next) => {
    console.error('❌ Erro não tratado:', err);
    res.status(500).json({
        success: false,
        error: 'Erro interno do servidor',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Erro interno'
    });
});

// Inicializar servidor
const startServer = async () => {
    try {
        // Testar conexão com banco de dados
        console.log('🔌 Testando conexão com banco de dados...');
        const dbConnected = await db.testConnection();
        
        if (!dbConnected) {
            console.error('❌ Não foi possível conectar ao banco de dados');
            process.exit(1);
        }
        
        // Iniciar servidor HTTP
        app.listen(PORT, '0.0.0.0', () => {
            console.log('========================================');
            console.log('🚀 Servidor iniciado com sucesso!');
            console.log(`   Porta: ${PORT}`);
            console.log(`   Ambiente: ${process.env.NODE_ENV || 'development'}`);
            console.log(`   Health Check: http://localhost:${PORT}/health`);
            console.log(`   API Base: http://localhost:${PORT}/api`);
            console.log('========================================');
        });
    } catch (err) {
        console.error('❌ Erro ao iniciar servidor:', err);
        process.exit(1);
    }
};

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('\n🛑 SIGTERM recebido. Encerrando servidor...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('\n🛑 SIGINT recebido. Encerrando servidor...');
    process.exit(0);
});

// Iniciar aplicação
startServer();

module.exports = app;

