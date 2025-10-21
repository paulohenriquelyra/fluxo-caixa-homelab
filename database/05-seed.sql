-- ============================================
-- Fluxo de Caixa - Seed Data
-- PostgreSQL 15
-- ============================================

-- ============================================
-- Inserir Usuários
-- ============================================
INSERT INTO usuarios (nome, email, ativo) VALUES
('João Silva', 'joao.silva@email.com', true),
('Maria Santos', 'maria.santos@email.com', true),
('Pedro Oliveira', 'pedro.oliveira@email.com', true),
('Ana Costa', 'ana.costa@email.com', true),
('Carlos Souza', 'carlos.souza@email.com', false)
ON CONFLICT (email) DO NOTHING;

RAISE NOTICE 'Usuários inseridos: 5';

-- ============================================
-- Inserir Categorias
-- ============================================

-- Categorias de Crédito (Receitas)
INSERT INTO categorias (nome, tipo, descricao, cor) VALUES
('Salário', 'C', 'Salário mensal', '#4CAF50'),
('Freelance', 'C', 'Trabalhos freelance', '#8BC34A'),
('Investimentos', 'C', 'Rendimentos de investimentos', '#CDDC39'),
('Vendas', 'C', 'Vendas de produtos ou serviços', '#FFC107'),
('Outros Créditos', 'C', 'Outras receitas', '#FF9800')
ON CONFLICT (nome) DO NOTHING;

-- Categorias de Débito (Despesas)
INSERT INTO categorias (nome, tipo, descricao, cor) VALUES
('Moradia', 'D', 'Aluguel, condomínio, IPTU', '#F44336'),
('Alimentação', 'D', 'Supermercado, restaurantes', '#E91E63'),
('Transporte', 'D', 'Combustível, transporte público', '#9C27B0'),
('Saúde', 'D', 'Plano de saúde, medicamentos', '#673AB7'),
('Educação', 'D', 'Cursos, livros, mensalidades', '#3F51B5'),
('Lazer', 'D', 'Entretenimento, viagens', '#2196F3'),
('Contas', 'D', 'Água, luz, internet, telefone', '#00BCD4'),
('Vestuário', 'D', 'Roupas, calçados', '#009688'),
('Outros Débitos', 'D', 'Outras despesas', '#795548')
ON CONFLICT (nome) DO NOTHING;

RAISE NOTICE 'Categorias inseridas: 14 (5 créditos + 9 débitos)';

-- ============================================
-- Inserir Transações de Teste
-- ============================================

-- Obter IDs de categorias e usuários
DO $$
DECLARE
    v_cat_salario INTEGER;
    v_cat_freelance INTEGER;
    v_cat_investimentos INTEGER;
    v_cat_moradia INTEGER;
    v_cat_alimentacao INTEGER;
    v_cat_transporte INTEGER;
    v_cat_saude INTEGER;
    v_cat_educacao INTEGER;
    v_cat_lazer INTEGER;
    v_cat_contas INTEGER;
    v_user1 INTEGER;
    v_user2 INTEGER;
    v_user3 INTEGER;
    v_data_base DATE;
BEGIN
    -- Buscar IDs de categorias
    SELECT id INTO v_cat_salario FROM categorias WHERE nome = 'Salário';
    SELECT id INTO v_cat_freelance FROM categorias WHERE nome = 'Freelance';
    SELECT id INTO v_cat_investimentos FROM categorias WHERE nome = 'Investimentos';
    SELECT id INTO v_cat_moradia FROM categorias WHERE nome = 'Moradia';
    SELECT id INTO v_cat_alimentacao FROM categorias WHERE nome = 'Alimentação';
    SELECT id INTO v_cat_transporte FROM categorias WHERE nome = 'Transporte';
    SELECT id INTO v_cat_saude FROM categorias WHERE nome = 'Saúde';
    SELECT id INTO v_cat_educacao FROM categorias WHERE nome = 'Educação';
    SELECT id INTO v_cat_lazer FROM categorias WHERE nome = 'Lazer';
    SELECT id INTO v_cat_contas FROM categorias WHERE nome = 'Contas';
    
    -- Buscar IDs de usuários
    SELECT id INTO v_user1 FROM usuarios WHERE email = 'joao.silva@email.com';
    SELECT id INTO v_user2 FROM usuarios WHERE email = 'maria.santos@email.com';
    SELECT id INTO v_user3 FROM usuarios WHERE email = 'pedro.oliveira@email.com';
    
    -- Data base para as transações (3 meses atrás)
    v_data_base := CURRENT_DATE - INTERVAL '90 days';
    
    -- ========================================
    -- Mês 1 (3 meses atrás)
    -- ========================================
    
    -- Salários
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Salário Mensal', 5000.00, 'C', v_cat_salario, v_user1, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'confirmada'),
    ('Salário Mensal', 4500.00, 'C', v_cat_salario, v_user2, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'confirmada');
    
    -- Freelance
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Projeto Website Cliente X', 2500.00, 'C', v_cat_freelance, v_user1, v_data_base + INTERVAL '10 days', ARRAY['freelance', 'web'], 'confirmada');
    
    -- Despesas Fixas
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Aluguel', 1500.00, 'D', v_cat_moradia, v_user1, v_data_base + INTERVAL '1 day', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Condomínio', 350.00, 'D', v_cat_moradia, v_user1, v_data_base + INTERVAL '1 day', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Conta de Luz', 180.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Conta de Água', 85.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Internet', 120.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Plano de Saúde', 450.00, 'D', v_cat_saude, v_user1, v_data_base + INTERVAL '15 days', ARRAY['fixo', 'mensal'], 'confirmada');
    
    -- Despesas Variáveis
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Supermercado', 650.00, 'D', v_cat_alimentacao, v_user1, v_data_base + INTERVAL '7 days', ARRAY['supermercado'], 'confirmada'),
    ('Restaurante', 120.00, 'D', v_cat_alimentacao, v_user1, v_data_base + INTERVAL '12 days', ARRAY['restaurante'], 'confirmada'),
    ('Combustível', 350.00, 'D', v_cat_transporte, v_user1, v_data_base + INTERVAL '3 days', ARRAY['carro'], 'confirmada'),
    ('Cinema', 80.00, 'D', v_cat_lazer, v_user1, v_data_base + INTERVAL '20 days', ARRAY['entretenimento'], 'confirmada');
    
    -- ========================================
    -- Mês 2 (2 meses atrás)
    -- ========================================
    
    v_data_base := v_data_base + INTERVAL '30 days';
    
    -- Salários
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Salário Mensal', 5000.00, 'C', v_cat_salario, v_user1, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'confirmada'),
    ('Salário Mensal', 4500.00, 'C', v_cat_salario, v_user2, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'confirmada');
    
    -- Investimentos
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Rendimento Tesouro Direto', 250.00, 'C', v_cat_investimentos, v_user1, v_data_base + INTERVAL '1 day', ARRAY['investimento', 'renda-fixa'], 'confirmada');
    
    -- Despesas Fixas
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Aluguel', 1500.00, 'D', v_cat_moradia, v_user1, v_data_base + INTERVAL '1 day', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Condomínio', 350.00, 'D', v_cat_moradia, v_user1, v_data_base + INTERVAL '1 day', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Conta de Luz', 195.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Conta de Água', 90.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Internet', 120.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Plano de Saúde', 450.00, 'D', v_cat_saude, v_user1, v_data_base + INTERVAL '15 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Curso Online AWS', 350.00, 'D', v_cat_educacao, v_user1, v_data_base + INTERVAL '10 days', ARRAY['educacao', 'tecnologia'], 'confirmada');
    
    -- Despesas Variáveis
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Supermercado', 720.00, 'D', v_cat_alimentacao, v_user1, v_data_base + INTERVAL '7 days', ARRAY['supermercado'], 'confirmada'),
    ('Restaurante', 95.00, 'D', v_cat_alimentacao, v_user1, v_data_base + INTERVAL '14 days', ARRAY['restaurante'], 'confirmada'),
    ('Farmácia', 85.00, 'D', v_cat_saude, v_user1, v_data_base + INTERVAL '18 days', ARRAY['medicamentos'], 'confirmada'),
    ('Combustível', 380.00, 'D', v_cat_transporte, v_user1, v_data_base + INTERVAL '3 days', ARRAY['carro'], 'confirmada'),
    ('Streaming', 45.00, 'D', v_cat_lazer, v_user1, v_data_base + INTERVAL '1 day', ARRAY['assinatura'], 'confirmada');
    
    -- ========================================
    -- Mês 3 (mês passado)
    -- ========================================
    
    v_data_base := v_data_base + INTERVAL '30 days';
    
    -- Salários
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Salário Mensal', 5000.00, 'C', v_cat_salario, v_user1, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'confirmada'),
    ('Salário Mensal', 4500.00, 'C', v_cat_salario, v_user2, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'confirmada'),
    ('Bônus Trimestral', 1500.00, 'C', v_cat_salario, v_user1, v_data_base + INTERVAL '25 days', ARRAY['bonus'], 'confirmada');
    
    -- Freelance
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Consultoria Terraform', 3000.00, 'C', v_cat_freelance, v_user3, v_data_base + INTERVAL '15 days', ARRAY['freelance', 'cloud'], 'confirmada');
    
    -- Despesas Fixas
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Aluguel', 1500.00, 'D', v_cat_moradia, v_user1, v_data_base + INTERVAL '1 day', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Condomínio', 350.00, 'D', v_cat_moradia, v_user1, v_data_base + INTERVAL '1 day', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Conta de Luz', 210.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Conta de Água', 95.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Internet', 120.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '8 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Plano de Saúde', 450.00, 'D', v_cat_saude, v_user1, v_data_base + INTERVAL '15 days', ARRAY['fixo', 'mensal'], 'confirmada');
    
    -- Despesas Variáveis
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Supermercado', 680.00, 'D', v_cat_alimentacao, v_user1, v_data_base + INTERVAL '7 days', ARRAY['supermercado'], 'confirmada'),
    ('Restaurante', 150.00, 'D', v_cat_alimentacao, v_user1, v_data_base + INTERVAL '12 days', ARRAY['restaurante'], 'confirmada'),
    ('Combustível', 400.00, 'D', v_cat_transporte, v_user1, v_data_base + INTERVAL '3 days', ARRAY['carro'], 'confirmada'),
    ('Viagem Final de Semana', 850.00, 'D', v_cat_lazer, v_user1, v_data_base + INTERVAL '20 days', ARRAY['viagem'], 'confirmada'),
    ('Livros Técnicos', 180.00, 'D', v_cat_educacao, v_user1, v_data_base + INTERVAL '18 days', ARRAY['livros', 'tecnologia'], 'confirmada');
    
    -- ========================================
    -- Mês Atual
    -- ========================================
    
    v_data_base := CURRENT_DATE;
    
    -- Transações do mês atual
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Aluguel', 1500.00, 'D', v_cat_moradia, v_user1, v_data_base - INTERVAL '5 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Condomínio', 350.00, 'D', v_cat_moradia, v_user1, v_data_base - INTERVAL '5 days', ARRAY['fixo', 'mensal'], 'confirmada'),
    ('Supermercado', 320.00, 'D', v_cat_alimentacao, v_user1, v_data_base - INTERVAL '3 days', ARRAY['supermercado'], 'confirmada'),
    ('Combustível', 200.00, 'D', v_cat_transporte, v_user1, v_data_base - INTERVAL '2 days', ARRAY['carro'], 'confirmada'),
    ('Freelance Projeto Y', 1800.00, 'C', v_cat_freelance, v_user2, v_data_base - INTERVAL '1 day', ARRAY['freelance'], 'confirmada');
    
    -- Transações pendentes
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status)
    VALUES 
    ('Salário Mensal (Pendente)', 5000.00, 'C', v_cat_salario, v_user1, v_data_base + INTERVAL '5 days', ARRAY['salario', 'mensal'], 'pendente'),
    ('Conta de Luz (Pendente)', 200.00, 'D', v_cat_contas, v_user1, v_data_base + INTERVAL '10 days', ARRAY['fixo', 'mensal'], 'pendente');
    
    -- Transação cancelada (exemplo)
    INSERT INTO transacoes (descricao, valor, tipo, categoria_id, usuario_id, data_transacao, tags, status, observacoes)
    VALUES 
    ('Compra Cancelada', 500.00, 'D', v_cat_lazer, v_user1, v_data_base - INTERVAL '7 days', ARRAY['cancelado'], 'cancelada', 'Compra cancelada pelo vendedor');
    
    RAISE NOTICE 'Transações inseridas: ~50 transações de teste';
    RAISE NOTICE 'Período: últimos 3 meses + mês atual';
    RAISE NOTICE 'Status: confirmadas, pendentes e canceladas';
END $$;

-- ============================================
-- Estatísticas Finais
-- ============================================
DO $$
DECLARE
    v_total_usuarios INTEGER;
    v_total_categorias INTEGER;
    v_total_transacoes INTEGER;
    v_saldo_atual NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_total_usuarios FROM usuarios;
    SELECT COUNT(*) INTO v_total_categorias FROM categorias;
    SELECT COUNT(*) INTO v_total_transacoes FROM transacoes;
    SELECT saldo_total INTO v_saldo_atual FROM vw_saldo_atual;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SEED DATA - RESUMO FINAL';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Usuários cadastrados: %', v_total_usuarios;
    RAISE NOTICE 'Categorias cadastradas: %', v_total_categorias;
    RAISE NOTICE 'Transações inseridas: %', v_total_transacoes;
    RAISE NOTICE 'Saldo Atual: R$ %', TO_CHAR(v_saldo_atual, 'FM999,999,999.00');
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Banco de dados pronto para uso!';
    RAISE NOTICE '========================================';
END $$;

