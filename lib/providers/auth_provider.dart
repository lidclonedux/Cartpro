// lib/providers/auth_provider.dart - VERSÃO JWT COMPLETA (SEM FIREBASE)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

// Imports para limpeza de outros providers
import 'order_provider.dart';
import 'product_provider.dart';
import 'cart_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiService? apiService;

  // Estados principais
  User? _user;
  bool _isLoading = false;
  bool _isLoggingOut = false;
  String? _errorMessage;
  
  // Estados de inicialização centralizados
  bool _isInitialized = false;
  bool _isDataLoaded = false;
  
  AuthProvider(this.apiService) {
    print('🔧 DEBUG: AuthProvider construído com ApiService JWT: ${apiService != null}');
  }

  // Getters básicos
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggingOut => _isLoggingOut;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isOwner => _user?.isOwner ?? false;
  
  // Getters para controle de fluxo do AuthWrapper
  bool get isInitialized => _isInitialized;
  bool get isDataLoaded => _isDataLoaded;
  bool get shouldShowSplash => !_isInitialized;
  bool get shouldShowLogin => _isInitialized && !isLoggedIn;
  bool get shouldShowLoading => _isInitialized && isLoggedIn && !_isDataLoaded;
  bool get shouldShowApp => _isInitialized && isLoggedIn && _isDataLoaded;

  User? get currentUser => _user;

  /// Método de inicialização centralizado JWT
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔧 DEBUG: Initialize já foi executado anteriormente');
      return;
    }
    
    print('🔧 DEBUG: === INICIANDO INICIALIZAÇÃO JWT ===');
    print('🔧 DEBUG: ApiService disponível: ${apiService != null}');
    
    _setLoading(true);
    
    try {
      print('🔧 DEBUG: Aguardando 2 segundos (splash)...');
      await Future.delayed(const Duration(seconds: 2));
      
      print('🔧 DEBUG: Verificando status de autenticação JWT...');
      await checkAuthStatus();
      
      _isInitialized = true;
      print('🔧 DEBUG: ✅ SISTEMA JWT INICIALIZADO COM SUCESSO');
      print('🔧 DEBUG: Usuario logado: $isLoggedIn');
      if (isLoggedIn) {
        print('🔧 DEBUG: Usuario: ${_user!.username}, Admin: ${_user!.isAdmin}');
      }
      
    } catch (e) {
      print('🔧 DEBUG: ❌ ERRO NA INICIALIZAÇÃO JWT: $e');
      _isInitialized = true; // Permite continuar mesmo com erro
    } finally {
      _setLoading(false);
      notifyListeners();
      print('🔧 DEBUG: === INICIALIZAÇÃO JWT FINALIZADA ===');
    }
  }

  /// Carrega dados do usuário após login JWT
  Future<void> loadUserData(BuildContext context) async {
    print('🔧 DEBUG: === INICIANDO CARREGAMENTO DE DADOS JWT ===');
    print('🔧 DEBUG: Usuario logado: $isLoggedIn');
    print('🔧 DEBUG: Dados já carregados: $_isDataLoaded');
    
    if (!isLoggedIn) {
      print('🔧 DEBUG: ❌ Usuario não logado - cancelando carregamento');
      return;
    }
    
    if (_isDataLoaded) {
      print('🔧 DEBUG: ✅ Dados já foram carregados anteriormente');
      return;
    }
    
    print('🔧 DEBUG: Usuario: ${_user!.username}, Admin: ${_user!.isAdmin}');
    
    _setLoading(true);
    
    try {
      print('🔧 DEBUG: Obtendo providers...');
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      print('🔧 DEBUG: ProductProvider obtido: ${productProvider != null}');
      print('🔧 DEBUG: OrderProvider obtido: ${orderProvider != null}');
      
      // Carrega produtos
      print('🔧 DEBUG: Iniciando carregamento de produtos...');
      await productProvider.refresh();
      print('🔧 DEBUG: ✅ Produtos carregados - Total: ${productProvider.products.length}');
      
      // Carrega pedidos baseado no tipo de usuário
      if (isAdmin) {
        print('🔧 DEBUG: Usuario é admin - carregando todos os pedidos...');
        await orderProvider.fetchOrders();
        print('🔧 DEBUG: ✅ Pedidos admin carregados - Total: ${orderProvider.orders.length}');
      } else {
        print('🔧 DEBUG: Usuario é cliente - carregando pedidos do usuário...');
        await orderProvider.fetchUserOrders();
        print('🔧 DEBUG: ✅ Pedidos do usuário carregados - Total: ${orderProvider.userOrders.length}');
      }
      
      _isDataLoaded = true;
      print('🔧 DEBUG: ✅ TODOS OS DADOS CARREGADOS COM SUCESSO');
      print('🔧 DEBUG: _isDataLoaded definido como true');
      
    } catch (e, stackTrace) {
      print('🔧 DEBUG: ❌ ERRO AO CARREGAR DADOS: $e');
      print('🔧 DEBUG: StackTrace: $stackTrace');
      // Permite continuar mesmo com erro
      _isDataLoaded = true;
      print('🔧 DEBUG: ⚠️ _isDataLoaded forçado para true após erro');
    } finally {
      _setLoading(false);
      notifyListeners();
      print('🔧 DEBUG: === CARREGAMENTO DE DADOS FINALIZADO ===');
    }
  }

  /// Login do usuário JWT
  Future<bool> login(String username, String password) async {
    print('🔧 DEBUG: === INICIANDO LOGIN JWT ===');
    print('🔧 DEBUG: Usuario solicitado: $username');
    
    if (apiService == null) {
      print('🔧 DEBUG: ❌ ApiService não inicializado');
      _setError('Serviço de API não inicializado.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('🔧 DEBUG: Enviando requisição de login JWT...');
      final response = await apiService!.login(username, password);
      
      print('🔧 DEBUG: Resposta JWT recebida: ${response['success'] ?? 'não especificado'}');
      
      // JWT retorna user diretamente ou dentro de response
      final userData = response['user'] ?? response;
      
      if (userData != null && (response['success'] == true || response['token'] != null || userData['uid'] != null)) {
        _user = User.fromJson(userData);
        _isDataLoaded = false; // Reseta para forçar novo carregamento
        
        print('🔧 DEBUG: ✅ LOGIN JWT REALIZADO COM SUCESSO');
        print('🔧 DEBUG: Usuario: ${_user!.username}');
        print('🔧 DEBUG: Admin: ${_user!.isAdmin}');
        print('🔧 DEBUG: Token salvo automaticamente pelo ApiService');
        print('🔧 DEBUG: _isDataLoaded resetado para false');
        
        notifyListeners();
        return true;
      } else {
        final errorMsg = response['error'] ?? 'Credenciais inválidas ou resposta inválida';
        print('🔧 DEBUG: ❌ FALHA NO LOGIN JWT: $errorMsg');
        _setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('🔧 DEBUG: ❌ EXCEÇÃO DURANTE LOGIN JWT: $e');
      _setError('Erro ao fazer login: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
      print('🔧 DEBUG: === LOGIN JWT FINALIZADO ===');
    }
  }

  /// Registro de novo usuário JWT
  Future<bool> register(String username, String password, String displayName) async {
    print('🔧 DEBUG: === INICIANDO REGISTRO JWT ===');
    print('🔧 DEBUG: Usuario: $username, Nome: $displayName');
    
    if (apiService == null) {
      print('🔧 DEBUG: ❌ ApiService não inicializado');
      _setError('Serviço de API não inicializado.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('🔧 DEBUG: Enviando requisição de registro JWT...');
      final response = await apiService!.register(username, password, displayName);
      
      print('🔧 DEBUG: Resposta JWT recebida: ${response['success'] ?? 'não especificado'}');
      
      // JWT pode retornar user diretamente ou dentro de response
      final userData = response['user'] ?? response;
      
      if (userData != null && (response['success'] == true || response['token'] != null || userData['uid'] != null)) {
        _user = User.fromJson(userData);
        _isDataLoaded = false;
        
        print('🔧 DEBUG: ✅ REGISTRO JWT REALIZADO COM SUCESSO');
        print('🔧 DEBUG: Novo usuario: ${_user!.username}');
        print('🔧 DEBUG: Token salvo automaticamente pelo ApiService');
        
        notifyListeners();
        return true;
      } else {
        final errorMsg = response['error'] ?? 'Falha no registro';
        print('🔧 DEBUG: ❌ FALHA NO REGISTRO JWT: $errorMsg');
        _setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('🔧 DEBUG: ❌ EXCEÇÃO DURANTE REGISTRO JWT: $e');
      _setError('Erro ao registrar: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
      print('🔧 DEBUG: === REGISTRO JWT FINALIZADO ===');
    }
  }

  /// Verifica status de autenticação JWT
  Future<void> checkAuthStatus() async {
    print('🔧 DEBUG: === VERIFICANDO STATUS JWT ===');
    
    if (apiService == null) {
      print('🔧 DEBUG: ❌ ApiService não inicializado');
      _user = null;
      return;
    }

    try {
      // Verificar se tem token JWT salvo
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      if (token == null || token.isEmpty) {
        print('🔧 DEBUG: ❌ Nenhum token JWT encontrado');
        _user = null;
        _isDataLoaded = false;
        return;
      }

      print('🔧 DEBUG: Token JWT encontrado, validando com o backend...');
      
      // Validar token fazendo requisição de perfil
      final response = await apiService!.getProfile();
      
      print('🔧 DEBUG: Resposta do perfil JWT recebida - User presente: ${response['user'] != null}');
      
      if (response['user'] != null) {
        _user = User.fromJson(response['user']);
        _isDataLoaded = false;
        print('🔧 DEBUG: ✅ USUARIO AUTENTICADO VIA JWT');
        print('🔧 DEBUG: Usuario: ${_user!.username}');
        print('🔧 DEBUG: Admin: ${_user!.isAdmin}');
      } else {
        _user = null;
        _isDataLoaded = false;
        // Limpar token inválido
        await prefs.remove('jwt_token');
        print('🔧 DEBUG: ❌ TOKEN JWT INVÁLIDO - removido do storage');
      }
    } catch (e) {
      _user = null;
      _isDataLoaded = false;
      
      // Limpar token em caso de erro
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('jwt_token');
        print('🔧 DEBUG: Token JWT removido devido ao erro');
      } catch (cleanupError) {
        print('🔧 DEBUG: Erro ao limpar token: $cleanupError');
      }
      
      print('🔧 DEBUG: ⚠️ FALHA NA VERIFICAÇÃO JWT: $e');
    } finally {
      print('🔧 DEBUG: === VERIFICAÇÃO JWT FINALIZADA ===');
    }
  }

  /// Logout com limpeza completa JWT
  Future<void> logout([BuildContext? context]) async {
    print('🔧 DEBUG: === INICIANDO PROCESSO DE LOGOUT JWT ===');
    
    if (_isLoggingOut) {
      print('🔧 DEBUG: ⚠️ LOGOUT JA EM ANDAMENTO');
      return;
    }

    _isLoggingOut = true;
    _setLoading(true);
    notifyListeners();
    
    try {
      final String? usernameForLog = _user?.username;
      _user = null;
      _isDataLoaded = false;
      _clearError();
      
      print('🔧 DEBUG: ✅ ESTADO LOCAL LIMPO');
      print('🔧 DEBUG: Usuario anterior: $usernameForLog');
      
      notifyListeners();
      
      // Logout via API (notificar backend e limpar token)
      if (apiService != null) {
        try {
          await apiService!.logout();
          print('🔧 DEBUG: ✅ LOGOUT JWT NA API REALIZADO');
        } catch (apiError) {
          print('🔧 DEBUG: ⚠️ FALHA NO LOGOUT DA API JWT: $apiError');
        }
      }
      
      if (context != null && context.mounted) {
        await _clearOtherProviders(context);
      }

      // Limpeza completa de SharedPreferences (JWT específico)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Limpa tudo, incluindo tokens JWT
      print("🔧 DEBUG: ✅ SharedPreferences LIMPO (JWT e outros dados)");
      
      print('🔧 DEBUG: ✅ PROCESSO DE LOGOUT JWT CONCLUÍDO');
      
    } catch (e) {
      print('🔧 DEBUG: ❌ ERRO DURANTE LOGOUT JWT: $e');
      _user = null;
      _isDataLoaded = false;
      _clearError();
      
      // Garantir limpeza mesmo com erro
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print("🔧 DEBUG: ✅ SharedPreferences limpo mesmo com erro");
      } catch (cleanupError) {
        print("🔧 DEBUG: ❌ Falha na limpeza de emergência: $cleanupError");
      }
    } finally {
      _isLoggingOut = false;
      _setLoading(false);
      notifyListeners();
      print('🔧 DEBUG: === LOGOUT JWT FINALIZADO ===');
    }
  }

  /// Limpa outros providers
  Future<void> _clearOtherProviders(BuildContext context) async {
    print('🔧 DEBUG: === INICIANDO LIMPEZA DE PROVIDERS ===');
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    final List<({String name, Function() operation})> cleanupOperations = [
      (
        name: 'OrderProvider',
        operation: () {
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          orderProvider.clearAllOrders();
        }
      ),
      (
        name: 'ProductProvider',
        operation: () {
          final productProvider = Provider.of<ProductProvider>(context, listen: false);
          productProvider.clearAllData();
        }
      ),
      (
        name: 'CartProvider',
        operation: () {
          final cartProvider = Provider.of<CartProvider>(context, listen: false);
          cartProvider.clearCart();
        }
      ),
    ];
    
    for (final cleanup in cleanupOperations) {
      try {
        cleanup.operation();
        print('🔧 DEBUG: ✅ ${cleanup.name} LIMPO');
      } catch (e) {
        print('🔧 DEBUG: ⚠️ FALHA AO LIMPAR ${cleanup.name}: $e');
      }
    }
    print('🔧 DEBUG: === LIMPEZA DE PROVIDERS FINALIZADA ===');
  }

  /// Tenta renovar token automaticamente
  Future<bool> tryAutoRefreshToken() async {
    if (apiService == null) return false;
    
    try {
      print('🔧 DEBUG: Tentando renovar token JWT automaticamente');
      final response = await apiService!.refreshToken();
      
      if (response['success'] == true || response['token'] != null) {
        print('🔧 DEBUG: ✅ Token JWT renovado automaticamente');
        return true;
      } else {
        print('🔧 DEBUG: ❌ Falha na renovação automática');
        return false;
      }
    } catch (e) {
      print('🔧 DEBUG: ❌ Erro na renovação automática: $e');
      return false;
    }
  }

  /// Verifica se precisa renovar token e faz automaticamente
  Future<void> checkAndRefreshToken() async {
    if (apiService == null || !isLoggedIn) return;
    
    try {
      final needsRefresh = await apiService!.needsTokenRefresh();
      if (needsRefresh) {
        print('🔧 DEBUG: Token JWT precisa ser renovado');
        final success = await tryAutoRefreshToken();
        
        if (!success) {
          print('🔧 DEBUG: ⚠️ Falha na renovação - fazendo logout');
          await logout();
        }
      }
    } catch (e) {
      print('🔧 DEBUG: Erro na verificação de renovação: $e');
    }
  }

  /// Atualiza dados do usuário
  void updateUser(User updatedUser) {
    print('🔧 DEBUG: Atualizando dados do usuario JWT');
    _user = updatedUser;
    notifyListeners();
  }

  void updateUserFromJson(Map<String, dynamic> userData) {
    print('🔧 DEBUG: Atualizando dados via JSON');
    
    try {
      if (_user != null) {
        _user = User.fromJson(userData);
        notifyListeners();
        print('🔧 DEBUG: ✅ Dados atualizados');
      }
    } catch (e) {
      print('🔧 DEBUG: ❌ Erro ao atualizar: $e');
    }
  }

  /// Método para atualizar senha (novo recurso JWT)
  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    if (apiService == null) {
      _setError('Serviço de API não inicializado.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      print('🔧 DEBUG: Atualizando senha via JWT');
      final response = await apiService!.updatePassword(currentPassword, newPassword);
      
      if (response['success'] == true) {
        print('🔧 DEBUG: ✅ Senha atualizada com sucesso');
        return true;
      } else {
        final errorMsg = response['error'] ?? 'Falha ao atualizar senha';
        _setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('🔧 DEBUG: ❌ Erro ao atualizar senha: $e');
      _setError('Erro ao atualizar senha: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Métodos auxiliares
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      print('🔧 DEBUG: Loading alterado para: $loading');
      notifyListeners();
    }
  }

  void _setError(String error) {
    print('🔧 DEBUG: ⚠️ ERRO DEFINIDO: $error');
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      print('🔧 DEBUG: Limpando erro anterior');
      _errorMessage = null;
    }
  }

  void clearError() {
    print('🔧 DEBUG: Limpeza manual de erro solicitada');
    _clearError();
    notifyListeners();
  }

  // Métodos de compatibilidade e diagnóstico
  Future<Map<String, dynamic>> getAuthDiagnostics() async {
    final diagnostics = <String, dynamic>{};
    
    try {
      diagnostics['provider_state'] = {
        'is_initialized': _isInitialized,
        'is_data_loaded': _isDataLoaded,
        'is_logged_in': isLoggedIn,
        'is_loading': _isLoading,
        'has_error': _errorMessage != null,
        'user_username': _user?.username,
        'user_role': _user?.role,
      };
      
      if (apiService != null) {
        final apiDiagnostics = await apiService!.runDiagnostics();
        diagnostics['api_service'] = apiDiagnostics;
      }
      
      final prefs = await SharedPreferences.getInstance();
      diagnostics['shared_preferences'] = {
        'has_jwt_token': prefs.getString('jwt_token') != null,
        'keys': prefs.getKeys().toList(),
      };
      
    } catch (e) {
      diagnostics['error'] = e.toString();
    }
    
    return diagnostics;
  }

  /// Força recarregamento completo do estado de autenticação
  Future<void> forceRefresh() async {
    print('🔧 DEBUG: Forçando refresh completo do AuthProvider');
    
    _isDataLoaded = false;
    await checkAuthStatus();
    
    if (isLoggedIn) {
      print('🔧 DEBUG: Usuario ainda logado após refresh, dados serão recarregados automaticamente');
    } else {
      print('🔧 DEBUG: Usuario não está mais logado após refresh');
    }
    
    notifyListeners();
  }
}
