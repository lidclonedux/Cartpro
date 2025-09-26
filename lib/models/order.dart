// Funções auxiliares seguras para conversão de tipos
double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

List<T> _parseList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  if (value == null) return [];
  if (value is List) {
    return value.map((item) {
      try {
        if (item is Map<String, dynamic>) {
          return fromJson(item);
        }
        return null;
      } catch (e) {
        return null;
      }
    }).where((item) => item != null).cast<T>().toList();
  }
  return [];
}

/// CORREÇÃO: Classe para endereço de entrega estruturado
@pragma('vm:entry-point')
class DeliveryAddress {
  final String street;
  final String? number;
  final String city;

  DeliveryAddress({
    required this.street,
    this.number,
    required this.city,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      street: json['street']?.toString() ?? '',
      number: json['number']?.toString(),
      city: json['city']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'number': number,
      'city': city,
    };
  }

  @override
  String toString() {
    if (number != null && number!.isNotEmpty) {
      return '$street, $number - $city';
    }
    return '$street, $city';
  }

  bool get isValid {
    return street.isNotEmpty && city.isNotEmpty;
  }
}

@pragma('vm:entry-point')
class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      price: _parseDouble(json['price']),
      quantity: (json['quantity'] is int) ? json['quantity'] : 
                (json['quantity'] is String) ? int.tryParse(json['quantity']) ?? 0 : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
    };
  }

  double get subtotal => price * quantity;
  String get formattedSubtotal => 'R\$ ${subtotal.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  String toString() {
    return 'OrderItem(productName: $productName, quantity: $quantity, subtotal: $formattedSubtotal)';
  }
}

@pragma('vm:entry-point')
class CustomerInfo {
  final String name;
  final String email;
  final String phone;
  final String? address; // Campo legado, mantido para compatibilidade
  final String? city; // Campo legado, mantido para compatibilidade
  final bool isDelivery;

  CustomerInfo({
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.city,
    required this.isDelivery,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      isDelivery: json['is_delivery'] == true || json['is_delivery'] == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'is_delivery': isDelivery,
    };
  }

  @override
  String toString() {
    return 'CustomerInfo(name: $name, email: $email, isDelivery: $isDelivery)';
  }
}

@pragma('vm:entry-point')
class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final CustomerInfo customerInfo;
  final double totalAmount;
  final String status;
  final String? payment_method;
  final String? payment_proof_url;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  /// CORREÇÃO CRÍTICA: Campo de endereço estruturado
  final DeliveryAddress? deliveryAddress;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.customerInfo,
    required this.totalAmount,
    required this.status,
    this.payment_method,
    this.payment_proof_url,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryAddress,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      return Order(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        items: _parseList<OrderItem>(json['items'], OrderItem.fromJson),
        customerInfo: CustomerInfo.fromJson(json['customer_info'] as Map<String, dynamic>? ?? {}),
        totalAmount: _parseDouble(json['total_amount']),
        status: json['status']?.toString() ?? 'pending',
        payment_method: json['payment_method']?.toString(),
        payment_proof_url: json['payment_proof_url']?.toString() ?? json['paymentProof']?.toString(),
        notes: json['notes']?.toString(),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),

        /// CORREÇÃO: Parse do endereço estruturado
        deliveryAddress: _parseDeliveryAddress(json['delivery_address']),
      );
    } catch (e, stackTrace) {
      // Log detalhado do erro mas não quebra o app
      print('🚨 ERRO AO PROCESSAR PEDIDO - DADOS PROBLEMÁTICOS:');
      print('ERRO: $e');
      print('STACK: $stackTrace');
      print('JSON: $json');
      
      // Retorna um pedido de erro em vez de quebrar
      return Order(
        id: 'erro_${DateTime.now().millisecondsSinceEpoch}',
        userId: '',
        items: [],
        customerInfo: CustomerInfo(
          name: 'Erro ao carregar dados',
          email: 'erro@sistema.com',
          phone: '(00) 00000-0000',
          isDelivery: false,
        ),
        totalAmount: 0.0,
        status: 'error',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryAddress: null,
      );
    }
  }

  /// CORREÇÃO: Método auxiliar para parse seguro do endereço
  static DeliveryAddress? _parseDeliveryAddress(dynamic addressData) {
    if (addressData == null) return null;
    
    try {
      if (addressData is Map<String, dynamic>) {
        // Se é um objeto, faz parse normal
        return DeliveryAddress.fromJson(addressData);
      } else if (addressData is String && addressData.isNotEmpty) {
        // Se é uma string (formato legado), tenta converter
        return DeliveryAddress(
          street: addressData,
          city: 'Não informado',
        );
      }
    } catch (e) {
      print('Erro ao fazer parse do endereço: $e');
    }
    
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'customer_info': customerInfo.toJson(),
      'total_amount': totalAmount,
      'status': status,
      'payment_method': payment_method,
      'payment_proof_url': payment_proof_url,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'delivery_address': deliveryAddress?.toJson(),
    };
  }

  // Getters formatados
  String get formattedTotal => 'R\$ ${totalAmount.toStringAsFixed(2).replaceAll('.', ',')}';
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  // Status checkers
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isShipped => status == 'shipped';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isError => status == 'error';

  String get formattedStatus {
    switch (status) {
      case 'pending':
        return 'Aguardando Confirmação';
      case 'confirmed':
        return 'Confirmado';
      case 'shipped':
        return 'Enviado';
      case 'delivered':
        return 'Entregue';
      case 'cancelled':
        return 'Cancelado';
      case 'error':
        return 'Erro nos Dados';
      default:
        return 'Status Desconhecido';
    }
  }

  /// CORREÇÃO: Método para verificar se os dados são válidos
  bool get isValid {
    return id.isNotEmpty && 
           id != 'erro_${DateTime.now().millisecondsSinceEpoch}' &&
           status != 'error' &&
           customerInfo.name.isNotEmpty;
  }

  /// Informações de pagamento formatadas
  String get paymentMethodDisplay {
    switch (payment_method?.toLowerCase()) {
      case 'pix':
        return 'PIX';
      case 'card':
        return 'Cartão';
      case 'cash':
        return 'Dinheiro';
      default:
        return 'A Combinar';
    }
  }

  bool get hasPaymentProof => payment_proof_url != null && payment_proof_url!.isNotEmpty;

  /// Informações de entrega
  String get deliveryMethodDisplay {
    return customerInfo.isDelivery ? 'Entrega' : 'Retirada';
  }

  String? get deliveryAddressDisplay {
    if (deliveryAddress != null && deliveryAddress!.isValid) {
      return deliveryAddress.toString();
    }
    // Fallback para campos legados
    if (customerInfo.address != null && customerInfo.address!.isNotEmpty) {
      if (customerInfo.city != null && customerInfo.city!.isNotEmpty) {
        return '${customerInfo.address}, ${customerInfo.city}';
      }
      return customerInfo.address;
    }
    return null;
  }

  Order copyWith({
    String? id,
    String? userId,
    List<OrderItem>? items,
    CustomerInfo? customerInfo,
    double? totalAmount,
    String? status,
    String? payment_method,
    String? payment_proof_url,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DeliveryAddress? deliveryAddress,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      customerInfo: customerInfo ?? this.customerInfo,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      payment_method: payment_method ?? this.payment_method,
      payment_proof_url: payment_proof_url ?? this.payment_proof_url,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }

  @override
  String toString() {
    return 'Order(id: $id, customer: ${customerInfo.name}, total: $formattedTotal, status: $formattedStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
