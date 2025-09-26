import 'package:flutter/material.dart';
import 'package:vitrine_borracharia/models/recurring_transaction.dart';
import 'package:vitrine_borracharia/services/api_service.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/models/transaction.dart';
import '../services/api_modules/transactions/transaction_api_service.dart';

class TransactionProvider with ChangeNotifier {
  final ApiService _apiService;
  final TransactionApiService _transactionApiService;

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  TransactionProvider(ApiService apiService)
      : _apiService = apiService,
        _transactionApiService = apiService.transactionService;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchTransactions() async {
    Logger.info('💰 [TX_PROVIDER] Iniciando busca de transações...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<dynamic> data = await _transactionApiService.getTransactions();
      _transactions = data.map((json) => Transaction.fromJson(json)).toList();
      Logger.info('💰 [TX_PROVIDER] ✅ ${_transactions.length} transações carregadas com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao carregar transações: ${e.toString()}';
      Logger.error('💰 [TX_PROVIDER] ❌ FALHA ao carregar transações.', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTransaction(Map<String, dynamic> transactionData) async {
    Logger.info('💰 [TX_PROVIDER] Tentando criar nova transação: "${transactionData['description']}"...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> newTransactionJson = await _transactionApiService.createTransaction(transactionData);
      final newTransaction = Transaction.fromJson(newTransactionJson);
      _transactions.insert(0, newTransaction);
      Logger.info('💰 [TX_PROVIDER] ✅ Transação criada com sucesso (ID: ${newTransaction.id}).');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao criar transação: ${e.toString()}';
      Logger.error('💰 [TX_PROVIDER] ❌ FALHA ao criar transação.', error: e);
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTransaction(Transaction transaction) async {
    Logger.info('💰 [TX_PROVIDER] Tentando atualizar transação ID: ${transaction.id}...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
        notifyListeners();
      }

      await _transactionApiService.updateTransaction(transaction.id, transaction.toJson());
      Logger.info('💰 [TX_PROVIDER] ✅ Transação atualizada com sucesso no backend.');
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar transação: ${e.toString()}';
      Logger.error('💰 [TX_PROVIDER] ❌ FALHA ao atualizar transação.', error: e);
      fetchTransactions();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // <<< CORREÇÃO PRINCIPAL APLICADA AQUI: Lógica de exclusão otimista >>>
  Future<bool> deleteTransaction(String transactionId) async {
    final logPrefix = '🗑️ [DELETE]';
    Logger.info('$logPrefix Tentando deletar transação ID: $transactionId...');
    
    // 1. Encontra a transação e seu índice na lista.
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) {
      Logger.warning('$logPrefix Tentativa de deletar transação que não está na lista local. Abortando.');
      _errorMessage = 'Transação não encontrada para deletar.';
      notifyListeners();
      return false;
    }
    
    // Guarda uma cópia da transação para possível rollback.
    final transactionToRemove = _transactions[index];
    
    // 2. (Otimismo) Remove a transação da lista local IMEDIATAMENTE.
    _transactions.removeAt(index);
    _errorMessage = null; // Limpa erros antigos para não confundir o usuário.
    Logger.info('$logPrefix Removido da UI. Notificando listeners...');
    notifyListeners(); // Notifica a UI para remover o item da tela.
    
    Logger.info('$logPrefix Chamando API para deletar no backend...');

    try {
      // 3. Tenta deletar no backend.
      await _transactionApiService.deleteTransaction(transactionId);
      Logger.info('$logPrefix ✅ Transação deletada com sucesso no backend.');
      return true; // Sucesso total.
    } catch (e) {
      _errorMessage = 'Erro ao deletar. A transação foi restaurada.';
      Logger.error('$logPrefix ❌ FALHA ao deletar no backend. Iniciando rollback...', error: e);
      
      // 4. (Rollback) Se a API falhar, adiciona a transação de volta na lista.
      _transactions.insert(index, transactionToRemove);
      Logger.info('$logPrefix Transação restaurada na lista local.');
      notifyListeners(); // Notifica a UI para re-exibir o item e a mensagem de erro.
      
      return false; // Falha.
    }
  }

  Future<List<RecurringTransaction>> fetchRecurringTransactions() async {
    Logger.info('💰 [TX_PROVIDER] Iniciando busca de transações RECORRENTES...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<dynamic> data = await _transactionApiService.getRecurringTransactions();
      final recurring = data.map((json) => RecurringTransaction.fromJson(json)).toList();
      Logger.info('💰 [TX_PROVIDER] ✅ ${recurring.length} transações recorrentes carregadas.');

      _isLoading = false;
      notifyListeners();
      return recurring;
    } catch (e) {
      _errorMessage = 'Erro ao carregar transações recorrentes: ${e.toString()}';
      Logger.error('💰 [TX_PROVIDER] ❌ FALHA ao carregar transações recorrentes.', error: e);
      _isLoading = false;
      notifyListeners();
      throw Exception('Erro interno: ${e.toString()}');
    }
  }

  void clearAllData() {
    _transactions = [];
    _isLoading = false;
    _errorMessage = null;
    Logger.info('💰 [TX_PROVIDER] Todos os dados de transações foram limpos.');
    notifyListeners();
  }
}
