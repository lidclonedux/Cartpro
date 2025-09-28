import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importar módulos
import 'api_modules/core/api_client.dart';
import 'api_modules/core/api_headers.dart';
import 'api_modules/auth/auth_api_service.dart';
import 'api_modules/products/product_api_service.dart';
import 'api_modules/orders/order_api_service.dart';
import 'api_modules/categories/category_api_service.dart';
import 'api_modules/uploads/image_upload_service.dart';
import 'api_modules/uploads/document_upload_service.dart';
import 'api_modules/payments/payment_api_service.dart';
import 'api_modules/settings/settings_api_service.dart';
import 'api_modules/transactions/transaction_api_service.dart';
import 'api_modules/accounting/accounting_api_service.dart';

class ApiService {
  late final ApiHeaders _headers;

  // Módulos especializados
  late final AuthApiService _authService;
  late final ProductApiService _productService;
  late final OrderApiService _orderService;
  late final CategoryApiService _categoryService;
  late final ImageUploadService _imageUploadService;
  late final DocumentUploadService _documentUploadService;
  late final PaymentApiService _paymentService;
  late final SettingsApiService _settingsService;
  late final TransactionApiService _transactionService;
  late final AccountingApiService _accountingService;

  ApiService() {
    _headers = ApiHeaders();
    _authService = AuthApiService();
    _productService = ProductApiService(_headers);
    _orderService = OrderApiService(_headers);
    _categoryService = CategoryApiService(_headers);
    _imageUploadService = ImageUploadService(_headers);
    _documentUploadService = DocumentUploadService(_headers);
    _paymentService = PaymentApiService(_headers);
    _settingsService = SettingsApiService(_headers);
    _transactionService = TransactionApiService(_headers);
    _accountingService = AccountingApiService(_headers);
    Logger.info('ApiService: Todos os módulos inicializados com JWT');
  }

  // =========== MÉTODOS DE CONECTIVIDADE ===========
  Future<bool> testConnectivity() => ApiClient.testConnectivity();

  // =========== DELEGAÇÃO PARA MÓDULOS AUTH JWT ===========
  Future<Map<String, dynamic>> login(String username, String password) => _authService.login(username, password);
  Future<Map<String, dynamic>> register(String username, String password, String displayName) => _authService.register(username, password, displayName);
  Future<void> logout() => _authService.logout();
  Future<Map<String, dynamic>> getProfile() => _authService.getProfile();
  Future<Map<String, dynamic>> refreshToken() => _authService.refreshToken();
  Future<bool> isAuthenticated() => _authService.isAuthenticated();
  Future<void> clearAuthData() => _authService.clearAuthData();
  Future<Map<String, dynamic>> updatePassword(String currentPassword, String newPassword) =>
    _authService.updatePassword(currentPassword, newPassword);

  // PRODUCTS
  Future<List<dynamic>> getProducts({String? userId}) => _productService.getProducts(userId: userId);
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> productData) => _productService.createProduct(productData);
  Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> productData) => _productService.updateProduct(productId, productData);
  Future<void> deleteProduct(String productId) => _productService.deleteProduct(productId);

  // ORDERS
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) => _orderService.createOrder(orderData);
  Future<List<dynamic>> getUserOrders() => _orderService.getUserOrders();
  Future<List<dynamic>> getOrders() => _orderService.getOrders();
  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) => _orderService.updateOrderStatus(orderId, status);

  // CATEGORIES (E-commerce)
  Future<List<dynamic>> getCategories({String? context}) => _categoryService.getCategories(context: context);
  Future<Map<String, dynamic>> createCategory(String name, {String? context, String? type, String? color, String? icon, String? emoji}) =>
    _categoryService.createCategory(name, context: context, type: type, color: color, icon: icon, emoji: emoji);
  Future<Map<String, dynamic>> updateCategory(String categoryId, Map<String, dynamic> categoryData) => _categoryService.updateCategory(categoryId, categoryData);
  Future<void> deleteCategory(String categoryId) => _categoryService.deleteCategory(categoryId);
  Future<Map<String, dynamic>> seedDefaultCategories() => _categoryService.seedDefaultCategories();

  // ACCOUNTING CATEGORIES
  Future<List<dynamic>> getAccountingCategories() => _accountingService.getAccountingCategories();
  Future<Map<String, dynamic>> createAccountingCategory(Map<String, dynamic> categoryData) => _accountingService.createAccountingCategory(categoryData);
  Future<Map<String, dynamic>> updateAccountingCategory(String categoryId, Map<String, dynamic> categoryData) => _accountingService.updateAccountingCategory(categoryId, categoryData);
  Future<void> deleteAccountingCategory(String categoryId) => _accountingService.deleteAccountingCategory(categoryId);

  // UPLOADS
  Future<Map<String, dynamic>> uploadProductImage({required File imageFile, String? productName}) =>
    _imageUploadService.uploadProductImage(imageFile: imageFile, productName: productName);
  Future<Map<String, dynamic>> uploadDocument({required File file, String context = 'business', String type = 'document', String? description}) =>
    _documentUploadService.uploadDocument(file: file, context: context, type: type, description: description);

  // =========== PROCESSAMENTO DE VOZ (SEÇÃO ATUALIZADA) ===========

  /// **[PARA MOBILE]** Processa comando de voz enviando um arquivo de áudio.
  Future<Map<String, dynamic>> processVoiceCommandFromFile(File audioFile) async {
    Logger.info('ApiService (Mobile): Iniciando processamento de comando de voz via arquivo.');

    try {
      if (!await isAuthenticated()) throw Exception('Usuário não autenticado');
      if (!await audioFile.exists()) throw Exception('Arquivo de áudio não encontrado');

      final headers = await _headers.getAuthHeaders();
      final uri = Uri.parse('${ApiClient.baseUrl}/api/voice/process');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      final mimeType = lookupMimeType(audioFile.path) ?? 'audio/m4a';
      final audioStream = http.ByteStream(audioFile.openRead());
      final audioLength = await audioFile.length();

      final multipartFile = http.MultipartFile(
        'audio', // Nome do campo esperado pelo backend
        audioStream,
        audioLength,
        filename: 'voice_command.${audioFile.path.split('.').last}',
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      Logger.info('ApiService (Mobile): Enviando áudio para processamento (${audioLength} bytes)');
      return _sendVoiceRequest(request);

    } catch (e) {
      Logger.error('ApiService (Mobile): Erro no processamento de comando de voz', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// **[PARA WEB]** Processa comando de voz a partir de uma URL de Blob.
  Future<Map<String, dynamic>> processVoiceCommandFromWeb(String blobUrl) async {
    Logger.info('ApiService (Web): Iniciando processamento de comando de voz via Blob URL.');

    try {
      if (!await isAuthenticated()) throw Exception('Usuário não autenticado');

      // 1. Baixar os dados do Blob
      final audioDataResponse = await http.get(Uri.parse(blobUrl));
      if (audioDataResponse.statusCode != 200) {
        throw Exception('Falha ao baixar os dados do áudio da URL do Blob.');
      }
      final Uint8List audioBytes = audioDataResponse.bodyBytes;

      // 2. Montar e enviar a requisição
      final headers = await _headers.getAuthHeaders();
      final uri = Uri.parse('${ApiClient.baseUrl}/api/voice/process');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      final multipartFile = http.MultipartFile.fromBytes(
        'audio', // O mesmo nome de campo esperado pelo backend
        audioBytes,
        filename: 'voice_command_web.m4a', // Nome de arquivo para o backend
        contentType: MediaType('audio', 'm4a'),
      );
      request.files.add(multipartFile);

      Logger.info('ApiService (Web): Enviando áudio para processamento (${audioBytes.length} bytes)');
      return _sendVoiceRequest(request);

    } catch (e) {
      Logger.error('ApiService (Web): Erro no processamento de comando de voz', error: e);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// **[MÉTODO PRIVADO]** Envia a requisição de voz e processa a resposta.
  Future<Map<String, dynamic>> _sendVoiceRequest(http.MultipartRequest request) async {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    Logger.info('ApiService (Voice): Resposta recebida - Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        Logger.info('ApiService (Voice): Comando de voz processado com sucesso.');
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Erro desconhecido no processamento de voz');
      }
    } else {
      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Erro HTTP ${response.statusCode}');
      } catch (_) {
        throw Exception('Erro HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }

  // PAYMENTS
  Future<Map<String, dynamic>> getStorePaymentInfo(String storeOwnerId) => _paymentService.getStorePaymentInfo(storeOwnerId);
  Future<String> uploadPaymentProof({required File imageFile, String? orderId, String? description}) =>
    _paymentService.uploadPaymentProof(imageFile: imageFile, orderId: orderId, description: description);

  // SETTINGS
  Future<Map<String, dynamic>> updateContactInfo(String phoneNumber) => _settingsService.updateContactInfo(phoneNumber);
  Future<Map<String, dynamic>> updatePixInfo(String pixKey, [String? pixQrCodeUrl]) => _settingsService.updatePixInfo(pixKey, pixQrCodeUrl);

  // TRANSACTIONS
  Future<List<dynamic>> getTransactions() => _transactionService.getTransactions();
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> transactionData) => _transactionService.createTransaction(transactionData);
  Future<Map<String, dynamic>> updateTransaction(String transactionId, Map<String, dynamic> transactionData) => _transactionService.updateTransaction(transactionId, transactionData);
  Future<void> deleteTransaction(String transactionId) => _transactionService.deleteTransaction(transactionId);

  // ACCOUNTING
  Future<Map<String, dynamic>> getDashboardSummary() => _accountingService.getDashboardSummary();
  Future<List<dynamic>> getRecurringTransactions() => _accountingService.getRecurringTransactions();
  Future<Map<String, dynamic>> createRecurringTransaction(Map<String, dynamic> recurringTransactionData) => _accountingService.createRecurringTransaction(recurringTransactionData);
  Future<Map<String, dynamic>> updateRecurringTransaction(String recurringTransactionId, Map<String, dynamic> recurringTransactionData) => _accountingService.updateRecurringTransaction(recurringTransactionId, recurringTransactionData);
  Future<void> deleteRecurringTransaction(String recurringTransactionId) => _accountingService.deleteRecurringTransaction(recurringTransactionId);

  // =========== GETTERS UTILITÁRIOS JWT ===========
  String get baseUrl => ApiClient.baseUrl;
  Future<bool> get isAuthenticatedSync async => await isAuthenticated();
  Future<String?> get currentUserId async {
    try {
      final profile = await getProfile();
      return profile['user']?['uid'];
    } catch (e) {
      return null;
    }
  }
  AccountingApiService get accountingService => _accountingService;
  TransactionApiService get transactionService => _transactionService;
  Future<Map<String, String?>> get currentUserInfo async {
    try {
      final profile = await getProfile();
      final user = profile['user'];
      if (user == null) return {};

      return {
        'uid': user['uid']?.toString(),
        'username': user['username']?.toString(),
        'email': user['email']?.toString(),
        'displayName': user['display_name']?.toString(),
        'role': user['role']?.toString(),
        'phoneNumber': user['phone_number']?.toString(),
      };
    } catch (e) {
      Logger.warning('ApiService: Erro ao obter informações do usuário', error: e);
      return {};
    }
  }

  // =========== MÉTODOS UTILITÁRIOS JWT ===========
  void clearLocalCache() {
    Logger.info('ApiService: Cache local limpo (se existir)');
  }

  Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};
    try {
      Logger.info('ApiService: Executando diagnósticos JWT...');
      final connectivityResult = await testConnectivity();
      results['connectivity'] = connectivityResult;
      final isAuth = await isAuthenticated();
      results['jwt_authenticated'] = isAuth;
      final prefs = await SharedPreferences.getInstance();
      final hasToken = prefs.getString('jwt_token') != null;
      results['has_local_token'] = hasToken;
      if (isAuth) {
        try {
          final profile = await getProfile();
          results['profile_accessible'] = profile['user'] != null;
        } catch (e) {
          results['profile_accessible'] = false;
          results['profile_error'] = e.toString();
        }
      }
      try {
        final categories = await getCategories();
        results['api_categories'] = categories.isNotEmpty;
      } catch (e) {
        results['api_categories'] = false;
        results['categories_error'] = e.toString();
      }
      results['is_production'] = ApiClient.baseUrl.contains('render.com');
      results['base_url'] = ApiClient.baseUrl;
      results['auth_type'] = 'JWT';
      final authDiagnostics = await _authService.runAuthDiagnostics();
      results['auth_diagnostics'] = authDiagnostics;
      Logger.info('ApiService: Diagnósticos JWT concluídos');
      return results;
    } catch (e) {
      Logger.error('ApiService: Erro nos diagnósticos JWT', error: e);
      results['error'] = e.toString();
      return results;
    }
  }

  void logUsageStats(String endpoint, int responseTime, bool success) {
    try {
      final status = success ? '✅' : '❌';
      Logger.info('ApiService: $status $endpoint - ${responseTime}ms');
    } catch (e) {
      print('ApiService: $endpoint - ${responseTime}ms - Success: $success');
    }
  }

  // =========== MÉTODOS DE MANUTENÇÃO TOKEN ===========
  Future<bool> needsTokenRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenSavedTime = prefs.getInt('jwt_token_saved_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursPassed = (now - tokenSavedTime) / (1000 * 60 * 60);
      return hoursPassed > 20;
    } catch (e) {
      Logger.warning('ApiService: Erro ao verificar necessidade de refresh', error: e);
      return false;
    }
  }

  Future<bool> tryAutoRefreshToken() async {
    try {
      if (await needsTokenRefresh()) {
        Logger.info('ApiService: Tentando renovar token automaticamente');
        await refreshToken();
        return true;
      }
      return false;
    } catch (e) {
      Logger.warning('ApiService: Falha na renovação automática do token', error: e);
      return false;
    }
  }

  Future<void> _saveTokenTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('jwt_token_saved_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.warning('ApiService: Erro ao salvar timestamp do token', error: e);
    }
  }

  // =========== MÉTODOS DE COMPATIBILIDADE ===========
  Future<void> signOut() async {
    Logger.info('ApiService: Método signOut (compatibilidade) - redirecionando para logout JWT');
    await logout();
  }

  Future<bool> get isSignedIn async => await isAuthenticated();
  Future<Map<String, dynamic>?> get currentUser async {
    try {
      final profile = await getProfile();
      return profile['user'];
    } catch (e) {
      return null;
    }
  }

  // =========== LIMPEZA E CLEANUP ===========
  Future<void> fullAuthCleanup() async {
    try {
      Logger.info('ApiService: Iniciando limpeza completa de autenticação');
      await clearAuthData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('jwt_token_saved_time');
      await prefs.remove('user_data');
      clearLocalCache();
      Logger.info('ApiService: Limpeza completa concluída');
    } catch (e) {
      Logger.error('ApiService: Erro na limpeza completa', error: e);
      rethrow;
    }
  }

  void dispose() {
    Logger.info('ApiService: Recursos liberados');
  }
}
