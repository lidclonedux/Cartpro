
// lib/models/product.dart - VERSÃO CORRIGIDA PARA PRODUCT_ID

import 'package:intl/intl.dart';
import '../utils/logger.dart'; // Para logs inteligentes

@pragma('vm:entry-point')
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stockQuantity;
  final String? imageUrl;
  final String categoryId;
  final String userId;
  final bool isActive;
  final bool isInStock;
  final bool isLowStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stockQuantity,
    this.imageUrl,
    required this.categoryId,
    required this.userId,
    required this.isActive,
    required this.isInStock,
    required this.isLowStock,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Retorna o preço formatado como string no padrão BRL.
  String get formattedPrice {
    final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatCurrency.format(price);
  }

  /// CORREÇÃO PRINCIPAL: fromJson com validação rigorosa de ID
  factory Product.fromJson(Map<String, dynamic> json) {
    // LOGS INTELIGENTES - Rastreamento detalhado da criação do produto
    final rawProductName = json['name'] ?? 'PRODUTO_SEM_NOME';
    final rawId = json['id'];
    final rawIdMongo = json['_id'];
    
    Logger.info('Product.fromJson: Processando produto "$rawProductName"');
    Logger.info('Product.fromJson: Raw ID: "$rawId", Raw _id: "$rawIdMongo"');
    
    // VALIDAÇÃO CRÍTICA DO ID
    String productId = '';
    
    // Tenta múltiplas fontes de ID em ordem de prioridade
    if (rawId != null && _isValidId(rawId)) {
      productId = rawId.toString();
      Logger.info('Product.fromJson: ID válido encontrado em "id": "$productId"');
    } else if (rawIdMongo != null && _isValidId(rawIdMongo)) {
      productId = rawIdMongo.toString();
      Logger.info('Product.fromJson: ID válido encontrado em "_id": "$productId"');
    } else {
      // LOG CRÍTICO - Produto inválido detectado
      Logger.error('Product.fromJson: PRODUTO INVÁLIDO REJEITADO!');
      Logger.error('Product.fromJson: Nome: "$rawProductName"');
      Logger.error('Product.fromJson: ID recebido: "$rawId"');
      Logger.error('Product.fromJson: _ID recebido: "$rawIdMongo"');
      Logger.error('Product.fromJson: Este produto será rejeitado para prevenir erros no carrinho');
      
      throw ProductValidationException(
        'Produto inválido: "$rawProductName" não possui um ID válido. '
        'ID recebido: "$rawId", _id recebido: "$rawIdMongo". '
        'Este produto foi rejeitado para prevenir erros no carrinho.'
      );
    }
    
    // VALIDAÇÃO DE DADOS ESSENCIAIS
    final productName = json['name']?.toString().trim() ?? '';
    if (productName.isEmpty) {
      Logger.error('Product.fromJson: Produto com ID "$productId" não tem nome válido');
      throw ProductValidationException('Produto com ID "$productId" não possui nome válido');
    }
    
    final productPrice = (json['price'] ?? 0).toDouble();
    if (productPrice < 0) {
      Logger.warning('Product.fromJson: Produto "$productName" tem preço negativo: $productPrice');
    }
    
    final productStock = json['stock_quantity'] ?? 0;
    final userId = json['user_id']?.toString() ?? '';
    final categoryId = json['category_id']?.toString() ?? '';
    
    // LOG DE SUCESSO COM DADOS IMPORTANTES
    Logger.info('Product.fromJson: ✅ Produto "$productName" criado com sucesso');
    Logger.info('Product.fromJson: ✅ ID: "$productId", Preço: R\$ ${productPrice.toStringAsFixed(2)}, Estoque: $productStock');
    
    return Product(
      id: productId,
      name: productName,
      description: json['description']?.toString() ?? '',
      price: productPrice,
      stockQuantity: productStock,
      imageUrl: json['image_url']?.toString(),
      categoryId: categoryId,
      userId: userId,
      isActive: json['is_active'] ?? false,
      isInStock: json['is_in_stock'] ?? false,
      isLowStock: json['is_low_stock'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  /// VALIDAÇÃO INTELIGENTE DE ID
  /// Verifica se um ID é válido para uso no sistema
  static bool _isValidId(dynamic id) {
    if (id == null) return false;
    
    final idString = id.toString().trim();
    
    // Lista de valores inválidos conhecidos
    final invalidValues = [
      '', 
      'None', 
      'null', 
      'undefined', 
      'NULL', 
      'NONE',
      '0',
      'false',
      'true'
    ];
    
    if (invalidValues.contains(idString)) {
      Logger.warning('Product._isValidId: ID inválido detectado: "$idString"');
      return false;
    }
    
    // Para ObjectIds do MongoDB, deve ter 24 caracteres hexadecimais
    if (idString.length == 24 && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(idString)) {
      return true;
    }
    
    // Para outros IDs, deve ter pelo menos 8 caracteres e não ser só números
    if (idString.length >= 8 && !RegExp(r'^[0-9]+$').hasMatch(idString)) {
      return true;
    }
    
    Logger.warning('Product._isValidId: ID com formato inválido: "$idString" (tamanho: ${idString.length})');
    return false;
  }

  /// Converte a instância de Product para um Map (JSON para enviar à API).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'category_id': categoryId,
      'user_id': userId,
      'is_active': isActive,
    };
  }

  /// Cria uma cópia do produto com alguns campos alterados.
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stockQuantity,
    String? imageUrl,
    String? categoryId,
    String? userId,
    bool? isActive,
    bool? isInStock,
    bool? isLowStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      isInStock: isInStock ?? this.isInStock,
      isLowStock: isLowStock ?? this.isLowStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $formattedPrice, stock: $stockQuantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// EXCEÇÃO CUSTOMIZADA PARA PRODUTOS INVÁLIDOS
@pragma('vm:entry-point')
class ProductValidationException implements Exception {
  final String message;
  
  ProductValidationException(this.message);
  
  @override
  String toString() => 'ProductValidationException: $message';
}
