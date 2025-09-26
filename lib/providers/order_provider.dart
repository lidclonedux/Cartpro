// lib/providers/order_provider.dart - VERSÃO CORRIGIDA DO LOOP INFINITO

import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import 'product_provider.dart';
import '../utils/logger.dart';

class OrderProvider with ChangeNotifier {
  final ApiService? apiService;
  final ProductProvider? productProvider;
  
  bool _disposed = false;
  
  OrderProvider(this.apiService, this.productProvider);
  
  List<Order> _orders = [];
  List<Order> _userOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => _disposed ? [] : _orders;
  List<Order> get userOrders => _disposed ? [] : _userOrders;
  bool get isLoading => _disposed ? false : _isLoading;
  String? get errorMessage => _disposed ? null : _errorMessage;

  @override
  void dispose() {
    Logger.info('OrderProvider.dispose: Iniciando dispose do OrderProvider');
    _disposed = true;
    super.dispose();
  }

  bool _checkDisposed() {
    if (_disposed) {
      Logger.warning('OrderProvider: Tentativa de uso após dispose - operação cancelada');
      return true;
    }
    return false;
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Busca todos os pedidos da API (apenas para ADMIN/OWNER)
  Future<void> fetchOrders() async {
    if (_checkDisposed()) return;
    
    if (apiService == null) {
      _setError("Serviço de API não inicializado.");
      return;
    }

    final bool isRefresh = _orders.isNotEmpty;
    
    if (!isRefresh) {
      _setLoading(true);
    }
    _clearError();

    try {
      Logger.info('OrderProvider.fetchOrders: Iniciando busca de pedidos');
      final response = await apiService!.getOrders();
      
      if (_checkDisposed()) return;
      
      Logger.info('OrderProvider.fetchOrders: Resposta da API recebida - ${response.length} itens');
      
      // DEBUG: Vamos processar item por item e capturar erros específicos
      final List<Order> processedOrders = [];
      int successCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          Logger.info('OrderProvider.fetchOrders: Processando pedido ${i + 1}/${response.length}');
          
          // Log dos dados recebidos (primeiro pedido apenas)
          if (i == 0) {
            Logger.info('OrderProvider.fetchOrders: Estrutura do primeiro pedido: ${json.keys.toList()}');
          }
          
          final order = Order.fromJson(json);
          processedOrders.add(order);
          successCount++;
          
          Logger.info('OrderProvider.fetchOrders: ✅ Pedido ${order.id} processado com sucesso');
          
        } catch (e, stackTrace) {
          errorCount++;
          Logger.error('OrderProvider.fetchOrders: ❌ Erro ao processar pedido ${i + 1}', error: e, stackTrace: stackTrace);
          Logger.error('OrderProvider.fetchOrders: JSON problemático: ${response[i]}');
          
          // Não interrompe o loop - continua processando outros pedidos
          continue;
        }
      }
      
      Logger.info('OrderProvider.fetchOrders: Processamento concluído - $successCount sucessos, $errorCount erros');
      
      if (processedOrders.isEmpty && errorCount > 0) {
        throw Exception('Falha ao processar todos os $errorCount pedidos recebidos da API');
      }
      
      processedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _orders = processedOrders;
      
      Logger.info('OrderProvider.fetchOrders: ✅ $successCount pedidos carregados com sucesso');

    } catch (e, stackTrace) {
      if (_checkDisposed()) return;
      
      Logger.error('OrderProvider.fetchOrders: Falha geral ao buscar pedidos', error: e, stackTrace: stackTrace);
      _setError("Erro ao carregar pedidos: ${e.toString()}");
    } finally {
      // CORREÇÃO CRÍTICA 1: SEMPRE desliga loading no finally
      if (!isRefresh) {
        _setLoading(false);
      } else {
        _safeNotifyListeners();
      }
    }
  }

  /// Busca os pedidos de um usuário específico (para CLIENTE) - COM DEBUG INTENSIVO
  Future<void> fetchUserOrders() async {
    if (_checkDisposed()) return;
    
    if (apiService == null) {
      Logger.error('OrderProvider.fetchUserOrders: ApiService é null');
      _setError("Serviço de API não inicializado.");
      return;
    }
    
    Logger.info('OrderProvider.fetchUserOrders: 🚀 INICIANDO busca de pedidos do usuário');
    _setLoading(true);
    _clearError();

    try {
      Logger.info('OrderProvider.fetchUserOrders: Chamando apiService.getUserOrders()');
      final response = await apiService!.getUserOrders();
      
      if (_checkDisposed()) {
        Logger.warning('OrderProvider.fetchUserOrders: Provider foi disposed durante a requisição');
        return;
      }
      
      Logger.info('OrderProvider.fetchUserOrders: ✅ Resposta da API recebida');
      Logger.info('OrderProvider.fetchUserOrders: 📊 Quantidade de itens: ${response.length}');
      Logger.info('OrderProvider.fetchUserOrders: 📊 Tamanho dos dados: ${response.toString().length} caracteres');
      
      // DEPURAÇÃO INTENSIVA: Vamos analisar o primeiro pedido em detalhes
      if (response.isNotEmpty) {
        final firstOrder = response[0];
        Logger.info('OrderProvider.fetchUserOrders: 🔍 ANÁLISE DO PRIMEIRO PEDIDO:');
        Logger.info('OrderProvider.fetchUserOrders: 🔍 Tipo: ${firstOrder.runtimeType}');
        Logger.info('OrderProvider.fetchUserOrders: 🔍 Keys: ${firstOrder.keys.toList()}');
        
        // Verificar campos críticos
        final criticalFields = ['_id', 'id', 'total_amount', 'created_at', 'items', 'customer_info'];
        for (final field in criticalFields) {
          final value = firstOrder[field];
          Logger.info('OrderProvider.fetchUserOrders: 🔍 $field: ${value?.toString()} (${value.runtimeType})');
        }
      }
      
      // PROCESSAMENTO COM RECUPERAÇÃO DE ERRO
      final List<Order> processedOrders = [];
      int successCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < response.length; i++) {
        try {
          Logger.info('OrderProvider.fetchUserOrders: 🔄 Processando pedido ${i + 1}/${response.length}');
          
          final json = response[i];
          final order = Order.fromJson(json);
          processedOrders.add(order);
          successCount++;
          
          Logger.info('OrderProvider.fetchUserOrders: ✅ Pedido ${order.id} processado - Total: ${order.formattedTotal}');
          
        } catch (e, stackTrace) {
          errorCount++;
          Logger.error('OrderProvider.fetchUserOrders: ❌ ERRO no pedido ${i + 1}', error: e, stackTrace: stackTrace);
          
          // Log detalhado do JSON problemático
          try {
            final problemJson = response[i];
            Logger.error('OrderProvider.fetchUserOrders: 📋 JSON PROBLEMÁTICO: $problemJson');
          } catch (logError) {
            Logger.error('OrderProvider.fetchUserOrders: ❌ Erro até ao logar JSON: $logError');
          }
          
          // Continuar processando outros pedidos
          continue;
        }
      }
      
      Logger.info('OrderProvider.fetchUserOrders: 📈 RESULTADO FINAL:');
      Logger.info('OrderProvider.fetchUserOrders: ✅ Sucessos: $successCount');
      Logger.info('OrderProvider.fetchUserOrders: ❌ Erros: $errorCount');
      Logger.info('OrderProvider.fetchUserOrders: 📊 Total processado: ${processedOrders.length}');
      
      // CORREÇÃO CRÍTICA 2: SEMPRE define _userOrders, mesmo se vazio
      if (processedOrders.isNotEmpty) {
        processedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _userOrders = processedOrders;
        Logger.info('OrderProvider.fetchUserOrders: ✅ $successCount pedidos do usuário carregados com sucesso');
      } else if (errorCount > 0) {
        _userOrders = []; // CORREÇÃO: Lista vazia em caso de erro
        throw Exception('Falha ao processar todos os $errorCount pedidos do usuário. Verifique os logs para detalhes.');
      } else {
        Logger.info('OrderProvider.fetchUserOrders: ℹ️ Nenhum pedido encontrado para este usuário');
        _userOrders = []; // CORREÇÃO: Lista vazia válida
      }
      
    } catch (e, stackTrace) {
      if (_checkDisposed()) return;
      
      Logger.error('OrderProvider.fetchUserOrders: 💥 FALHA CRÍTICA', error: e, stackTrace: stackTrace);
      _userOrders = []; // CORREÇÃO CRÍTICA 3: SEMPRE define lista mesmo em erro
      _setError("Erro crítico ao processar pedidos do usuário: ${e.toString()}");
    } finally {
      Logger.info('OrderProvider.fetchUserOrders: 🏁 Finalizando - setLoading(false)');
      // CORREÇÃO CRÍTICA 1: SEMPRE desliga loading no finally
      _setLoading(false);
    }
  }

  /// Cria um novo pedido
  Future<bool> placeOrder(Map<String, dynamic> orderData) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final response = await apiService!.createOrder(orderData);
      
      if (_checkDisposed()) return false;
      
      final newOrder = Order.fromJson(response);
      _userOrders.insert(0, newOrder);
      
      if (productProvider != null) {
        Logger.info('OrderProvider: Atualizando estoque após pedido');
        try {
          await productProvider!.refresh();
        } catch (e) {
          Logger.warning('OrderProvider: Erro ao atualizar estoque após pedido: $e');
        }
      }
      
      _safeNotifyListeners();
      Logger.info('OrderProvider.placeOrder: ✅ Pedido criado com sucesso');
      return true;
      
    } catch (e, stackTrace) {
      if (_checkDisposed()) return false;
      
      Logger.error('OrderProvider.placeOrder: Falha ao criar pedido', error: e, stackTrace: stackTrace);
      _setError('Erro ao criar pedido: ${e.toString()}');
      return false;
    } finally {
      // CORREÇÃO CRÍTICA 1: SEMPRE desliga loading no finally
      _setLoading(false);
    }
  }

  /// Atualiza o status de um pedido (apenas para ADMIN/OWNER)
  Future<bool> updateOrderStatus(String orderId, String newStatus, {String? notes}) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) return false;
    
    _setLoading(true);
    _clearError();

    try {
      final response = await apiService!.updateOrderStatus(orderId, newStatus);
      
      if (_checkDisposed()) return false;
      
      final updatedOrder = Order.fromJson(response);
      final index = _orders.indexWhere((order) => order.id == orderId);
      
      if (index != -1) {
        _orders[index] = updatedOrder;
        _safeNotifyListeners();
      }
      
      Logger.info('OrderProvider.updateOrderStatus: ✅ Status do pedido $orderId atualizado para $newStatus');
      return true;
      
    } catch (e, stackTrace) {
      if (_checkDisposed()) return false;
      
      Logger.error('OrderProvider.updateOrderStatus: Falha ao atualizar status', error: e, stackTrace: stackTrace);
      _setError('Erro ao atualizar status do pedido: ${e.toString()}');
      return false;
    } finally {
      // CORREÇÃO CRÍTICA 1: SEMPRE desliga loading no finally
      _setLoading(false);
    }
  }

  // Métodos auxiliares com verificação de dispose
  void _setLoading(bool loading) {
    if (_checkDisposed()) return;
    Logger.info('OrderProvider._setLoading: $loading');
    _isLoading = loading;
    _safeNotifyListeners();
  }

  void _setError(String error) {
    if (_checkDisposed()) return;
    Logger.error('OrderProvider._setError: $error');
    _errorMessage = error;
    // CORREÇÃO CRÍTICA: SEMPRE desliga loading quando há erro
    _isLoading = false;
    _safeNotifyListeners();
  }

  void _clearError() {
    if (_checkDisposed()) return;
    _errorMessage = null;
  }

  /// Limpa todos os pedidos (para logout)
  void clearAllOrders() {
    if (_checkDisposed()) return;
    
    _orders.clear();
    _userOrders.clear();
    _clearError();
    _isLoading = false; // CORREÇÃO: Garante que loading está desligado
    _safeNotifyListeners();
    
    Logger.info('OrderProvider.clearAllOrders: ✅ Todos os pedidos foram limpos');
  }

  /// Métodos de conveniência para status
  List<Order> get pendingOrders => _disposed ? [] : _orders.where((o) => o.status == 'pending').toList();
  List<Order> get confirmedOrders => _disposed ? [] : _orders.where((o) => o.status == 'confirmed').toList();
  List<Order> get completedOrders => _disposed ? [] : _orders.where((o) => o.status == 'completed' || o.status == 'delivered').toList();

  /// Receita total
  double getTotalRevenue(List<String> validStatuses) {
    if (_checkDisposed()) return 0.0;
    
    double revenue = 0.0;
    for (final order in _orders) {
      if (validStatuses.contains(order.status)) {
        revenue += order.totalAmount;
      }
    }
    return revenue;
  }

  /// Recarrega a lista de pedidos
  Future<void> refresh() async {
    if (_checkDisposed()) return;
    await fetchOrders();
  }

  /// Limpa o erro manualmente
  void clearError() {
    _clearError();
    _safeNotifyListeners();
  }
}
