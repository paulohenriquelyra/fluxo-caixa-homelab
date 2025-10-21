const db = require('../models/db');

// Listar todas as transações
exports.listarTransacoes = async (req, res) => {
    try {
        const { limit = 50, offset = 0, tipo, status = 'confirmada' } = req.query;
        
        let query = `
            SELECT 
                t.id,
                t.uuid,
                t.descricao,
                t.valor,
                t.tipo,
                t.data_transacao,
                t.status,
                t.observacoes,
                t.tags,
                c.nome as categoria,
                u.nome as usuario
            FROM transacoes t
            LEFT JOIN categorias c ON t.categoria_id = c.id
            LEFT JOIN usuarios u ON t.usuario_id = u.id
            WHERE t.status = $1
        `;
        
        const params = [status];
        
        if (tipo) {
            query += ` AND t.tipo = $${params.length + 1}`;
            params.push(tipo);
        }
        
        query += ` ORDER BY t.data_transacao DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
        params.push(limit, offset);
        
        const result = await db.query(query, params);
        
        res.json({
            success: true,
            count: result.rows.length,
            data: result.rows
        });
    } catch (err) {
        console.error('Erro ao listar transações:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao listar transações',
            message: err.message
        });
    }
};

// Buscar transação por ID
exports.buscarTransacao = async (req, res) => {
    try {
        const { id } = req.params;
        
        const result = await db.query(`
            SELECT 
                t.*,
                c.nome as categoria,
                u.nome as usuario,
                u.email as usuario_email
            FROM transacoes t
            LEFT JOIN categorias c ON t.categoria_id = c.id
            LEFT JOIN usuarios u ON t.usuario_id = u.id
            WHERE t.id = $1
        `, [id]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Transação não encontrada'
            });
        }
        
        res.json({
            success: true,
            data: result.rows[0]
        });
    } catch (err) {
        console.error('Erro ao buscar transação:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar transação',
            message: err.message
        });
    }
};

// Criar nova transação
exports.criarTransacao = async (req, res) => {
    try {
        const { descricao, valor, tipo, categoria_id, usuario_id, observacoes, tags } = req.body;
        
        // Validações básicas
        if (!descricao || !valor || !tipo) {
            return res.status(400).json({
                success: false,
                error: 'Campos obrigatórios: descricao, valor, tipo'
            });
        }
        
        if (!['C', 'D'].includes(tipo)) {
            return res.status(400).json({
                success: false,
                error: 'Tipo deve ser C (crédito) ou D (débito)'
            });
        }
        
        if (valor <= 0) {
            return res.status(400).json({
                success: false,
                error: 'Valor deve ser positivo'
            });
        }
        
        const result = await db.query(`
            INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, observacoes, tags, status)
            VALUES ($1, $2, $3, $4, $5, $6, $7, 'confirmada')
            RETURNING *
        `, [descricao, valor, tipo, categoria_id || null, usuario_id || null, observacoes || null, tags || null]);
        
        res.status(201).json({
            success: true,
            message: 'Transação criada com sucesso',
            data: result.rows[0]
        });
    } catch (err) {
        console.error('Erro ao criar transação:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao criar transação',
            message: err.message
        });
    }
};

// Consultar saldo atual
exports.consultarSaldo = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM vw_saldo_atual');
        
        res.json({
            success: true,
            data: result.rows[0]
        });
    } catch (err) {
        console.error('Erro ao consultar saldo:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao consultar saldo',
            message: err.message
        });
    }
};

// Relatório mensal
exports.relatorioMensal = async (req, res) => {
    try {
        const { mes, ano } = req.query;
        
        let query = 'SELECT * FROM vw_relatorio_mensal';
        const params = [];
        
        if (mes && ano) {
            query += ' WHERE EXTRACT(MONTH FROM mes) = $1 AND EXTRACT(YEAR FROM mes) = $2';
            params.push(mes, ano);
        }
        
        query += ' ORDER BY mes DESC, tipo, categoria';
        
        const result = await db.query(query, params);
        
        res.json({
            success: true,
            count: result.rows.length,
            data: result.rows
        });
    } catch (err) {
        console.error('Erro ao gerar relatório mensal:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao gerar relatório mensal',
            message: err.message
        });
    }
};

// Inserção em lote usando procedure
exports.inserirLote = async (req, res) => {
    try {
        const { transacoes } = req.body;
        
        if (!transacoes || !Array.isArray(transacoes) || transacoes.length === 0) {
            return res.status(400).json({
                success: false,
                error: 'Campo transacoes deve ser um array não vazio'
            });
        }
        
        // Chamar a stored procedure
        await db.query('CALL sp_inserir_lote_transacoes($1)', [JSON.stringify(transacoes)]);
        
        res.status(201).json({
            success: true,
            message: `Lote de ${transacoes.length} transações processado`,
            count: transacoes.length
        });
    } catch (err) {
        console.error('Erro ao inserir lote:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao inserir lote de transações',
            message: err.message
        });
    }
};

// Consolidação mensal usando procedure
exports.consolidarMes = async (req, res) => {
    try {
        const { ano, mes } = req.params;
        
        if (!ano || !mes) {
            return res.status(400).json({
                success: false,
                error: 'Parâmetros obrigatórios: ano e mes'
            });
        }
        
        const result = await db.query(`
            CALL sp_consolidar_mes($1, $2, NULL, NULL, NULL, NULL)
        `, [parseInt(ano), parseInt(mes)]);
        
        res.json({
            success: true,
            message: 'Consolidação mensal executada com sucesso'
        });
    } catch (err) {
        console.error('Erro ao consolidar mês:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao consolidar mês',
            message: err.message
        });
    }
};

// Buscar por tags usando function
exports.buscarPorTags = async (req, res) => {
    try {
        const { tags } = req.query;
        
        if (!tags) {
            return res.status(400).json({
                success: false,
                error: 'Parâmetro tags é obrigatório'
            });
        }
        
        const tagsArray = tags.split(',').map(t => t.trim());
        
        const result = await db.query(`
            SELECT * FROM fn_buscar_por_tags($1)
        `, [tagsArray]);
        
        res.json({
            success: true,
            count: result.rows.length,
            data: result.rows
        });
    } catch (err) {
        console.error('Erro ao buscar por tags:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar por tags',
            message: err.message
        });
    }
};

// Estatísticas de período usando function
exports.estatisticasPeriodo = async (req, res) => {
    try {
        const { data_inicio, data_fim } = req.query;
        
        if (!data_inicio || !data_fim) {
            return res.status(400).json({
                success: false,
                error: 'Parâmetros obrigatórios: data_inicio e data_fim'
            });
        }
        
        const result = await db.query(`
            SELECT * FROM fn_estatisticas_periodo($1, $2)
        `, [data_inicio, data_fim]);
        
        res.json({
            success: true,
            data: result.rows[0]
        });
    } catch (err) {
        console.error('Erro ao gerar estatísticas:', err);
        res.status(500).json({
            success: false,
            error: 'Erro ao gerar estatísticas',
            message: err.message
        });
    }
};

