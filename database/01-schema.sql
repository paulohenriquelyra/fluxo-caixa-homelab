-- ============================================
-- Fluxo de Caixa - Schema Database
-- PostgreSQL 15
-- ============================================

-- Criar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Tabela: usuarios
-- ============================================
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE usuarios IS 'Tabela de usuários do sistema';
COMMENT ON COLUMN usuarios.id IS 'Identificador único do usuário';
COMMENT ON COLUMN usuarios.nome IS 'Nome completo do usuário';
COMMENT ON COLUMN usuarios.email IS 'Email único do usuário';
COMMENT ON COLUMN usuarios.ativo IS 'Indica se o usuário está ativo no sistema';

-- ============================================
-- Tabela: categorias
-- ============================================
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50) NOT NULL UNIQUE,
    tipo CHAR(1) NOT NULL CHECK (tipo IN ('C', 'D')),
    descricao TEXT,
    cor VARCHAR(7) DEFAULT '#000000',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE categorias IS 'Categorias de transações (receitas e despesas)';
COMMENT ON COLUMN categorias.tipo IS 'Tipo da categoria: C (Crédito/Receita) ou D (Débito/Despesa)';
COMMENT ON COLUMN categorias.cor IS 'Cor hexadecimal para visualização';

-- ============================================
-- Tabela: transacoes
-- ============================================
CREATE TABLE IF NOT EXISTS transacoes (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    valor NUMERIC(12, 2) NOT NULL CHECK (valor > 0),
    tipo CHAR(1) NOT NULL CHECK (tipo IN ('C', 'D')),
    categoria_id INTEGER REFERENCES categorias(id) ON DELETE SET NULL,
    usuario_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
    data_transacao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    observacoes TEXT,
    tags VARCHAR(100)[],
    anexo_url VARCHAR(500),
    status VARCHAR(20) DEFAULT 'confirmada' CHECK (status IN ('pendente', 'confirmada', 'cancelada')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE transacoes IS 'Tabela principal de transações financeiras';
COMMENT ON COLUMN transacoes.uuid IS 'Identificador único universal da transação';
COMMENT ON COLUMN transacoes.tipo IS 'Tipo da transação: C (Crédito/Receita) ou D (Débito/Despesa)';
COMMENT ON COLUMN transacoes.valor IS 'Valor da transação (sempre positivo)';
COMMENT ON COLUMN transacoes.tags IS 'Array de tags para classificação adicional';
COMMENT ON COLUMN transacoes.status IS 'Status da transação: pendente, confirmada ou cancelada';

-- ============================================
-- Índices para Performance
-- ============================================

-- Índices na tabela transacoes
CREATE INDEX idx_transacoes_data ON transacoes(data_transacao DESC);
CREATE INDEX idx_transacoes_tipo ON transacoes(tipo);
CREATE INDEX idx_transacoes_usuario ON transacoes(usuario_id);
CREATE INDEX idx_transacoes_categoria ON transacoes(categoria_id);
CREATE INDEX idx_transacoes_status ON transacoes(status);
CREATE INDEX idx_transacoes_data_tipo ON transacoes(data_transacao DESC, tipo);
CREATE INDEX idx_transacoes_uuid ON transacoes(uuid);

-- Índice GIN para busca em arrays de tags
CREATE INDEX idx_transacoes_tags ON transacoes USING GIN(tags);

-- Índices na tabela usuarios
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_ativo ON usuarios(ativo);

-- Índices na tabela categorias
CREATE INDEX idx_categorias_tipo ON categorias(tipo);
CREATE INDEX idx_categorias_nome ON categorias(nome);

-- ============================================
-- Triggers para atualização automática
-- ============================================

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para tabela usuarios
CREATE TRIGGER trigger_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger para tabela transacoes
CREATE TRIGGER trigger_transacoes_updated_at
    BEFORE UPDATE ON transacoes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Constraints adicionais
-- ============================================

-- Garantir que categoria_id seja válida quando informada
ALTER TABLE transacoes 
    ADD CONSTRAINT fk_transacoes_categoria 
    FOREIGN KEY (categoria_id) 
    REFERENCES categorias(id) 
    ON DELETE SET NULL;

-- Garantir que usuario_id seja válido quando informado
ALTER TABLE transacoes 
    ADD CONSTRAINT fk_transacoes_usuario 
    FOREIGN KEY (usuario_id) 
    REFERENCES usuarios(id) 
    ON DELETE SET NULL;

-- ============================================
-- Estatísticas e Otimizações
-- ============================================

-- Analisar tabelas para otimizar planos de execução
ANALYZE usuarios;
ANALYZE categorias;
ANALYZE transacoes;

-- Mensagem de conclusão
DO $$
BEGIN
    RAISE NOTICE 'Schema criado com sucesso!';
    RAISE NOTICE 'Tabelas: usuarios, categorias, transacoes';
    RAISE NOTICE 'Índices: 11 índices criados';
    RAISE NOTICE 'Triggers: 2 triggers de atualização automática';
END $$;

