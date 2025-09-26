// lib/providers/cart_provider.dart

import 'package:flutter/foundation.dart';

// CORREÇÃO: Importando os modelos corretos de seus próprios arquivos.
// Isso resolve o erro de 'CartItem' duplicado e o erro de 'OrderItem' não encontrado.
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/*
// CORREÇÃO: O bloco de comentário agora está formatado corretamente com '/*' no início e '*/' no final.
// Manter esta classe aqui causa um erro de compilação porque o Dart não sabe
// se deve usar esta versão ou a versão de 'lib/models/cart_item.dart'.
// A lógica desta classe, especialmente o método 'toOrderItem', foi movida
// para o arquivo 'lib/models/cart_item.dart', que é o local correto para ela.

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  /// Calcula o subtotal do item (preço × quantidade)
  double get subtotal => product.price * quantity;

  /// Retorna o subtotal formatado como string
  String get formattedSubtotal => 'R\$ ${subtotal.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Converte para OrderItem (para criar pedidos)
  OrderItem toOrderItem() {
    return OrderItem(
      productId: product.id,
      productName: product.name,
      price: product.price,
      quantity: quantity,
    );
  }

  @override
  String toString() {
    return 'CartItem(product: ${product.name}, quantity: $quantity, subtotal: $formattedSubtotal)';
  }
}
*/

class CartProvider with ChangeNotifier {
  final ApiService? apiService;
  
  CartProvider(this.apiService);
  
  // Este Map agora usa a classe CartItem importada de 'lib/models/cart_item.dart'
  final Map<String, CartItem> _items = {};

  // Getters
  Map<String, CartItem> get items => _items;
  List<CartItem> get cartItems => _items.values.toList();
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  /// Calcula o total de itens no carrinho (soma das quantidades)
  int get totalQuantity {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Calcula o valor total do carrinho
  double get totalAmount {
    // CORREÇÃO: O getter 'subtotal' estava na classe comentada.
    // O modelo oficial 'CartItem' usa o getter 'totalPrice' para a mesma funcionalidade.
    return _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Retorna o valor total formatado como string
  String get formattedTotal => 'R\$ ${totalAmount.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Adiciona um produto ao carrinho
  void addToCart(Product product, {int quantity = 1}) {
    if (quantity <= 0) return;
    
    // Verifica se há estoque suficiente
    if (quantity > product.stockQuantity) {
      throw Exception('Estoque insuficiente. Disponível: ${product.stockQuantity}');
    }

    if (_items.containsKey(product.id)) {
      // Se o produto já está no carrinho, aumenta a quantidade
      final currentQuantity = _items[product.id]!.quantity;
      final newQuantity = currentQuantity + quantity;
      
      // Verifica se a nova quantidade não excede o estoque
      if (newQuantity > product.stockQuantity) {
        throw Exception('Estoque insuficiente. Disponível: ${product.stockQuantity}');
      }
      
      _items[product.id]!.quantity = newQuantity;
    } else {
      // Se é um produto novo, adiciona ao carrinho
      _items[product.id] = CartItem(
        product: product,
        quantity: quantity,
      );
    }
    
    notifyListeners();
  }

  /// Remove um produto do carrinho completamente
  void removeFromCart(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  /// Diminui a quantidade de um produto no carrinho
  void decreaseQuantity(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items[productId]!.quantity--;
    } else {
      _items.remove(productId);
    }
    
    notifyListeners();
  }

  /// Aumenta a quantidade de um produto no carrinho
  void increaseQuantity(String productId) {
    if (!_items.containsKey(productId)) return;

    final cartItem = _items[productId]!;
    final newQuantity = cartItem.quantity + 1;
    
    // Verifica se a nova quantidade não excede o estoque
    if (newQuantity > cartItem.product.stockQuantity) {
      throw Exception('Estoque insuficiente. Disponível: ${cartItem.product.stockQuantity}');
    }
    
    cartItem.quantity = newQuantity;
    notifyListeners();
  }

  /// Atualiza a quantidade de um produto específico
  void updateQuantity(String productId, int newQuantity) {
    if (!_items.containsKey(productId)) return;
    
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }
    
    final cartItem = _items[productId]!;
    
    // Verifica se a nova quantidade não excede o estoque
    if (newQuantity > cartItem.product.stockQuantity) {
      throw Exception('Estoque insuficiente. Disponível: ${cartItem.product.stockQuantity}');
    }
    
    cartItem.quantity = newQuantity;
    notifyListeners();
  }

  /// Verifica se um produto está no carrinho
  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  /// Retorna a quantidade de um produto no carrinho
  int getQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  /// Retorna um item específico do carrinho
  CartItem? getCartItem(String productId) {
    return _items[productId];
  }

  /// NOVO MÉTODO: Limpa todo o carrinho (para logout)
  void clearCart() {
    _items.clear();
    Logger.info('CartProvider.clearCart: ✅ Carrinho foi limpo');
    notifyListeners();
  }

  /// Converte os itens do carrinho para uma lista de OrderItem
  List<OrderItem> toOrderItems() {
    return _items.values.map((cartItem) => cartItem.toOrderItem()).toList();
  }

  /// Valida se todos os produtos no carrinho ainda têm estoque suficiente
  /// Retorna uma lista de produtos com problemas de estoque
  List<String> validateStock() {
    final problems = <String>[];
    
    for (final cartItem in _items.values) {
      if (cartItem.quantity > cartItem.product.stockQuantity) {
        problems.add('${cartItem.product.name}: solicitado ${cartItem.quantity}, disponível ${cartItem.product.stockQuantity}');
      }
    }
    
    return problems;
  }

  /// Remove produtos que não têm estoque suficiente
  void removeOutOfStockItems() {
    final toRemove = <String>[];
    
    for (final entry in _items.entries) {
      if (entry.value.quantity > entry.value.product.stockQuantity) {
        toRemove.add(entry.key);
      }
    }
    
    for (final productId in toRemove) {
      _items.remove(productId);
    }
    
    if (toRemove.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Ajusta as quantidades para o estoque disponível
  void adjustQuantitiesToStock() {
    bool hasChanges = false;
    
    for (final cartItem in _items.values) {
      if (cartItem.quantity > cartItem.product.stockQuantity) {
        cartItem.quantity = cartItem.product.stockQuantity;
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      notifyListeners();
    }
  }
}

