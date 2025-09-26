// lib/providers/product_provider.dart - VERSÃO CORRIGIDA PARA DISPOSE

import 'package:flutter/foundation.dart' hide Category;
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class ProductProvider with ChangeNotifier {
  final ApiService? apiService;

  // ✅ CORREÇÃO: Adicionar flag para controlar dispose
  bool _disposed = false;

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  ProductProvider(this.apiService);

  // Getters com verificação de dispose
  List<Product> get products => _disposed ? [] : _products;
  List<Category> get categories => _disposed ? [] : _categories;
  bool get isLoading => _disposed ? false : _isLoading;
  String? get errorMessage => _disposed ? null : _errorMessage;

  // ✅ CORREÇÃO: Override do dispose com flag de controle
  @override
  void dispose() {
    Logger.info('ProductProvider.dispose: Iniciando dispose do ProductProvider');
    _disposed = true;
    super.dispose();
  }

  // ✅ CORREÇÃO: Verificação de dispose antes de qualquer operação
  bool _checkDisposed() {
    if (_disposed) {
      Logger.warning('ProductProvider: Tentativa de uso após dispose - operação cancelada');
      return true;
    }
    return false;
  }

  // ✅ CORREÇÃO: Método seguro para notificar listeners
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Busca as categorias da API
  Future<void> fetchCategories() async {
    if (_checkDisposed()) return;
    
    if (apiService == null) {
      _setError('Serviço de API não inicializado.');
      return;
    }
    
    _clearError();
    
    try {
      Logger.info('ProductProvider.fetchCategories: Iniciando busca de categorias');
      
      final response = await apiService!.getCategories(context: 'product');
      
      if (_checkDisposed()) return; // Verificar novamente após async
      
      _categories = response.map((json) => Category.fromJson(json)).toList();
      
      Logger.info('ProductProvider.fetchCategories: ✅ ${_categories.length} categorias carregadas com sucesso');
    } catch (e) {
      if (_checkDisposed()) return;
      
      _setError('Erro ao carregar categorias: ${e.toString()}');
      Logger.error('ProductProvider.fetchCategories: Falha ao carregar categorias', error: e);
    }
    _safeNotifyListeners();
  }

  /// Busca os produtos da API com tratamento inteligente de produtos inválidos
  Future<void> fetchProducts({String? userId}) async {
    if (_checkDisposed()) return;
    
    if (apiService == null) {
      _setError('Serviço de API não inicializado.');
      return;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      Logger.info('ProductProvider.fetchProducts: Iniciando busca de produtos${userId != null ? ' para usuário $userId' : ''}');
      
      final response = await apiService!.getProducts(userId: userId);
      
      if (_checkDisposed()) return;
      
      Logger.info('ProductProvider.fetchProducts: Recebidos ${response.length} produtos válidos da API');
      
      final validProducts = <Product>[];
      final invalidProducts = <String>[];
      
      // Processamento com tratamento de erros
      for (int i = 0; i < response.length; i++) {
        try {
          final product = Product.fromJson(response[i]);
          validProducts.add(product);
          
          if (i < 3) { // Log apenas primeiros 3 para não poluir
            Logger.info('ProductProvider.fetchProducts: Produto criado: "${product.name}" (${product.formattedPrice})');
          }
          
        } catch (e) {
          final productName = response[i]['name'] ?? 'PRODUTO_${i + 1}';
          invalidProducts.add(productName);
          
          if (e.toString().contains('ProductValidationException')) {
            Logger.warning('ProductProvider.fetchProducts: Produto inválido rejeitado: "$productName" - $e');
          } else {
            Logger.error('ProductProvider.fetchProducts: Erro ao processar produto "$productName": $e');
          }
        }
      }
      
      _products = validProducts;
      
      Logger.info('ProductProvider.fetchProducts: ✅ ${validProducts.length} produtos carregados com sucesso');
      
      if (invalidProducts.isNotEmpty) {
        Logger.warning('ProductProvider.fetchProducts: 🚨 ${invalidProducts.length} produto(s) inválido(s) ignorado(s)');
        Logger.warning('ProductProvider.fetchProducts: Produtos problemáticos: ${invalidProducts.join(', ')}');
        
        if (invalidProducts.length > validProducts.length * 0.1) {
          _setError('Alguns produtos têm dados inconsistentes e foram ignorados.\nProdutos válidos carregados: ${validProducts.length}');
        }
      }
      
      if (validProducts.isEmpty && response.isNotEmpty) {
        Logger.error('ProductProvider.fetchProducts: 🚨 CRÍTICO: Todos os produtos são inválidos!');
        _setError('Todos os produtos da API são inválidos. Verifique o backend.');
      }
      
    } catch (e) {
      if (_checkDisposed()) return;
      
      _setError('Erro ao carregar produtos: ${e.toString()}');
      Logger.error('ProductProvider.fetchProducts: Falha geral ao carregar produtos', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Adiciona um novo produto
  Future<bool> addProduct(Product product) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) {
      _setError('Serviço de API não inicializado.');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      Logger.info('ProductProvider.addProduct: Criando produto "${product.name}"');
      
      final responseJson = await apiService!.createProduct(product.toJson());
      
      if (_checkDisposed()) return false;
      
      final newProduct = Product.fromJson(responseJson);
      _products.add(newProduct);
      
      Logger.info('ProductProvider.addProduct: ✅ Produto "${newProduct.name}" criado com sucesso (ID: ${newProduct.id})');
      _safeNotifyListeners();
      return true;
      
    } catch (e) {
      if (_checkDisposed()) return false;
      
      _setError('Erro ao adicionar produto: ${e.toString()}');
      Logger.error('ProductProvider.addProduct: Falha ao adicionar produto "${product.name}"', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza um produto existente
  Future<bool> updateProduct(Product product) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) {
      _setError('Serviço de API não inicializado.');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      Logger.info('ProductProvider.updateProduct: Atualizando produto "${product.name}" (ID: ${product.id})');
      
      final responseJson = await apiService!.updateProduct(product.id, product.toJson());
      
      if (_checkDisposed()) return false;
      
      final updatedProduct = Product.fromJson(responseJson);
      final index = _products.indexWhere((p) => p.id == product.id);
      
      if (index != -1) {
        _products[index] = updatedProduct;
        Logger.info('ProductProvider.updateProduct: ✅ Produto atualizado com sucesso');
        _safeNotifyListeners();
      }
      return true;
      
    } catch (e) {
      if (_checkDisposed()) return false;
      
      _setError('Erro ao atualizar produto: ${e.toString()}');
      Logger.error('ProductProvider.updateProduct: Falha ao atualizar produto', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove um produto
  Future<bool> deleteProduct(String productId) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) {
      _setError('Serviço de API não inicializado.');
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      final productName = _products.firstWhere((p) => p.id == productId).name;
      Logger.info('ProductProvider.deleteProduct: Removendo produto "$productName" (ID: $productId)');
      
      await apiService!.deleteProduct(productId);
      
      if (_checkDisposed()) return false;
      
      _products.removeWhere((p) => p.id == productId);
      
      Logger.info('ProductProvider.deleteProduct: ✅ Produto removido com sucesso');
      _safeNotifyListeners();
      return true;
      
    } catch (e) {
      if (_checkDisposed()) return false;
      
      _setError('Erro ao remover produto: ${e.toString()}');
      Logger.error('ProductProvider.deleteProduct: Falha ao remover produto', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Recarrega categorias e produtos
  Future<void> refresh({String? userId}) async {
    if (_checkDisposed()) return;
    
    Logger.info('ProductProvider.refresh: Iniciando refresh completo${userId != null ? ' para usuário $userId' : ''}');
    
    await fetchCategories();
    await fetchProducts(userId: userId);
    
    Logger.info('ProductProvider.refresh: ✅ Refresh completo finalizado - ${_categories.length} categorias, ${_products.length} produtos');
  }

  // --- MÉTODOS DE CATEGORIA ---
  
  /// Adiciona uma nova categoria
  Future<void> addCategory(String name) async {
    if (_checkDisposed()) return;
    
    if (apiService == null) throw Exception('Serviço de API não inicializado.');
    
    _setLoading(true);
    _clearError();
    
    try {
      Logger.info('ProductProvider.addCategory: Criando categoria "$name"');
      
      final json = await apiService!.createCategory(name, context: 'product');
      
      if (_checkDisposed()) return;
      
      final newCategory = Category.fromJson(json);
      _categories.add(newCategory);
      
      Logger.info('ProductProvider.addCategory: ✅ Categoria "$name" criada (ID: ${newCategory.id})');
      _safeNotifyListeners();
      
    } catch (e) {
      if (_checkDisposed()) return;
      
      _setError('Erro ao adicionar categoria: ${e.toString()}');
      Logger.error('ProductProvider.addCategory: Falha ao adicionar categoria "$name"', error: e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza uma categoria
  Future<bool> updateCategory(Category category) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) throw Exception('Serviço de API não inicializado.');
    
    _setLoading(true);
    _clearError();
    
    try {
      Logger.info('ProductProvider.updateCategory: Atualizando categoria "${category.name}" (ID: ${category.id})');
      
      final json = await apiService!.updateCategory(category.id, category.toJson());
      
      if (_checkDisposed()) return false;
      
      final updatedCategory = Category.fromJson(json);
      final index = _categories.indexWhere((c) => c.id == category.id);
      
      if (index != -1) {
        _categories[index] = updatedCategory;
        Logger.info('ProductProvider.updateCategory: ✅ Categoria atualizada com sucesso');
        _safeNotifyListeners();
      }
      return true;
      
    } catch (e) {
      if (_checkDisposed()) return false;
      
      _setError('Erro ao atualizar categoria: ${e.toString()}');
      Logger.error('ProductProvider.updateCategory: Falha ao atualizar categoria', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove uma categoria
  Future<bool> deleteCategory(String categoryId) async {
    if (_checkDisposed()) return false;
    
    if (apiService == null) throw Exception('Serviço de API não inicializado.');
    
    _setLoading(true);
    _clearError();
    
    try {
      final categoryName = _categories.firstWhere((c) => c.id == categoryId).name;
      Logger.info('ProductProvider.deleteCategory: Removendo categoria "$categoryName" (ID: $categoryId)');
      
      await apiService!.deleteCategory(categoryId);
      
      if (_checkDisposed()) return false;
      
      _categories.removeWhere((c) => c.id == categoryId);
      
      Logger.info('ProductProvider.deleteCategory: ✅ Categoria removida com sucesso');
      _safeNotifyListeners();
      return true;
      
    } catch (e) {
      if (_checkDisposed()) return false;
      
      _setError('Erro ao remover categoria: ${e.toString()}');
      Logger.error('ProductProvider.deleteCategory: Falha ao remover categoria', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cria categorias padrão
  Future<void> seedDefaultCategories() async {
    if (_checkDisposed()) return;
    
    if (apiService == null) throw Exception('Serviço de API não inicializado.');
    
    _setLoading(true);
    _clearError();
    
    try {
      Logger.info('ProductProvider.seedDefaultCategories: Criando categorias padrão');
      
      await apiService!.seedDefaultCategories();
      
      if (_checkDisposed()) return;
      
      await fetchCategories();
      
      Logger.info('ProductProvider.seedDefaultCategories: ✅ Categorias padrão criadas com sucesso');
    } catch (e) {
      if (_checkDisposed()) return;
      
      _setError('Erro ao criar categorias padrão: ${e.toString()}');
      Logger.error('ProductProvider.seedDefaultCategories: Falha ao criar categorias padrão', error: e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODOS AUXILIARES ---

  /// Obtém nome da categoria por ID
  String getCategoryNameById(String? categoryId) {
    if (_checkDisposed() || categoryId == null || categoryId.isEmpty) {
      return 'Sem Categoria';
    }
    
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId).name;
    } catch (e) {
      Logger.warning('ProductProvider.getCategoryNameById: Categoria não encontrada para ID: $categoryId');
      return 'Categoria Desconhecida';
    }
  }

  /// Obtém produto por ID
  Product? getProductById(String productId) {
    if (_checkDisposed()) return null;
    
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      Logger.warning('ProductProvider.getProductById: Produto não encontrado para ID: $productId');
      return null;
    }
  }

  /// Busca produtos por query
  List<Product> searchProducts(String query) {
    if (_checkDisposed() || query.isEmpty) return _products;
    
    final lowerQuery = query.toLowerCase();
    
    final results = _products.where((product) {
      final categoryName = getCategoryNameById(product.categoryId).toLowerCase();
      return product.name.toLowerCase().contains(lowerQuery) ||
             product.description.toLowerCase().contains(lowerQuery) ||
             categoryName.contains(lowerQuery);
    }).toList();
    
    Logger.info('ProductProvider.searchProducts: Busca por "$query" retornou ${results.length} resultado(s)');
    return results;
  }

  /// Limpa todos os dados (para logout)
  void clearAllData() {
    if (_checkDisposed()) return;
    
    _products.clear();
    _categories.clear();
    _clearError();
    Logger.info('ProductProvider.clearAllData: ✅ Todos os produtos e categorias foram limpos');
    _safeNotifyListeners();
  }

  // Métodos de gerenciamento de estado
  void _setLoading(bool loading) {
    if (_checkDisposed()) return;
    _isLoading = loading;
    _safeNotifyListeners();
  }

  void _setError(String error) {
    if (_checkDisposed()) return;
    _errorMessage = error;
  }

  void _clearError() {
    if (_checkDisposed()) return;
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    _safeNotifyListeners();
  }

  // Filtros e estatísticas
  List<Product> get productsInStock => _disposed ? [] : _products.where((p) => p.isInStock).toList();
  List<Product> get productsLowStock => _disposed ? [] : _products.where((p) => p.isLowStock).toList();
  List<Product> get inactiveProducts => _disposed ? [] : _products.where((p) => !p.isActive).toList();
  
  int get totalActiveProducts => _disposed ? 0 : _products.where((p) => p.isActive).length;
  int get totalProductsInStock => _disposed ? 0 : _products.where((p) => p.isInStock).length;
  double get totalStockValue => _disposed ? 0.0 : _products.fold(0.0, (sum, p) => sum + (p.price * p.stockQuantity));
}
