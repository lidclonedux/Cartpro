// lib/utils/app_constants.dart - VERSÃO CORRIGIDA COM LOGS

class AppConstants {
  // ===== CONFIGURAÇÃO DA API - CORRIGIDA =====
  
  // URL base do seu backend no Render
  static const String baseUrl = 'https://maykonrodass.onrender.com';
  
  // Prefixo da API
  static const String apiPrefix = '/api';
  
  // URL completa da API (para logs e debug)
  static String get fullApiUrl => '$baseUrl$apiPrefix';
  
  // ===== URLs DE TESTE PARA DEBUG =====
  static const String localUrl = 'http://localhost:5000'; // Para desenvolvimento local
  static const String localhostAndroid = 'http://10.0.2.2:5000'; // Para emulador Android
  
  // ===== INFORMAÇÕES DO APP =====
  static const String appName = 'Vitrine Borracharia';
  static const String appVersion = '1.0.0+4';
  static const String userAgent = 'VitrineBorracharia/1.0.0 Flutter';
  
  // ===== CONFIGURAÇÕES DE CORES =====
  static const int primaryColorValue = 0xFF9147FF;
  static const int backgroundColorValue = 0xFF1E1E2C;
  static const int surfaceColorValue = 0xFF23272A;
  
  // ===== CONFIGURAÇÕES DE TIMEOUT - AJUSTADAS PARA RENDER =====
  static const int connectionTimeout = 30000; // 30 segundos (Render pode ser lento)
  static const int receiveTimeout = 30000; // 30 segundos
  static const int uploadTimeout = 60000; // 60 segundos para uploads
  
  // ===== CHAVES DE ARMAZENAMENTO LOCAL =====
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String cartKey = 'cart_items';
  static const String lastSyncKey = 'last_sync_timestamp';
  static const String debugModeKey = 'debug_mode_enabled';
  
  // ===== VALIDAÇÃO =====
  static const int minPasswordLength = 6;
  static const int maxUsernameLength = 50;
  static const int minUsernameLength = 3;
  
  // ===== PAGINAÇÃO =====
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // ===== CONFIGURAÇÕES DE IMAGEM =====
  static const String defaultProductImage = 'assets/images_png/default_product.png';
  static const double maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  
  // ===== STATUS DE PEDIDOS =====
  static const String orderStatusPending = 'pending';
  static const String orderStatusConfirmed = 'confirmed';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';
  static const String orderStatusProcessing = 'processing';
  static const String orderStatusDelivered = 'delivered';
  
  // ===== MÉTODOS DE PAGAMENTO =====
  static const String paymentMethodPix = 'pix';
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodCard = 'card';
  static const String paymentMethodOther = 'other';
  
  // ===== MÉTODOS DE ENTREGA =====
  static const String deliveryMethodPickup = 'pickup';
  static const String deliveryMethodDelivery = 'delivery';
  
  // ===== PAPÉIS DE USUÁRIO =====
  static const String roleAdmin = 'ADM';
  static const String roleUser = 'USER';
  static const String roleOwner = 'OWNER';
  
  // ===== MENSAGENS DE ERRO PADRONIZADAS =====
  static const String networkError = '🌐 Erro de conexão. Verifique sua internet e tente novamente.';
  static const String serverError = '🔧 Erro no servidor. Tente novamente mais tarde.';
  static const String timeoutError = '⏱️ Timeout: Servidor demorou para responder.';
  static const String unknownError = '❓ Erro desconhecido. Tente novamente.';
  static const String authError = '🔐 Erro de autenticação. Faça login novamente.';
  static const String validationError = '✏️ Dados inválidos. Verifique os campos.';
  static const String permissionError = '🚫 Você não tem permissão para esta ação.';
  
  // ===== MENSAGENS DE SUCESSO =====
  static const String loginSuccess = '✅ Login realizado com sucesso!';
  static const String logoutSuccess = '👋 Logout realizado com sucesso!';
  static const String orderSuccess = '🎉 Pedido realizado com sucesso!';
  static const String productAddedToCart = '🛒 Produto adicionado ao carrinho!';
  static const String productUpdated = '📦 Produto atualizado com sucesso!';
  static const String orderStatusUpdated = '🔄 Status do pedido atualizado!';
  
  // ===== CONFIGURAÇÕES DE LOG ESPECÍFICAS PARA DEBUG =====
  static const bool enableDetailedLogs = true; // Mude para false em produção
  static const bool enableNetworkLogs = true;
  static const bool enableErrorReporting = true;
  
  // ===== CONFIGURAÇÕES ESPECÍFICAS DO RENDER =====
  static const String renderDomain = 'painel-lucasbeats.onrender.com';
  static const bool renderUsesHttps = true;
  static const int renderColdStartTimeout = 45000; // 45 segundos para cold start
  
  // ===== ENDPOINTS DA API =====
  static String get authEndpoint => '$fullApiUrl/auth';
  static String get productsEndpoint => '$fullApiUrl/products';
  static String get ordersEndpoint => '$fullApiUrl/orders';
  static String get categoriesEndpoint => '$fullApiUrl/categories';
  static String get uploadEndpoint => '$fullApiUrl/upload';
  static String get settingsEndpoint => '$fullApiUrl/settings';
  
  // ===== FUNÇÃO UTILITÁRIA PARA DEBUG =====
  static void logApiConfiguration() {
    if (enableDetailedLogs) {
      print('====== CONFIGURAÇÃO DA API ======');
      print('🔗 Base URL: $baseUrl');
      print('🔗 API Prefix: $apiPrefix');
      print('🔗 Full API URL: $fullApiUrl');
      print('📱 User Agent: $userAgent');
      print('⏱️ Connection Timeout: ${connectionTimeout}ms');
      print('⏱️ Receive Timeout: ${receiveTimeout}ms');
      print('🌐 Render Domain: $renderDomain');
      print('🔒 Uses HTTPS: $renderUsesHttps');
      print('==================================');
    }
  }
  
  // ===== FUNÇÃO PARA VERIFICAR AMBIENTE =====
  static bool get isProduction {
    return baseUrl.contains('render.com') || baseUrl.contains('herokuapp.com');
  }
  
  static bool get isDevelopment {
    return baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1') || baseUrl.contains('10.0.2.2');
  }
  
  // ===== FUNÇÃO PARA OBTER URL BASEADA NO AMBIENTE =====
  static String getApiUrl({bool forceLocal = false}) {
    if (forceLocal || isDevelopment) {
      print('🔧 Usando URL de desenvolvimento: $localUrl$apiPrefix');
      return '$localUrl$apiPrefix';
    } else {
      print('🚀 Usando URL de produção: $fullApiUrl');
      return fullApiUrl;
    }
  }
  
  // ===== CONFIGURAÇÕES ESPECÍFICAS PARA DIFERENTES BUILDS =====
  static const Map<String, dynamic> debugConfig = {
    'enableLogs': true,
    'enableNetworkLogs': true,
    'enableErrorReporting': true,
    'allowHttpRequests': true,
    'bypassSslVerification': true, // APENAS PARA DEBUG
  };
  
  static const Map<String, dynamic> releaseConfig = {
    'enableLogs': false,
    'enableNetworkLogs': false,
    'enableErrorReporting': true,
    'allowHttpRequests': false,
    'bypassSslVerification': false,
  };
  
  // ===== FUNÇÃO PARA OBTER CONFIGURAÇÃO ATUAL =====
  static Map<String, dynamic> getCurrentConfig() {
    // Em produção, use releaseConfig
    // Em debug, use debugConfig
    const bool isDebugMode = true; // Mude para false no release
    
    return isDebugMode ? debugConfig : releaseConfig;
  }
}

// ===== CLASSE DE UTILITÁRIOS PARA LOGS =====
class AppLogger {
  static const String _prefix = '🔷 VitrineBorracharia';
  
  static void info(String message) {
    if (AppConstants.enableDetailedLogs) {
      print('$_prefix ℹ️ $message');
    }
  }
  
  static void error(String message, {Object? error}) {
    if (AppConstants.enableErrorReporting) {
      print('$_prefix ❌ $message');
      if (error != null) {
        print('$_prefix 🔍 Detalhes: $error');
      }
    }
  }
  
  static void network(String message) {
    if (AppConstants.enableNetworkLogs) {
      print('$_prefix 🌐 $message');
    }
  }
  
  static void debug(String message) {
    if (AppConstants.enableDetailedLogs) {
      print('$_prefix 🔧 $message');
    }
  }
}
