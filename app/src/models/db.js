const { Pool } = require('pg');
const dbConfig = require('../config/database');

// Criar pool de conexões
const pool = new Pool(dbConfig);

// Event listeners para monitoramento
pool.on('connect', () => {
    console.log('✅ Nova conexão estabelecida com o banco de dados');
});

pool.on('error', (err) => {
    console.error('❌ Erro inesperado no pool de conexões:', err);
    process.exit(-1);
});

// Função para testar conexão
const testConnection = async () => {
    try {
        const client = await pool.connect();
        const result = await client.query('SELECT NOW() as now, version() as version');
        console.log('✅ Conexão com banco de dados OK');
        console.log(`   Timestamp: ${result.rows[0].now}`);
        console.log(`   PostgreSQL: ${result.rows[0].version.split(',')[0]}`);
        client.release();
        return true;
    } catch (err) {
        console.error('❌ Erro ao conectar com banco de dados:', err.message);
        return false;
    }
};

// Função auxiliar para executar queries
const query = async (text, params) => {
    const start = Date.now();
    try {
        const res = await pool.query(text, params);
        const duration = Date.now() - start;
        console.log('📊 Query executada:', { text, duration: `${duration}ms`, rows: res.rowCount });
        return res;
    } catch (err) {
        console.error('❌ Erro na query:', { text, error: err.message });
        throw err;
    }
};

// Função para executar transações
const transaction = async (callback) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
    } catch (err) {
        await client.query('ROLLBACK');
        throw err;
    } finally {
        client.release();
    }
};

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n🛑 Encerrando pool de conexões...');
    await pool.end();
    console.log('✅ Pool de conexões encerrado');
    process.exit(0);
});

module.exports = {
    pool,
    query,
    transaction,
    testConnection
};

