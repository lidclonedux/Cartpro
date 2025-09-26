
// lib/models/cart_item.dart

import 'product.dart';
import 'order.dart'; // CORREÇÃO: Importando o modelo 'order.dart' para ter acesso à classe 'OrderItem'.

@pragma('vm:entry-point')
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
    );
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  // CORREÇÃO: Adicionando o método de conversão que antes estava (incorretamente) no provider.
  /// Converte um CartItem em um OrderItem para a criação de pedidos.
  OrderItem toOrderItem() {
    return OrderItem(
      productId: product.id,
      productName: product.name,
      price: product.price,
      quantity: quantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && 
           other.product.id == product.id &&
           other.quantity == quantity;
  }

  @override
  int get hashCode => product.id.hashCode ^ quantity.hashCode;

  @override
  String toString() {
    return 'CartItem(product: ${product.name}, quantity: $quantity, totalPrice: $totalPrice)';
  }
}
