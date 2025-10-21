# Documentação da API - Fluxo de Caixa

## Base URL

```
http://fluxo-caixa.local/api
```

## Autenticação

Atualmente a API não requer autenticação (ambiente de laboratório).

---

## Endpoints

### 1. Health Check

Verifica o status da aplicação.

**Endpoint:** `GET /health`

**Resposta de Sucesso (200):**
```json
{
  "status": "OK",
  "timestamp": "2025-01-21T10:30:00.000Z",
  "uptime": 3600,
  "environment": "production",
  "version": "1.0.0"
}
```

---

### 2. Listar Transações

Lista todas as transações com paginação.

**Endpoint:** `GET /api/transacoes`

**Query Parameters:**
- `limit` (opcional): Número de registros por página (padrão: 50)
- `offset` (opcional): Offset para paginação (padrão: 0)
- `tipo` (opcional): Filtrar por tipo (C ou D)
- `status` (opcional): Filtrar por status (confirmada, pendente, cancelada)

**Exemplo:**
```bash
GET /api/transacoes?limit=10&offset=0&tipo=C&status=confirmada
```

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "count": 10,
  "data": [
    {
      "id": 1,
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "descricao": "Salário Mensal",
      "valor": 5000.00,
      "tipo": "C",
      "data_transacao": "2025-01-05T00:00:00.000Z",
      "status": "confirmada",
      "observacoes": null,
      "tags": ["salario", "mensal"],
      "categoria": "Salário",
      "usuario": "João Silva"
    }
  ]
}
```

---

### 3. Buscar Transação por ID

Busca uma transação específica pelo ID.

**Endpoint:** `GET /api/transacoes/:id`

**Exemplo:**
```bash
GET /api/transacoes/1
```

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "descricao": "Salário Mensal",
    "valor": 5000.00,
    "tipo": "C",
    "categoria": "Salário",
    "usuario": "João Silva",
    "usuario_email": "joao.silva@email.com"
  }
}
```

**Resposta de Erro (404):**
```json
{
  "success": false,
  "error": "Transação não encontrada"
}
```

---

### 4. Criar Transação

Cria uma nova transação.

**Endpoint:** `POST /api/transacoes`

**Body (JSON):**
```json
{
  "descricao": "Freelance Projeto X",
  "valor": 2500.00,
  "tipo": "C",
  "categoria_id": 2,
  "usuario_id": 1,
  "observacoes": "Projeto de website",
  "tags": ["freelance", "web"]
}
```

**Campos Obrigatórios:**
- `descricao` (string): Descrição da transação
- `valor` (number): Valor da transação (positivo)
- `tipo` (string): Tipo da transação (C = Crédito, D = Débito)

**Campos Opcionais:**
- `categoria_id` (integer): ID da categoria
- `usuario_id` (integer): ID do usuário
- `observacoes` (string): Observações adicionais
- `tags` (array): Array de tags

**Resposta de Sucesso (201):**
```json
{
  "success": true,
  "message": "Transação criada com sucesso",
  "data": {
    "id": 51,
    "uuid": "550e8400-e29b-41d4-a716-446655440001",
    "descricao": "Freelance Projeto X",
    "valor": 2500.00,
    "tipo": "C",
    "status": "confirmada"
  }
}
```

---

### 5. Consultar Saldo Atual

Retorna o saldo atual consolidado (usa VIEW).

**Endpoint:** `GET /api/transacoes/consultas/saldo`

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "data": {
    "saldo_total": 15350.50,
    "total_transacoes": 48,
    "transacoes_confirmadas": 45,
    "transacoes_pendentes": 2,
    "transacoes_canceladas": 1,
    "total_creditos": 32500.00,
    "total_debitos": 17149.50,
    "valor_medio_transacao": 685.32,
    "ultima_transacao": "2025-01-21T10:00:00.000Z",
    "primeira_transacao": "2024-10-21T10:00:00.000Z"
  }
}
```

---

### 6. Relatório Mensal

Retorna relatório mensal detalhado (usa VIEW).

**Endpoint:** `GET /api/transacoes/consultas/relatorio-mensal`

**Query Parameters:**
- `mes` (opcional): Mês (1-12)
- `ano` (opcional): Ano (ex: 2025)

**Exemplo:**
```bash
GET /api/transacoes/consultas/relatorio-mensal?mes=1&ano=2025
```

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "count": 12,
  "data": [
    {
      "mes": "2025-01-01",
      "mes_ano": "2025-01",
      "mes_extenso": "January 2025",
      "tipo": "C",
      "tipo_descricao": "Crédito",
      "categoria": "Salário",
      "categoria_cor": "#4CAF50",
      "quantidade_transacoes": 2,
      "total": 10000.00,
      "media": 5000.00,
      "valor_minimo": 4500.00,
      "valor_maximo": 5500.00,
      "desvio_padrao": 500.00,
      "usuarios_distintos": 2,
      "total_confirmado": 10000.00,
      "total_pendente": 0
    }
  ]
}
```

---

### 7. Inserção em Lote

Insere múltiplas transações em lote (usa PROCEDURE).

**Endpoint:** `POST /api/transacoes/lote`

**Body (JSON):**
```json
{
  "transacoes": [
    {
      "descricao": "Transação 1",
      "valor": 100.00,
      "tipo": "C",
      "categoria_id": 1,
      "usuario_id": 1
    },
    {
      "descricao": "Transação 2",
      "valor": 200.00,
      "tipo": "D",
      "categoria_id": 6,
      "usuario_id": 1
    }
  ]
}
```

**Resposta de Sucesso (201):**
```json
{
  "success": true,
  "message": "Lote de 2 transações processado",
  "count": 2
}
```

---

### 8. Consolidação Mensal

Executa consolidação mensal (usa PROCEDURE).

**Endpoint:** `POST /api/transacoes/consolidar/:ano/:mes`

**Exemplo:**
```bash
POST /api/transacoes/consolidar/2025/1
```

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "message": "Consolidação mensal executada com sucesso"
}
```

---

### 9. Buscar por Tags

Busca transações por tags (usa FUNCTION).

**Endpoint:** `GET /api/transacoes/consultas/tags`

**Query Parameters:**
- `tags` (obrigatório): Tags separadas por vírgula

**Exemplo:**
```bash
GET /api/transacoes/consultas/tags?tags=salario,mensal
```

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "count": 3,
  "data": [
    {
      "id": 1,
      "descricao": "Salário Mensal",
      "valor": 5000.00,
      "tipo": "C",
      "data_transacao": "2025-01-05T00:00:00.000Z",
      "tags_encontradas": ["salario", "mensal"],
      "qtd_tags_match": 2
    }
  ]
}
```

---

### 10. Estatísticas de Período

Retorna estatísticas de um período (usa FUNCTION).

**Endpoint:** `GET /api/transacoes/consultas/estatisticas`

**Query Parameters:**
- `data_inicio` (obrigatório): Data inicial (YYYY-MM-DD)
- `data_fim` (obrigatório): Data final (YYYY-MM-DD)

**Exemplo:**
```bash
GET /api/transacoes/consultas/estatisticas?data_inicio=2025-01-01&data_fim=2025-01-31
```

**Resposta de Sucesso (200):**
```json
{
  "success": true,
  "data": {
    "total_transacoes": 15,
    "total_creditos": 12500.00,
    "total_debitos": 5800.00,
    "saldo_periodo": 6700.00,
    "media_transacao": 1220.00,
    "maior_credito": 5000.00,
    "maior_debito": 1500.00,
    "dias_com_transacoes": 12,
    "transacoes_por_dia": 1.25
  }
}
```

---

## Códigos de Status HTTP

| Código | Descrição |
|--------|-----------|
| 200 | Sucesso |
| 201 | Criado com sucesso |
| 400 | Requisição inválida |
| 404 | Recurso não encontrado |
| 500 | Erro interno do servidor |

---

## Exemplos de Uso com cURL

### Criar transação
```bash
curl -X POST http://fluxo-caixa.local/api/transacoes \
  -H "Content-Type: application/json" \
  -d '{
    "descricao": "Teste",
    "valor": 100.00,
    "tipo": "C"
  }'
```

### Consultar saldo
```bash
curl http://fluxo-caixa.local/api/transacoes/consultas/saldo
```

### Listar transações
```bash
curl http://fluxo-caixa.local/api/transacoes?limit=10
```

---

## Observações

- Todas as respostas são em formato JSON
- Timestamps estão em formato ISO 8601 (UTC)
- Valores monetários são em formato decimal com 2 casas decimais
- A API não requer autenticação (ambiente de laboratório)

