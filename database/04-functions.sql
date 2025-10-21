-- ============================================
-- Fluxo de Caixa - Functions
-- PostgreSQL 15
-- ============================================

-- ============================================
-- Function 1: Calcular Saldo em Data Específica
-- ============================================
CREATE OR REPLACE FUNCTION fn_saldo_em_data(
    p_data TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
    saldo_total NUMERIC,
    total_creditos NUMERIC,
    total_debitos NUMERIC,
    qtd_transacoes INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE 
            WHEN tipo = 'C' AND status = 'confirmada' THEN valor 
            WHEN tipo = 'D' AND status = 'confirmada' THEN -valor 
            ELSE 0 
        END), 0) as saldo_total,
        COALESCE(SUM(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE 0 END), 0) as total_creditos,
        COALESCE(SUM(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE 0 END), 0) as total_debitos,
        COUNT(*)::INTEGER as qtd_transacoes
    FROM transacoes
    WHERE data_transacao <= p_data;
END;
$$;

COMMENT ON FUNCTION fn_saldo_em_data IS 'Calcula o saldo acumulado até uma data específica';

-- ============================================
-- Function 2: Categoria Mais Usada por Usuário
-- ============================================
CREATE OR REPLACE FUNCTION fn_categoria_favorita(
    p_usuario_id INTEGER
)
RETURNS TABLE (
    categoria_id INTEGER,
    categoria_nome VARCHAR,
    quantidade_usos BIGINT,
    valor_total NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verificar se usuário existe
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id) THEN
        RAISE EXCEPTION 'Usuário com ID % não encontrado', p_usuario_id;
    END IF;
    
    RETURN QUERY
    SELECT 
        c.id as categoria_id,
        c.nome as categoria_nome,
        COUNT(t.id) as quantidade_usos,
        SUM(t.valor) as valor_total
    FROM transacoes t
    INNER JOIN categorias c ON t.categoria_id = c.id
    WHERE t.usuario_id = p_usuario_id
      AND t.status = 'confirmada'
      AND t.categoria_id IS NOT NULL
    GROUP BY c.id, c.nome
    ORDER BY COUNT(t.id) DESC, SUM(t.valor) DESC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION fn_categoria_favorita IS 'Retorna a categoria mais utilizada por um usuário específico';

-- ============================================
-- Function 3: Projeção de Saldo Futuro
-- ============================================
CREATE OR REPLACE FUNCTION fn_projecao_saldo(
    p_meses_futuros INTEGER DEFAULT 3
)
RETURNS TABLE (
    mes_projecao DATE,
    saldo_atual NUMERIC,
    media_mensal_creditos NUMERIC,
    media_mensal_debitos NUMERIC,
    saldo_projetado NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo_atual NUMERIC;
    v_media_creditos NUMERIC;
    v_media_debitos NUMERIC;
    v_mes INTEGER;
BEGIN
    -- Calcular saldo atual
    SELECT COALESCE(SUM(CASE 
        WHEN tipo = 'C' AND status = 'confirmada' THEN valor 
        WHEN tipo = 'D' AND status = 'confirmada' THEN -valor 
        ELSE 0 
    END), 0)
    INTO v_saldo_atual
    FROM transacoes;
    
    -- Calcular médias mensais dos últimos 6 meses
    SELECT 
        COALESCE(AVG(monthly_credits), 0),
        COALESCE(AVG(monthly_debits), 0)
    INTO v_media_creditos, v_media_debitos
    FROM (
        SELECT 
            DATE_TRUNC('month', data_transacao) as month,
            SUM(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE 0 END) as monthly_credits,
            SUM(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE 0 END) as monthly_debits
        FROM transacoes
        WHERE data_transacao >= CURRENT_DATE - INTERVAL '6 months'
        GROUP BY DATE_TRUNC('month', data_transacao)
    ) monthly_data;
    
    -- Gerar projeções
    FOR v_mes IN 1..p_meses_futuros LOOP
        mes_projecao := (DATE_TRUNC('month', CURRENT_DATE) + (v_mes || ' months')::INTERVAL)::DATE;
        saldo_atual := v_saldo_atual;
        media_mensal_creditos := v_media_creditos;
        media_mensal_debitos := v_media_debitos;
        saldo_projetado := v_saldo_atual + (v_mes * (v_media_creditos - v_media_debitos));
        
        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_projecao_saldo IS 'Projeta o saldo futuro baseado nas médias mensais dos últimos 6 meses';

-- ============================================
-- Function 4: Validar Integridade de Transação
-- ============================================
CREATE OR REPLACE FUNCTION fn_validar_transacao(
    p_descricao VARCHAR,
    p_valor NUMERIC,
    p_tipo CHAR,
    p_categoria_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    valido BOOLEAN,
    mensagem TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_categoria_tipo CHAR;
BEGIN
    -- Validação 1: Descrição
    IF p_descricao IS NULL OR TRIM(p_descricao) = '' THEN
        valido := FALSE;
        mensagem := 'Descrição não pode ser vazia';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validação 2: Valor
    IF p_valor IS NULL OR p_valor <= 0 THEN
        valido := FALSE;
        mensagem := 'Valor deve ser positivo';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validação 3: Tipo
    IF p_tipo NOT IN ('C', 'D') THEN
        valido := FALSE;
        mensagem := 'Tipo deve ser C (crédito) ou D (débito)';
        RETURN NEXT;
        RETURN;
    END IF;
    
    -- Validação 4: Categoria (se informada)
    IF p_categoria_id IS NOT NULL THEN
        SELECT tipo INTO v_categoria_tipo
        FROM categorias
        WHERE id = p_categoria_id;
        
        IF NOT FOUND THEN
            valido := FALSE;
            mensagem := 'Categoria não encontrada';
            RETURN NEXT;
            RETURN;
        END IF;
        
        IF v_categoria_tipo != p_tipo THEN
            valido := FALSE;
            mensagem := 'Tipo da transação não corresponde ao tipo da categoria';
            RETURN NEXT;
            RETURN;
        END IF;
    END IF;
    
    -- Todas as validações passaram
    valido := TRUE;
    mensagem := 'Transação válida';
    RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION fn_validar_transacao IS 'Valida os dados de uma transação antes da inserção';

-- ============================================
-- Function 5: Calcular Percentual de Categoria
-- ============================================
CREATE OR REPLACE FUNCTION fn_percentual_categoria(
    p_categoria_id INTEGER,
    p_data_inicio DATE DEFAULT NULL,
    p_data_fim DATE DEFAULT NULL
)
RETURNS TABLE (
    categoria_nome VARCHAR,
    valor_categoria NUMERIC,
    valor_total NUMERIC,
    percentual NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_data_inicio DATE;
    v_data_fim DATE;
BEGIN
    -- Definir intervalo de datas
    v_data_inicio := COALESCE(p_data_inicio, DATE_TRUNC('month', CURRENT_DATE)::DATE);
    v_data_fim := COALESCE(p_data_fim, CURRENT_DATE);
    
    -- Verificar se categoria existe
    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id = p_categoria_id) THEN
        RAISE EXCEPTION 'Categoria com ID % não encontrada', p_categoria_id;
    END IF;
    
    RETURN QUERY
    WITH totals AS (
        SELECT 
            c.nome,
            SUM(CASE WHEN t.categoria_id = p_categoria_id THEN t.valor ELSE 0 END) as cat_value,
            SUM(t.valor) as total_value
        FROM transacoes t
        LEFT JOIN categorias c ON c.id = p_categoria_id
        WHERE t.status = 'confirmada'
          AND DATE(t.data_transacao) BETWEEN v_data_inicio AND v_data_fim
        GROUP BY c.nome
    )
    SELECT 
        totals.nome as categoria_nome,
        totals.cat_value as valor_categoria,
        totals.total_value as valor_total,
        CASE 
            WHEN totals.total_value > 0 THEN ROUND((totals.cat_value / totals.total_value) * 100, 2)
            ELSE 0
        END as percentual
    FROM totals;
END;
$$;

COMMENT ON FUNCTION fn_percentual_categoria IS 'Calcula o percentual de uma categoria em relação ao total em um período';

-- ============================================
-- Function 6: Buscar Transações por Tags
-- ============================================
CREATE OR REPLACE FUNCTION fn_buscar_por_tags(
    p_tags VARCHAR[]
)
RETURNS TABLE (
    id INTEGER,
    descricao VARCHAR,
    valor NUMERIC,
    tipo CHAR,
    data_transacao TIMESTAMP WITH TIME ZONE,
    tags_encontradas VARCHAR[],
    qtd_tags_match INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.descricao,
        t.valor,
        t.tipo,
        t.data_transacao,
        t.tags as tags_encontradas,
        (SELECT COUNT(*) FROM unnest(t.tags) tag WHERE tag = ANY(p_tags))::INTEGER as qtd_tags_match
    FROM transacoes t
    WHERE t.tags && p_tags  -- Operador de overlap de arrays
      AND t.status = 'confirmada'
    ORDER BY 
        (SELECT COUNT(*) FROM unnest(t.tags) tag WHERE tag = ANY(p_tags)) DESC,
        t.data_transacao DESC;
END;
$$;

COMMENT ON FUNCTION fn_buscar_por_tags IS 'Busca transações que contenham qualquer uma das tags especificadas';

-- ============================================
-- Function 7: Estatísticas de Período
-- ============================================
CREATE OR REPLACE FUNCTION fn_estatisticas_periodo(
    p_data_inicio DATE,
    p_data_fim DATE
)
RETURNS TABLE (
    total_transacoes INTEGER,
    total_creditos NUMERIC,
    total_debitos NUMERIC,
    saldo_periodo NUMERIC,
    media_transacao NUMERIC,
    maior_credito NUMERIC,
    maior_debito NUMERIC,
    dias_com_transacoes INTEGER,
    transacoes_por_dia NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_transacoes,
        COALESCE(SUM(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE 0 END), 0) as total_creditos,
        COALESCE(SUM(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE 0 END), 0) as total_debitos,
        COALESCE(SUM(CASE 
            WHEN tipo = 'C' AND status = 'confirmada' THEN valor 
            WHEN tipo = 'D' AND status = 'confirmada' THEN -valor 
            ELSE 0 
        END), 0) as saldo_periodo,
        COALESCE(AVG(CASE WHEN status = 'confirmada' THEN valor ELSE NULL END), 0) as media_transacao,
        COALESCE(MAX(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE NULL END), 0) as maior_credito,
        COALESCE(MAX(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE NULL END), 0) as maior_debito,
        COUNT(DISTINCT DATE(data_transacao))::INTEGER as dias_com_transacoes,
        CASE 
            WHEN COUNT(DISTINCT DATE(data_transacao)) > 0 
            THEN ROUND(COUNT(*)::NUMERIC / COUNT(DISTINCT DATE(data_transacao)), 2)
            ELSE 0 
        END as transacoes_por_dia
    FROM transacoes
    WHERE DATE(data_transacao) BETWEEN p_data_inicio AND p_data_fim;
END;
$$;

COMMENT ON FUNCTION fn_estatisticas_periodo IS 'Retorna estatísticas completas de um período específico';

-- ============================================
-- Mensagem de conclusão
-- ============================================
DO $$
BEGIN
    RAISE NOTICE 'Functions criadas com sucesso!';
    RAISE NOTICE '- fn_saldo_em_data: Saldo em data específica';
    RAISE NOTICE '- fn_categoria_favorita: Categoria mais usada por usuário';
    RAISE NOTICE '- fn_projecao_saldo: Projeção de saldo futuro';
    RAISE NOTICE '- fn_validar_transacao: Validação de dados';
    RAISE NOTICE '- fn_percentual_categoria: Percentual de categoria no período';
    RAISE NOTICE '- fn_buscar_por_tags: Busca por tags';
    RAISE NOTICE '- fn_estatisticas_periodo: Estatísticas de período';
END $$;

