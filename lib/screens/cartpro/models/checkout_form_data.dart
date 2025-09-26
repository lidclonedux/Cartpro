// lib/screens/cartpro/models/checkout_form_data.dart

class CheckoutFormData {
  final String name;
  final String email;
  final String phone;
  final bool isDelivery;
  final String? address;
  final String? city;
  final String paymentMethod;

  CheckoutFormData({
    required this.name,
    required this.email,
    required this.phone,
    required this.isDelivery,
    this.address,
    this.city,
    required this.paymentMethod,
  });

  /// Verifica se todos os dados obrigatórios estão válidos
  bool get isValid {
    // Validações básicas
    if (name.trim().isEmpty || email.trim().isEmpty || phone.trim().isEmpty) {
      return false;
    }
    
    // Validação básica de email
    if (!email.contains('@') || !email.contains('.')) {
      return false;
    }
    
    // Validações específicas para entrega
    if (isDelivery) {
      if (address == null || city == null || 
          address!.trim().isEmpty || city!.trim().isEmpty) {
        return false;
      }
    }
    
    return true;
  }

  /// Retorna a primeira mensagem de erro encontrada, ou null se válido
  String? get validationError {
    // Validar nome
    if (name.trim().isEmpty) {
      return 'Nome é obrigatório';
    }
    if (name.trim().length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }
    
    // Validar email
    if (email.trim().isEmpty) {
      return 'Email é obrigatório';
    }
    if (!_isValidEmail(email)) {
      return 'Email inválido';
    }
    
    // Validar telefone
    if (phone.trim().isEmpty) {
      return 'Telefone é obrigatório';
    }
    if (!_isValidPhone(phone)) {
      return 'Formato de telefone inválido';
    }
    
    // Validações para entrega
    if (isDelivery) {
      if (address == null || address!.trim().isEmpty) {
        return 'Endereço é obrigatório para entrega';
      }
      if (address!.trim().length < 10) {
        return 'Endereço deve ser mais detalhado (mín. 10 caracteres)';
      }
      if (city == null || city!.trim().isEmpty) {
        return 'Cidade é obrigatória para entrega';
      }
      if (city!.trim().length < 3) {
        return 'Cidade deve ter pelo menos 3 caracteres';
      }
    }
    
    return null; // Sem erros
  }

  /// Converte para JSON para envio à API
  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'is_delivery': isDelivery,
      'address': isDelivery ? address?.trim() : null,
      'city': isDelivery ? city?.trim() : null,
      'delivery_address': isDelivery ? _getFullAddress() : null,
      'payment_method': paymentMethod,
    };
  }

  /// Cria uma cópia com alguns campos alterados
  CheckoutFormData copyWith({
    String? name,
    String? email,
    String? phone,
    bool? isDelivery,
    String? address,
    String? city,
    String? paymentMethod,
  }) {
    return CheckoutFormData(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isDelivery: isDelivery ?? this.isDelivery,
      address: address ?? this.address,
      city: city ?? this.city,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  /// Cria instância a partir de JSON
  factory CheckoutFormData.fromJson(Map<String, dynamic> json) {
    return CheckoutFormData(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      isDelivery: json['is_delivery'] ?? true,
      address: json['address'],
      city: json['city'],
      paymentMethod: json['payment_method'] ?? 'pix',
    );
  }

  /// Cria uma instância vazia para inicialização de formulários
  factory CheckoutFormData.empty() {
    return CheckoutFormData(
      name: '',
      email: '',
      phone: '',
      isDelivery: true,
      paymentMethod: 'pix',
    );
  }

  /// Obtém resumo dos dados para exibição
  Map<String, String> get summary {
    final Map<String, String> summary = {
      'Nome': name.trim(),
      'Email': email.trim(),
      'Telefone': phone.trim(),
      'Entrega': isDelivery ? 'Sim' : 'Retirada no local',
      'Pagamento': _getPaymentMethodDisplayName(),
    };

    if (isDelivery && address != null && city != null) {
      summary['Endereço'] = _getFullAddress();
    }

    return summary;
  }

  // MÉTODOS AUXILIARES PRIVADOS

  String _getFullAddress() {
    if (!isDelivery || address == null || city == null) return '';
    return '${address!.trim()}, ${city!.trim()}';
  }

  String _getPaymentMethodDisplayName() {
    switch (paymentMethod) {
      case 'pix':
        return 'PIX com comprovante';
      case 'other':
        return 'A combinar com vendedor';
      default:
        return 'Método não definido';
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    return emailRegex.hasMatch(email.trim());
  }

  bool _isValidPhone(String phone) {
    // Remove todos os caracteres não numéricos
    final numbersOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Aceita números com 10 ou 11 dígitos (com ou sem DDD)
    return numbersOnly.length >= 10 && numbersOnly.length <= 11;
  }

  @override
  String toString() {
    return 'CheckoutFormData('
           'name: $name, '
           'email: $email, '
           'isDelivery: $isDelivery, '
           'paymentMethod: $paymentMethod'
           ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is CheckoutFormData &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        other.isDelivery == isDelivery &&
        other.address == address &&
        other.city == city &&
        other.paymentMethod == paymentMethod;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        email.hashCode ^
        phone.hashCode ^
        isDelivery.hashCode ^
        (address?.hashCode ?? 0) ^
        (city?.hashCode ?? 0) ^
        paymentMethod.hashCode;
  }
}

/// Extensões úteis para CheckoutFormData
extension CheckoutFormDataExtensions on CheckoutFormData {
  /// Verifica se é um pedido para entrega
  bool get isDeliveryOrder => isDelivery;
  
  /// Verifica se é um pedido para retirada
  bool get isPickupOrder => !isDelivery;
  
  /// Verifica se o pagamento é PIX
  bool get isPixPayment => paymentMethod == 'pix';
  
  /// Verifica se o pagamento é a combinar
  bool get isOtherPayment => paymentMethod == 'other';
  
  /// Obtém informações de contato formatadas
  String get contactInfo => 'Email: $email\nTelefone: $phone';
  
  /// Obtém endereço completo se for entrega
  String? get fullDeliveryAddress => isDelivery ? _getFullAddress() : null;
}