-- ============================================
-- Fluxo de Caixa - Stored Procedures
-- PostgreSQL 15
-- ============================================

-- ============================================
-- Procedure 1: Adicionar Transação com Validação
-- ============================================
CREATE OR REPLACE PROCEDURE sp_adicionar_transacao(
    p_descricao VARCHAR,
    p_valor NUMERIC,
    p_tipo CHAR,
    p_categoria_id INTEGER DEFAULT NULL,
    p_usuario_id INTEGER DEFAULT NULL,
    p_observacoes TEXT DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL,
    p_data_transacao TIMESTAMP DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transacao_id INTEGER;
    v_categoria_tipo CHAR;
BEGIN
    -- Validação: Descrição não pode ser vazia
    IF p_descricao IS NULL OR TRIM(p_descricao) = '' THEN
        RAISE EXCEPTION 'Descrição não pode ser vazia';
    END IF;
    
    -- Validação: Valor deve ser positivo
    IF p_valor IS NULL OR p_valor <= 0 THEN
        RAISE EXCEPTION 'Valor deve ser positivo. Valor informado: %', p_valor;
    END IF;
    
    -- Validação: Tipo deve ser C ou D
    IF p_tipo NOT IN ('C', 'D') THEN
        RAISE EXCEPTION 'Tipo deve ser C (crédito) ou D (débito). Tipo informado: %', p_tipo;
    END IF;
    
    -- Validação: Se categoria informada, verificar se existe e se o tipo é compatível
    IF p_categoria_id IS NOT NULL THEN
        SELECT tipo INTO v_categoria_tipo
        FROM categorias
        WHERE id = p_categoria_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Categoria com ID % não encontrada', p_categoria_id;
        END IF;
        
        IF v_categoria_tipo != p_tipo THEN
            RAISE WARNING 'Tipo da transação (%) não corresponde ao tipo da categoria (%)', p_tipo, v_categoria_tipo;
        END IF;
    END IF;
    
    -- Validação: Se usuário informado, verificar se existe e está ativo
    IF p_usuario_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id AND ativo = true) THEN
            RAISE EXCEPTION 'Usuário com ID % não encontrado ou inativo', p_usuario_id;
        END IF;
    END IF;
    
    -- Inserção da transação
    INSERT INTO transacoes (
        descricao, 
        valor, 
        tipo, 
        categoria_id, 
        usuario_id, 
        observacoes, 
        tags,
        data_transacao,
        status
    )
    VALUES (
        TRIM(p_descricao),
        p_valor,
        p_tipo,
        p_categoria_id,
        p_usuario_id,
        p_observacoes,
        p_tags,
        COALESCE(p_data_transacao, CURRENT_TIMESTAMP),
        'confirmada'
    )
    RETURNING id INTO v_transacao_id;
    
    RAISE NOTICE 'Transação ID % adicionada com sucesso. Valor: %, Tipo: %', 
                 v_transacao_id, p_valor, p_tipo;
    
    -- Log de auditoria (simulado)
    RAISE NOTICE 'Auditoria: Usuário % criou transação %', 
                 COALESCE(p_usuario_id::TEXT, 'Sistema'), v_transacao_id;
END;
$$;

COMMENT ON PROCEDURE sp_adicionar_transacao IS 'Adiciona uma nova transação com validações completas';

-- ============================================
-- Procedure 2: Inserção em Lote de Transações
-- ============================================
CREATE OR REPLACE PROCEDURE sp_inserir_lote_transacoes(
    p_transacoes JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transacao JSONB;
    v_count INTEGER := 0;
    v_errors INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_error_msg TEXT;
BEGIN
    v_start_time := CLOCK_TIMESTAMP();
    
    -- Validação: JSON não pode ser nulo ou vazio
    IF p_transacoes IS NULL OR jsonb_array_length(p_transacoes) = 0 THEN
        RAISE EXCEPTION 'Array de transações não pode ser nulo ou vazio';
    END IF;
    
    RAISE NOTICE 'Iniciando inserção em lote de % transações', jsonb_array_length(p_transacoes);
    
    -- Iterar sobre cada transação no array JSON
    FOR v_transacao IN SELECT * FROM jsonb_array_elements(p_transacoes)
    LOOP
        BEGIN
            -- Inserir transação usando a procedure de validação
            CALL sp_adicionar_transacao(
                p_descricao := v_transacao->>'descricao',
                p_valor := (v_transacao->>'valor')::NUMERIC,
                p_tipo := v_transacao->>'tipo',
                p_categoria_id := (v_transacao->>'categoria_id')::INTEGER,
                p_usuario_id := (v_transacao->>'usuario_id')::INTEGER,
                p_observacoes := v_transacao->>'observacoes',
                p_tags := CASE 
                    WHEN v_transacao->'tags' IS NOT NULL 
                    THEN ARRAY(SELECT jsonb_array_elements_text(v_transacao->'tags'))
                    ELSE NULL 
                END,
                p_data_transacao := (v_transacao->>'data_transacao')::TIMESTAMP
            );
            
            v_count := v_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_errors := v_errors + 1;
                v_error_msg := SQLERRM;
                RAISE WARNING 'Erro ao inserir transação: %. Dados: %', v_error_msg, v_transacao;
        END;
    END LOOP;
    
    v_end_time := CLOCK_TIMESTAMP();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Inserção em lote concluída';
    RAISE NOTICE 'Total processado: %', jsonb_array_length(p_transacoes);
    RAISE NOTICE 'Inseridas com sucesso: %', v_count;
    RAISE NOTICE 'Erros: %', v_errors;
    RAISE NOTICE 'Tempo de execução: % ms', 
                 EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
    RAISE NOTICE '========================================';
    
    -- Se houver muitos erros, lançar exceção
    IF v_errors > (jsonb_array_length(p_transacoes) * 0.5) THEN
        RAISE EXCEPTION 'Mais de 50%% das transações falharam. Verifique os dados.';
    END IF;
END;
$$;

COMMENT ON PROCEDURE sp_inserir_lote_transacoes IS 'Insere múltiplas transações em lote a partir de um array JSON';

-- ============================================
-- Procedure 3: Consolidação Mensal
-- ============================================
CREATE OR REPLACE PROCEDURE sp_consolidar_mes(
    p_ano INTEGER,
    p_mes INTEGER,
    OUT o_total_creditos NUMERIC,
    OUT o_total_debitos NUMERIC,
    OUT o_saldo NUMERIC,
    OUT o_qtd_transacoes INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_data_inicio DATE;
    v_data_fim DATE;
    v_qtd_creditos INTEGER;
    v_qtd_debitos INTEGER;
BEGIN
    -- Validação: Ano válido
    IF p_ano < 2000 OR p_ano > 2100 THEN
        RAISE EXCEPTION 'Ano inválido: %. Deve estar entre 2000 e 2100', p_ano;
    END IF;
    
    -- Validação: Mês válido
    IF p_mes < 1 OR p_mes > 12 THEN
        RAISE EXCEPTION 'Mês inválido: %. Deve estar entre 1 e 12', p_mes;
    END IF;
    
    -- Calcular intervalo de datas
    v_data_inicio := make_date(p_ano, p_mes, 1);
    v_data_fim := (v_data_inicio + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    
    RAISE NOTICE 'Consolidando período: % a %', v_data_inicio, v_data_fim;
    
    -- Calcular totais
    SELECT 
        COALESCE(SUM(CASE WHEN tipo = 'C' AND status = 'confirmada' THEN valor ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN tipo = 'D' AND status = 'confirmada' THEN valor ELSE 0 END), 0),
        COUNT(*) FILTER (WHERE tipo = 'C' AND status = 'confirmada'),
        COUNT(*) FILTER (WHERE tipo = 'D' AND status = 'confirmada'),
        COUNT(*) FILTER (WHERE status = 'confirmada')
    INTO 
        o_total_creditos,
        o_total_debitos,
        v_qtd_creditos,
        v_qtd_debitos,
        o_qtd_transacoes
    FROM transacoes
    WHERE DATE(data_transacao) BETWEEN v_data_inicio AND v_data_fim;
    
    -- Calcular saldo
    o_saldo := o_total_creditos - o_total_debitos;
    
    -- Relatório detalhado
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CONSOLIDAÇÃO MENSAL - %/%', LPAD(p_mes::TEXT, 2, '0'), p_ano;
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Período: % a %', v_data_inicio, v_data_fim;
    RAISE NOTICE '----------------------------------------';
    RAISE NOTICE 'CRÉDITOS (Receitas)';
    RAISE NOTICE '  Quantidade: %', v_qtd_creditos;
    RAISE NOTICE '  Total: R$ %', TO_CHAR(o_total_creditos, 'FM999,999,999.00');
    RAISE NOTICE '----------------------------------------';
    RAISE NOTICE 'DÉBITOS (Despesas)';
    RAISE NOTICE '  Quantidade: %', v_qtd_debitos;
    RAISE NOTICE '  Total: R$ %', TO_CHAR(o_total_debitos, 'FM999,999,999.00');
    RAISE NOTICE '----------------------------------------';
    RAISE NOTICE 'SALDO DO PERÍODO';
    RAISE NOTICE '  Saldo: R$ %', TO_CHAR(o_saldo, 'FM999,999,999.00');
    RAISE NOTICE '  Total de Transações: %', o_qtd_transacoes;
    RAISE NOTICE '========================================';
    
    -- Análise adicional
    IF o_saldo < 0 THEN
        RAISE WARNING 'ATENÇÃO: Saldo negativo no período!';
    END IF;
    
    IF o_qtd_transacoes = 0 THEN
        RAISE WARNING 'Nenhuma transação confirmada encontrada no período';
    END IF;
END;
$$;

COMMENT ON PROCEDURE sp_consolidar_mes IS 'Consolida e exibe relatório financeiro de um mês específico';

-- ============================================
-- Procedure 4: Cancelar Transação
-- ============================================
CREATE OR REPLACE PROCEDURE sp_cancelar_transacao(
    p_transacao_id INTEGER,
    p_motivo TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transacao_record RECORD;
BEGIN
    -- Buscar transação
    SELECT * INTO v_transacao_record
    FROM transacoes
    WHERE id = p_transacao_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transação com ID % não encontrada', p_transacao_id;
    END IF;
    
    -- Verificar se já está cancelada
    IF v_transacao_record.status = 'cancelada' THEN
        RAISE EXCEPTION 'Transação % já está cancelada', p_transacao_id;
    END IF;
    
    -- Atualizar status
    UPDATE transacoes
    SET 
        status = 'cancelada',
        observacoes = CASE 
            WHEN observacoes IS NULL THEN 'CANCELADA: ' || COALESCE(p_motivo, 'Sem motivo informado')
            ELSE observacoes || E'\n\nCANCELADA: ' || COALESCE(p_motivo, 'Sem motivo informado')
        END,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_transacao_id;
    
    RAISE NOTICE 'Transação % cancelada com sucesso', p_transacao_id;
    RAISE NOTICE 'Descrição: %', v_transacao_record.descricao;
    RAISE NOTICE 'Valor: %', v_transacao_record.valor;
    RAISE NOTICE 'Motivo: %', COALESCE(p_motivo, 'Não informado');
END;
$$;

COMMENT ON PROCEDURE sp_cancelar_transacao IS 'Cancela uma transação existente com registro de motivo';

-- ============================================
-- Procedure 5: Recalcular Estatísticas
-- ============================================
CREATE OR REPLACE PROCEDURE sp_recalcular_estatisticas()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    v_start_time := CLOCK_TIMESTAMP();
    
    RAISE NOTICE 'Iniciando recálculo de estatísticas...';
    
    -- Atualizar estatísticas das tabelas
    ANALYZE usuarios;
    ANALYZE categorias;
    ANALYZE transacoes;
    
    -- Reindexar tabelas (opcional, pode ser demorado)
    REINDEX TABLE usuarios;
    REINDEX TABLE categorias;
    REINDEX TABLE transacoes;
    
    v_end_time := CLOCK_TIMESTAMP();
    
    RAISE NOTICE 'Estatísticas recalculadas com sucesso';
    RAISE NOTICE 'Tempo de execução: % ms', 
                 EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
END;
$$;

COMMENT ON PROCEDURE sp_recalcular_estatisticas IS 'Recalcula estatísticas e reindexar tabelas para otimização';

-- ============================================
-- Mensagem de conclusão
-- ============================================
DO $$
BEGIN
    RAISE NOTICE 'Stored Procedures criadas com sucesso!';
    RAISE NOTICE '- sp_adicionar_transacao: Adiciona transação com validações';
    RAISE NOTICE '- sp_inserir_lote_transacoes: Inserção em lote via JSON';
    RAISE NOTICE '- sp_consolidar_mes: Consolidação mensal com relatório';
    RAISE NOTICE '- sp_cancelar_transacao: Cancelamento de transação';
    RAISE NOTICE '- sp_recalcular_estatisticas: Otimização de performance';
END $$;

