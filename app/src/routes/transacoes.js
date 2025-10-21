const express = require('express');
const router = express.Router();
const transacoesController = require('../controllers/transacoesController');

// Rotas de transações
router.get('/', transacoesController.listarTransacoes);
router.get('/:id', transacoesController.buscarTransacao);
router.post('/', transacoesController.criarTransacao);
router.post('/lote', transacoesController.inserirLote);

// Rotas de consultas e relatórios
router.get('/consultas/saldo', transacoesController.consultarSaldo);
router.get('/consultas/relatorio-mensal', transacoesController.relatorioMensal);
router.get('/consultas/tags', transacoesController.buscarPorTags);
router.get('/consultas/estatisticas', transacoesController.estatisticasPeriodo);

// Rota de consolidação
router.post('/consolidar/:ano/:mes', transacoesController.consolidarMes);

module.exports = router;

