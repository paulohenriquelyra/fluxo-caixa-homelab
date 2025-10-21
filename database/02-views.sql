-- ============================================
-- Fluxo de Caixa - Views
-- PostgreSQL 15
-- ============================================

-- ============================================
-- View 1: Saldo Atual Consolidado
-- ============================================
CREATE OR REPLACE VIEW vw_saldo_atual AS
SELECT 
    SUM(CASE 
        WHEN tipo = 'C' AND status = 'confirmada' THEN valor 
        WHEN tipo = 'D' AND status = 'confirmada' THEN -valor 
        ELSE 0 
    END) as saldo_total,
    COUNT(*) as total_transacoes,
    COUNT(*) FILTER (WHERE status = 'confirmada') as transacoes_confirmadas,
    COUNT(*) FILTER (WHERE status = 'pendente') as transacoes_pendentes,
    COUNT(*) FILTER (WHERE status = 'cancelada') as transacoes_canceladas,
    SUM(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE 0 END) as total_creditos,
    SUM(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE 0 END) as total_debitos,
    AVG(CASE WHEN status = 'confirmada' THEN valor ELSE NULL END) as valor_medio_transacao,
    MAX(data_transacao) as ultima_transacao,
    MIN(data_transacao) as primeira_transacao
FROM transacoes;

COMMENT ON VIEW vw_saldo_atual IS 'Visão consolidada do saldo atual e estatísticas gerais';

-- ============================================
-- View 2: Relatório Mensal Detalhado
-- ============================================
CREATE OR REPLACE VIEW vw_relatorio_mensal AS
SELECT 
    DATE_TRUNC('month', data_transacao)::DATE as mes,
    TO_CHAR(data_transacao, 'YYYY-MM') as mes_ano,
    TO_CHAR(data_transacao, 'Month YYYY') as mes_extenso,
    tipo,
    CASE 
        WHEN tipo = 'C' THEN 'Crédito'
        WHEN tipo = 'D' THEN 'Débito'
        ELSE 'Indefinido'
    END as tipo_descricao,
    c.nome as categoria,
    c.cor as categoria_cor,
    COUNT(*) as quantidade_transacoes,
    SUM(t.valor) as total,
    AVG(t.valor) as media,
    MIN(t.valor) as valor_minimo,
    MAX(t.valor) as valor_maximo,
    STDDEV(t.valor) as desvio_padrao,
    COUNT(DISTINCT t.usuario_id) as usuarios_distintos,
    SUM(CASE WHEN t.status = 'confirmada' THEN t.valor ELSE 0 END) as total_confirmado,
    SUM(CASE WHEN t.status = 'pendente' THEN t.valor ELSE 0 END) as total_pendente
FROM transacoes t
LEFT JOIN categorias c ON t.categoria_id = c.id
WHERE t.status IN ('confirmada', 'pendente')
GROUP BY 
    DATE_TRUNC('month', data_transacao),
    TO_CHAR(data_transacao, 'YYYY-MM'),
    TO_CHAR(data_transacao, 'Month YYYY'),
    tipo,
    c.nome,
    c.cor
ORDER BY mes DESC, tipo, categoria;

COMMENT ON VIEW vw_relatorio_mensal IS 'Relatório mensal detalhado com agregações por categoria e tipo';

-- ============================================
-- View 3: Top Transações por Categoria
-- ============================================
CREATE OR REPLACE VIEW vw_top_transacoes AS
WITH ranked_transactions AS (
    SELECT 
        t.id,
        t.uuid,
        t.descricao,
        t.valor,
        t.tipo,
        CASE 
            WHEN t.tipo = 'C' THEN 'Crédito'
            WHEN t.tipo = 'D' THEN 'Débito'
            ELSE 'Indefinido'
        END as tipo_descricao,
        c.nome as categoria,
        c.cor as categoria_cor,
        t.data_transacao,
        u.nome as usuario_nome,
        u.email as usuario_email,
        t.observacoes,
        t.tags,
        RANK() OVER (
            PARTITION BY t.categoria_id, t.tipo 
            ORDER BY t.valor DESC
        ) as ranking_categoria,
        RANK() OVER (
            PARTITION BY t.tipo 
            ORDER BY t.valor DESC
        ) as ranking_geral,
        PERCENT_RANK() OVER (
            PARTITION BY t.categoria_id 
            ORDER BY t.valor
        ) as percentil_categoria
    FROM transacoes t
    LEFT JOIN categorias c ON t.categoria_id = c.id
    LEFT JOIN usuarios u ON t.usuario_id = u.id
    WHERE t.status = 'confirmada'
      AND t.categoria_id IS NOT NULL
)
SELECT 
    id,
    uuid,
    descricao,
    valor,
    tipo,
    tipo_descricao,
    categoria,
    categoria_cor,
    data_transacao,
    usuario_nome,
    usuario_email,
    observacoes,
    tags,
    ranking_categoria,
    ranking_geral,
    ROUND(percentil_categoria::numeric, 4) as percentil_categoria
FROM ranked_transactions
WHERE ranking_categoria <= 10
ORDER BY categoria, tipo, ranking_categoria;

COMMENT ON VIEW vw_top_transacoes IS 'Top 10 maiores transações por categoria com rankings e percentis';

-- ============================================
-- View 4: Análise de Categorias
-- ============================================
CREATE OR REPLACE VIEW vw_analise_categorias AS
SELECT 
    c.id as categoria_id,
    c.nome as categoria,
    c.tipo,
    CASE 
        WHEN c.tipo = 'C' THEN 'Crédito'
        WHEN c.tipo = 'D' THEN 'Débito'
        ELSE 'Indefinido'
    END as tipo_descricao,
    c.cor,
    COUNT(t.id) as total_transacoes,
    COALESCE(SUM(t.valor), 0) as valor_total,
    COALESCE(AVG(t.valor), 0) as valor_medio,
    COALESCE(MIN(t.valor), 0) as valor_minimo,
    COALESCE(MAX(t.valor), 0) as valor_maximo,
    MAX(t.data_transacao) as ultima_utilizacao,
    COUNT(DISTINCT t.usuario_id) as usuarios_distintos,
    ROUND(
        (COUNT(t.id)::NUMERIC / NULLIF(SUM(COUNT(t.id)) OVER (), 0)) * 100, 
        2
    ) as percentual_uso
FROM categorias c
LEFT JOIN transacoes t ON c.id = t.categoria_id AND t.status = 'confirmada'
GROUP BY c.id, c.nome, c.tipo, c.cor
ORDER BY valor_total DESC;

COMMENT ON VIEW vw_analise_categorias IS 'Análise completa de uso e valores por categoria';

-- ============================================
-- View 5: Fluxo de Caixa Diário
-- ============================================
CREATE OR REPLACE VIEW vw_fluxo_diario AS
WITH daily_flow AS (
    SELECT 
        DATE(data_transacao) as data,
        SUM(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE 0 END) as entradas,
        SUM(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE 0 END) as saidas,
        SUM(CASE 
            WHEN tipo = 'C' AND status = 'confirmada' THEN valor 
            WHEN tipo = 'D' AND status = 'confirmada' THEN -valor 
            ELSE 0 
        END) as saldo_dia,
        COUNT(*) FILTER (WHERE tipo = 'C') as qtd_entradas,
        COUNT(*) FILTER (WHERE tipo = 'D') as qtd_saidas
    FROM transacoes
    GROUP BY DATE(data_transacao)
)
SELECT 
    data,
    entradas,
    saidas,
    saldo_dia,
    SUM(saldo_dia) OVER (ORDER BY data ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as saldo_acumulado,
    qtd_entradas,
    qtd_saidas,
    TO_CHAR(data, 'Day') as dia_semana,
    EXTRACT(DOW FROM data) as dia_semana_numero
FROM daily_flow
ORDER BY data DESC;

COMMENT ON VIEW vw_fluxo_diario IS 'Fluxo de caixa diário com saldo acumulado';

-- ============================================
-- View 6: Usuários Mais Ativos
-- ============================================
CREATE OR REPLACE VIEW vw_usuarios_ativos AS
SELECT 
    u.id as usuario_id,
    u.nome,
    u.email,
    u.ativo,
    COUNT(t.id) as total_transacoes,
    SUM(CASE WHEN t.tipo = 'C' AND t.status = 'confirmada' THEN t.valor ELSE 0 END) as total_creditos,
    SUM(CASE WHEN t.tipo = 'D' AND t.status = 'confirmada' THEN t.valor ELSE 0 END) as total_debitos,
    SUM(CASE 
        WHEN t.tipo = 'C' AND t.status = 'confirmada' THEN t.valor 
        WHEN t.tipo = 'D' AND t.status = 'confirmada' THEN -t.valor 
        ELSE 0 
    END) as saldo_usuario,
    MAX(t.data_transacao) as ultima_transacao,
    MIN(t.data_transacao) as primeira_transacao,
    COUNT(DISTINCT t.categoria_id) as categorias_utilizadas,
    ROUND(AVG(t.valor), 2) as valor_medio_transacao
FROM usuarios u
LEFT JOIN transacoes t ON u.id = t.usuario_id
GROUP BY u.id, u.nome, u.email, u.ativo
ORDER BY total_transacoes DESC;

COMMENT ON VIEW vw_usuarios_ativos IS 'Análise de atividade e estatísticas por usuário';

-- ============================================
-- Mensagem de conclusão
-- ============================================
DO $$
BEGIN
    RAISE NOTICE 'Views criadas com sucesso!';
    RAISE NOTICE '- vw_saldo_atual: Saldo consolidado';
    RAISE NOTICE '- vw_relatorio_mensal: Relatório mensal detalhado';
    RAISE NOTICE '- vw_top_transacoes: Top 10 por categoria com window functions';
    RAISE NOTICE '- vw_analise_categorias: Análise de uso de categorias';
    RAISE NOTICE '- vw_fluxo_diario: Fluxo de caixa diário com acumulado';
    RAISE NOTICE '- vw_usuarios_ativos: Estatísticas por usuário';
END $$;

