// lib/screens/cartpro/services/cart_validation_service.dart

import 'dart:io';
import '../../../providers/cart_provider.dart';
import '../models/checkout_form_data.dart';
import '../../../utils/logger.dart';

class CartValidationService {
  /// Valida o carrinho completo
  ValidationResult validateCart(CartProvider cartProvider) {
    Logger.info('CartValidationService: Validando carrinho');

    // Verificar se carrinho está vazio
    if (cartProvider.items.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Carrinho está vazio',
      );
    }

    // Verificar se todos os itens têm IDs válidos
    final invalidItems = <String>[];
    for (final item in cartProvider.cartItems) {
      if (!_isValidProductId(item.product.id)) {
        invalidItems.add(item.product.name);
        Logger.warning('CartValidationService: Produto com ID inválido: ${item.product.name} (ID: "${item.product.id}")');
      }
    }

    if (invalidItems.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Produtos com dados inválidos encontrados: ${invalidItems.join(', ')}. '
                     'Remova estes itens e adicione novamente.',
      );
    }

    // Verificar disponibilidade de estoque
    final outOfStockItems = <String>[];
    for (final item in cartProvider.cartItems) {
      if (item.quantity > item.product.stockQuantity) {
        outOfStockItems.add('${item.product.name} (solicitado: ${item.quantity}, disponível: ${item.product.stockQuantity})');
      }
    }

    if (outOfStockItems.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Estoque insuficiente para: ${outOfStockItems.join(', ')}',
      );
    }

    // Verificar valor mínimo do pedido (exemplo: R$ 10,00)
    const minOrderValue = 10.0;
    if (cartProvider.totalAmount < minOrderValue) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Valor mínimo do pedido: R\$ ${minOrderValue.toStringAsFixed(2)}',
      );
    }

    // Verificar se todos os produtos são do mesmo vendedor
    if (!_areAllProductsFromSameVendor(cartProvider)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Produtos de vendedores diferentes no carrinho. Finalize pedidos separadamente.',
      );
    }

    Logger.info('CartValidationService: ✅ Carrinho validado com sucesso');
    return ValidationResult(isValid: true);
  }

  /// Valida os dados do formulário de checkout
  ValidationResult validateCheckoutForm(CheckoutFormData formData) {
    Logger.info('CartValidationService: Validando dados do formulário');

    // Usar validação interna do modelo
    final validationError = formData.validationError;
    if (validationError != null) {
      return ValidationResult(
        isValid: false,
        errorMessage: validationError,
      );
    }

    // Validações adicionais específicas
    
    // Validar email mais rigorosamente
    if (!_isValidEmail(formData.email)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Formato de email inválido',
      );
    }

    // Validar telefone (formato básico)
    if (!_isValidPhone(formData.phone)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Formato de telefone inválido. Use formato: (xx) xxxxx-xxxx',
      );
    }

    // Validações específicas para entrega
    if (formData.isDelivery) {
      if (formData.address == null || formData.address!.trim().length < 10) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Endereço deve ter pelo menos 10 caracteres',
        );
      }

      if (formData.city == null || formData.city!.trim().length < 3) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Cidade deve ter pelo menos 3 caracteres',
        );
      }
    }

    Logger.info('CartValidationService: ✅ Formulário validado com sucesso');
    return ValidationResult(isValid: true);
  }

  /// Valida comprovante de pagamento
  Future<ValidationResult> validatePaymentProof(File? proofFile) async {
    Logger.info('CartValidationService: Validando comprovante de pagamento');

    if (proofFile == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Comprovante de pagamento é obrigatório',
      );
    }

    try {
      // Verificar se arquivo existe
      if (!await proofFile.exists()) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Arquivo de comprovante não encontrado',
        );
      }

      // Verificar tamanho (máximo 5MB)
      final fileSize = await proofFile.length();
      const maxSize = 5 * 1024 * 1024; // 5MB
      
      if (fileSize > maxSize) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Arquivo muito grande. Máximo: 5MB',
        );
      }

      if (fileSize == 0) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Arquivo está vazio',
        );
      }

      // Verificar extensão
      final extension = proofFile.path.toLowerCase().split('.').last;
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      
      if (!allowedExtensions.contains(extension)) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Formato não suportado. Use: JPG, PNG ou WEBP',
        );
      }

      Logger.info('CartValidationService: ✅ Comprovante validado com sucesso');
      return ValidationResult(isValid: true);

    } catch (e) {
      Logger.error('CartValidationService: Erro ao validar comprovante', error: e);
      return ValidationResult(
        isValid: false,
        errorMessage: 'Erro ao validar comprovante: ${e.toString()}',
      );
    }
  }

  /// Valida método de pagamento
  ValidationResult validatePaymentMethod(String paymentMethod) {
    const supportedMethods = ['pix', 'other'];
    
    if (!supportedMethods.contains(paymentMethod)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Método de pagamento não suportado: $paymentMethod',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validação completa antes de processar pedido
  Future<ValidationResult> validateCompleteOrder({
    required CartProvider cartProvider,
    required CheckoutFormData formData,
    File? proofImage,
  }) async {
    Logger.info('CartValidationService: Iniciando validação completa do pedido');

    // 1. Validar carrinho
    final cartValidation = validateCart(cartProvider);
    if (!cartValidation.isValid) {
      return cartValidation;
    }

    // 2. Validar formulário
    final formValidation = validateCheckoutForm(formData);
    if (!formValidation.isValid) {
      return formValidation;
    }

    // 3. Validar método de pagamento
    final paymentValidation = validatePaymentMethod(formData.paymentMethod);
    if (!paymentValidation.isValid) {
      return paymentValidation;
    }

    // 4. Validar comprovante (se necessário)
    if (formData.paymentMethod == 'pix') {
      final proofValidation = await validatePaymentProof(proofImage);
      if (!proofValidation.isValid) {
        return proofValidation;
      }
    }

    Logger.info('CartValidationService: ✅ Validação completa realizada com sucesso');
    return ValidationResult(isValid: true);
  }

  // MÉTODOS AUXILIARES PRIVADOS

  bool _isValidProductId(String id) {
    return id.isNotEmpty && 
           id != 'None' && 
           id != 'null' && 
           id != 'undefined' && 
           id.trim().isNotEmpty;
  }

  bool _areAllProductsFromSameVendor(CartProvider cartProvider) {
    if (cartProvider.cartItems.isEmpty) return true;
    
    final firstVendorId = cartProvider.cartItems.first.product.userId;
    return cartProvider.cartItems.every(
      (item) => item.product.userId == firstVendorId
    );
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

  /// Validações específicas para diferentes cenários
  ValidationResult validateDeliveryInfo({
    required bool isDelivery,
    String? address,
    String? city,
  }) {
    if (!isDelivery) {
      return ValidationResult(isValid: true);
    }

    if (address == null || address.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Endereço é obrigatório para entrega',
      );
    }

    if (address.trim().length < 10) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Endereço deve ser mais detalhado (mín. 10 caracteres)',
      );
    }

    if (city == null || city.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Cidade é obrigatória para entrega',
      );
    }

    if (city.trim().length < 3) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Nome da cidade deve ter pelo menos 3 caracteres',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Valida quantidade total de itens no carrinho
  ValidationResult validateCartQuantityLimits(CartProvider cartProvider) {
    const maxTotalItems = 50;
    const maxSingleItemQuantity = 10;

    final totalItems = cartProvider.cartItems.fold<int>(
      0, (sum, item) => sum + item.quantity
    );

    if (totalItems > maxTotalItems) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Quantidade máxima por pedido: $maxTotalItems itens',
      );
    }

    final itemsWithExcessiveQuantity = cartProvider.cartItems
        .where((item) => item.quantity > maxSingleItemQuantity)
        .map((item) => item.product.name)
        .toList();

    if (itemsWithExcessiveQuantity.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Quantidade máxima por item: $maxSingleItemQuantity. '
                     'Itens afetados: ${itemsWithExcessiveQuantity.join(', ')}',
      );
    }

    return ValidationResult(isValid: true);
  }
}

// Classe para resultado de validação
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? additionalData;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.additionalData,
  });

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, error: $errorMessage)';
  }
}