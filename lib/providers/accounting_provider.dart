// lib/providers/accounting_provider.dart
// MODIFICAÇÃO: Ajustado para consumir a nova estrutura de dados unificada 'cash_flow_distribution'.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vitrine_borracharia/services/api_service.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/models/recurring_transaction.dart';
import '../services/api_modules/accounting/accounting_api_service.dart';

// Enum para o tipo de transação recorrente
enum RecurringTransactionType {
  income,
  expense,
}

class AccountingProvider with ChangeNotifier {
  final ApiService _apiService;
  final AccountingApiService _accountingApiService;

  Map<String, dynamic>? _dashboardSummary;
  List<AccountingCategory> _categories = [];
  List<RecurringTransaction> _recurringTransactions = [];

  bool _isLoadingSummary = false;
  bool _isLoadingCategories = false;
  bool _isLoadingRecurring = false;
  String? _errorMessage;

  // Controle de estado para pré-carregamento
  bool _isPreloading = false;
  bool get isPreloading => _isPreloading;

  AccountingProvider(ApiService apiService)
      : _apiService = apiService,
        _accountingApiService = apiService.accountingService;

  // Getters principais
  Map<String, dynamic>? get dashboardSummary => _dashboardSummary;
  List<AccountingCategory> get categories => _categories;
  List<RecurringTransaction> get recurringTransactions => _recurringTransactions;

  bool get isLoading => _isLoadingSummary || _isLoadingCategories || _isLoadingRecurring;
  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingRecurringTransactions => _isLoadingRecurring;

  String? get errorMessage => _errorMessage;

  // Getters adicionais para compatibilidade com as telas
  bool get isLoadingSummary => _isLoadingSummary;
  double get totalIncome => _dashboardSummary?['total_income']?.toDouble() ?? 0.0;
  double get totalExpenses => _dashboardSummary?['total_expenses']?.toDouble() ?? 0.0;
  double get balance => _dashboardSummary?['balance']?.toDouble() ?? 0.0;
  int get pendingPayments => _dashboardSummary?['pending_payments'] ?? 0;
  int get upcomingReceivables => _dashboardSummary?['upcoming_receivables'] ?? 0;
  
  // --- INÍCIO DA MODIFICAÇÃO ---
  
  // Getters para dados de gráficos
  List<dynamic> get monthlyTrend => _dashboardSummary?['monthly_trend'] ?? [];
  
  // NOVO GETTER UNIFICADO: Retorna a lista completa para o gráfico de pizza.
  List<dynamic> get cashFlowDistribution => _dashboardSummary?['cash_flow_distribution'] ?? [];

  // Getter antigo (marcado como obsoleto para referência, pode ser removido depois)
  @Deprecated('Use cashFlowDistribution. Este getter será removido em futuras versões.')
  List<dynamic> get expenseCategories => (_dashboardSummary?['cash_flow_distribution'] as List<dynamic>?)
      ?.where((item) => item['type'] == 'expense')
      .toList() ?? [];

  // --- FIM DA MODIFICAÇÃO ---

  // =======================================================================
  // === PRÉ-CARREGAMENTO INTELIGENTE ===
  // =======================================================================
  
  Future<void> preloadAccountingData() async {
    if (_isPreloading) {
      Logger.info('📊 [ACC_PROVIDER] Pré-carregamento já em andamento. Ignorando nova chamada.');
      return;
    }

    Logger.info('📊 [ACC_PROVIDER] Iniciando pré-carregamento de dados contábeis em segundo plano...');
    _isPreloading = true;
    
    await Future.wait([
      fetchDashboardSummary(isPreload: true),
      fetchAccountingCategories(isPreload: true),
      fetchRecurringTransactions(isPreload: true),
    ], eagerError: false);

    _isPreloading = false;
    Logger.info('📊 [ACC_PROVIDER] ✅ Pré-carregamento de dados contábeis finalizado.');
    notifyListeners();
  }

  // =======================================================================
  // === DASHBOARD SUMMARY ===
  // =======================================================================

  Future<void> fetchDashboardSummary({bool isPreload = false}) async {
    final logPrefix = isPreload ? '📊 [PRELOAD]' : '📈 [FETCH]';
    Logger.info('$logPrefix Iniciando busca do Resumo do Dashboard...');

    if (!isPreload) {
      _isLoadingSummary = true;
      notifyListeners();
    }
    
    _errorMessage = null;

    try {
      final Map<String, dynamic> summaryData = await _accountingApiService.getDashboardSummary();
      
      // --- INÍCIO DA MODIFICAÇÃO ---
      // Garantir que todos os campos esperados pela UI existam, incluindo o novo campo unificado.
      _dashboardSummary = {
        'balance': (summaryData['balance'] as num?)?.toDouble() ?? 0.0,
        'total_income': (summaryData['total_income'] as num?)?.toDouble() ?? 0.0,
        'total_expenses': (summaryData['total_expenses'] as num?)?.toDouble() ?? 0.0,
        'pending_payments': summaryData['pending_payments'] as int? ?? 0,
        'upcoming_receivables': summaryData['upcoming_receivables'] as int? ?? 0,
        
        // Campos para os gráficos
        'monthly_trend': (summaryData['monthly_trend'] as List<dynamic>?) ?? [],
        'cash_flow_distribution': (summaryData['cash_flow_distribution'] as List<dynamic>?) ?? [], // <<< CAMPO UNIFICADO
        
        // Métricas adicionais
        'avg_transaction_value': (summaryData['avg_transaction_value'] as num?)?.toDouble() ?? 0.0,
        'transaction_count': summaryData['transaction_count'] as int? ?? 0,
        'cash_flow_trend': summaryData['cash_flow_trend'] as String? ?? 'stable',
        'monthly_growth': (summaryData['monthly_growth'] as num?)?.toDouble() ?? 0.0,
      };
      // --- FIM DA MODIFICAÇÃO ---

      Logger.info('$logPrefix ✅ Resumo do dashboard carregado com sucesso.');
      Logger.debug('$logPrefix Dados do Resumo: Saldo R\$${_dashboardSummary?['balance']}');

    } catch (e) {
      _errorMessage = 'Erro ao carregar resumo do dashboard: ${e.toString()}';
      Logger.error('$logPrefix ❌ FALHA ao carregar resumo do dashboard.', error: e);
    } finally {
      if (!isPreload) {
        _isLoadingSummary = false;
      }
      notifyListeners();
    }
  }

  // =======================================================================
  // === CATEGORIAS DE CONTABILIDADE ===
  // =======================================================================

  Future<void> fetchAccountingCategories({bool isPreload = false}) async {
    final logPrefix = isPreload ? '📊 [PRELOAD]' : '📂 [FETCH]';
    Logger.info('$logPrefix Iniciando busca das Categorias Contábeis...');

    if (!isPreload) {
      _isLoadingCategories = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final List<dynamic> data = await _accountingApiService.getAccountingCategories();
      _categories = data.map((json) => AccountingCategory.fromJson(json)).toList();
      Logger.info('$logPrefix ✅ ${_categories.length} categorias contábeis carregadas.');
    } catch (e) {
      _errorMessage = 'Erro ao carregar categorias: ${e.toString()}';
      Logger.error('$logPrefix ❌ FALHA ao carregar categorias.', error: e);
    } finally {
      if (!isPreload) {
        _isLoadingCategories = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    return fetchAccountingCategories();
  }

  Future<void> createAccountingCategory(AccountingCategory category) async {
    _isLoadingCategories = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> newCategoryJson = await _accountingApiService.createAccountingCategory(category.toJson());
      final newCategory = AccountingCategory.fromJson(newCategoryJson);
      _categories.add(newCategory);
      Logger.info('AccountingProvider: Categoria de contabilidade criada com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao criar categoria de contabilidade: ${e.toString()}';
      Logger.error('AccountingProvider: $_errorMessage', error: e);
      rethrow;
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(String name, {String type = 'expense'}) async {
    final category = AccountingCategory(
      id: '',
      name: name,
      type: type,
      color: type == 'income' ? '#4CAF50' : '#F44336',
      emoji: type == 'income' ? '💰' : '💸',
    );
    return createAccountingCategory(category);
  }

  Future<void> updateAccountingCategory(AccountingCategory category) async {
    _isLoadingCategories = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _accountingApiService.updateAccountingCategory(category.id, category.toJson());
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
      }
      Logger.info('AccountingProvider: Categoria de contabilidade atualizada com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao atualizar categoria de contabilidade: ${e.toString()}';
      Logger.error('AccountingProvider: $_errorMessage', error: e);
      rethrow;
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> updateCategory(String categoryId, String name) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    final updatedCategory = category.copyWith(name: name);
    return updateAccountingCategory(updatedCategory);
  }

  Future<void> deleteAccountingCategory(String categoryId) async {
    _isLoadingCategories = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _accountingApiService.deleteAccountingCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
      Logger.info('AccountingProvider: Categoria de contabilidade deletada com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao deletar categoria de contabilidade: ${e.toString()}';
      Logger.error('AccountingProvider: $_errorMessage', error: e);
      rethrow;
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    return deleteAccountingCategory(categoryId);
  }

  // =======================================================================
  // === TRANSAÇÕES RECORRENTES ===
  // =======================================================================

  Future<void> fetchRecurringTransactions({bool isPreload = false}) async {
    final logPrefix = isPreload ? '📊 [PRELOAD]' : '🔁 [FETCH]';
    Logger.info('$logPrefix Iniciando busca de Transações Recorrentes...');

    if (!isPreload) {
      _isLoadingRecurring = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final List<dynamic> data = await _accountingApiService.getRecurringTransactions();
      _recurringTransactions = data.map((json) => RecurringTransaction.fromJson(json)).toList();
      Logger.info('$logPrefix ✅ ${_recurringTransactions.length} transações recorrentes carregadas.');
    } catch (e) {
      _errorMessage = 'Erro ao carregar transações recorrentes: ${e.toString()}';
      Logger.error('$logPrefix ❌ FALHA ao carregar transações recorrentes.', error: e);
    } finally {
      if (!isPreload) {
        _isLoadingRecurring = false;
      }
      notifyListeners();
    }
  }

  Future<void> createRecurringTransaction(RecurringTransaction transaction) async {
    _isLoadingRecurring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> newTransactionJson = await _accountingApiService.createRecurringTransaction(transaction.toJson());
      final newTransaction = RecurringTransaction.fromJson(newTransactionJson);
      _recurringTransactions.add(newTransaction);
      Logger.info('AccountingProvider: Transação recorrente criada com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao criar transação recorrente: ${e.toString()}';
      Logger.error('AccountingProvider: $_errorMessage', error: e);
      rethrow;
    } finally {
      _isLoadingRecurring = false;
      notifyListeners();
    }
  }

  Future<void> addRecurringTransaction(
    String description,
    double amount,
    RecurringTransactionType type,
    String categoryId,
    RecurringFrequency frequency,
  ) async {
    final transaction = RecurringTransaction(
      id: '',
      description: description,
      amount: amount,
      type: type == RecurringTransactionType.income ? 'income' : 'expense',
      frequency: frequency,
      startDate: DateTime.now(),
      categoryId: categoryId,
    );
    return createRecurringTransaction(transaction);
  }

  Future<void> updateRecurringTransaction(RecurringTransaction transaction) async {
    _isLoadingRecurring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _accountingApiService.updateRecurringTransaction(transaction.id, transaction.toJson());
      final index = _recurringTransactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _recurringTransactions[index] = transaction;
      }
      Logger.info('AccountingProvider: Transação recorrente atualizada com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao atualizar transação recorrente: ${e.toString()}';
      Logger.error('AccountingProvider: $_errorMessage', error: e);
      rethrow;
    } finally {
      _isLoadingRecurring = false;
      notifyListeners();
    }
  }

  Future<void> deleteRecurringTransaction(String transactionId) async {
    _isLoadingRecurring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _accountingApiService.deleteRecurringTransaction(transactionId);
      _recurringTransactions.removeWhere((t) => t.id == transactionId);
      Logger.info('AccountingProvider: Transação recorrente deletada com sucesso.');
    } catch (e) {
      _errorMessage = 'Erro ao deletar transação recorrente: ${e.toString()}';
      Logger.error('AccountingProvider: $_errorMessage', error: e);
      rethrow;
    } finally {
      _isLoadingRecurring = false;
      notifyListeners();
    }
  }

  // =======================================================================
  // === PROCESSAMENTO DE DOCUMENTOS (IMPORTAÇÃO) ===
  // =======================================================================

  Future<Map<String, dynamic>> processDocument({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String context = 'business',
  }) async {
    final logPrefix = '📄 [IMPORT]';
    Logger.info('$logPrefix Iniciando processamento do documento: $fileName');
    _errorMessage = null;

    try {
      final Map<String, dynamic> result = await _accountingApiService.processDocument(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
        context: context,
      );

      if (result['success'] == true) {
        Logger.info('$logPrefix ✅ Documento processado com sucesso pela API.');
        Logger.debug('$logPrefix Resposta da API: $result');
        return result;
      } else {
        final error = result['error'] ?? 'Erro desconhecido retornado pela API.';
        _errorMessage = 'Falha no processamento: $error';
        Logger.error('$logPrefix ❌ FALHA no processamento do documento: $error');
        return {'success': false, 'error': _errorMessage};
      }
    } catch (e) {
      _errorMessage = 'Erro ao se comunicar com o serviço de importação: ${e.toString()}';
      Logger.error('$logPrefix ❌ ERRO CRÍTICO ao processar documento.', error: e);
      return {'success': false, 'error': _errorMessage};
    }
  }

  // =======================================================================
  // === MÉTODOS UTILITÁRIOS ===
  // =======================================================================

  void clearAllData() {
    _dashboardSummary = null;
    _categories = [];
    _recurringTransactions = [];
    _isLoadingSummary = false;
    _isLoadingCategories = false;
    _isLoadingRecurring = false;
    _errorMessage = null;
    _isPreloading = false;
    notifyListeners();
  }

  AccountingCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      Logger.warning('AccountingProvider: Categoria com ID $categoryId não encontrada.');
      return null;
    }
  }

  List<AccountingCategory> getCategoriesByType(String type) {
    return _categories.where((c) => c.type == type).toList();
  }

  bool get hasData {
    return _dashboardSummary != null || _categories.isNotEmpty || _recurringTransactions.isNotEmpty;
  }
}
