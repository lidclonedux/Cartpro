// lib/screens/cartpro/services/cart_order_service.dart - VERSÃO COMPLETA E CORRIGIDA

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../providers/cart_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/auth_provider.dart';

// Models
import '../models/checkout_form_data.dart';
import '../models/payment_method_info.dart'; // Importação corrigida

// Services
import 'cart_validation_service.dart';
import 'cart_payment_service.dart';

// Utils
import '../../../utils/logger.dart';

class CartOrderService {
  final CartValidationService _validationService;
  final CartPaymentService _paymentService;

  CartOrderService({
    CartValidationService? validationService,
    CartPaymentService? paymentService,
  })  : _validationService = validationService ?? CartValidationService(),
        _paymentService = paymentService ?? CartPaymentService();

  /// Processa um pedido completo com todas as validações e upload de comprovante
  Future<bool> processOrder({
    required CartProvider cartProvider,
    required CheckoutFormData formData,
    required StorePaymentInfo storeInfo,
    required OrderProvider orderProvider,
    required AuthProvider authProvider,
    File? proofImage,
  }) async {
    try {
      Logger.info('CartOrderService: Iniciando processamento do pedido');

      // PASSO 1: Validações iniciais
      final validation = await _validateOrderRequest(
        cartProvider: cartProvider,
        formData: formData,
        authProvider: authProvider,
        proofImage: proofImage,
      );

      if (!validation.isValid) {
        Logger.warning('CartOrderService: Validação falhou: ${validation.errorMessage}');
        return false;
      }

      // PASSO 2: Upload do comprovante (se necessário)
      String? paymentProofUrl;
      if (formData.paymentMethod == 'pix' && proofImage != null) {
        paymentProofUrl = await _uploadPaymentProof(authProvider, proofImage);
        if (paymentProofUrl == null) {
          Logger.error('CartOrderService: Falha no upload do comprovante');
          return false;
        }
      }

      // PASSO 3: Criar pedido
      final success = await _createOrder(
        cartProvider: cartProvider,
        formData: formData,
        storeInfo: storeInfo,
        orderProvider: orderProvider,
        authProvider: authProvider,
        paymentProofUrl: paymentProofUrl,
      );

      if (success) {
        Logger.info('CartOrderService: Pedido criado com sucesso');
      } else {
        Logger.error('CartOrderService: Falha ao criar pedido');
      }

      return success;

    } catch (e) {
      Logger.error('CartOrderService: Erro inesperado no processamento', error: e);
      return false;
    }
  }

  /// Versão alternativa que recebe providers diretamente
  Future<bool> processOrderDirect({
    required CartProvider cartProvider,
    required CheckoutFormData formData,
    required StorePaymentInfo storeInfo,
    required OrderProvider orderProvider,
    required AuthProvider authProvider,
    File? proofImage,
  }) {
    return processOrder(
      cartProvider: cartProvider,
      formData: formData,
      storeInfo: storeInfo,
      orderProvider: orderProvider,
      authProvider: authProvider,
      proofImage: proofImage,
    );
  }

  // VALIDAÇÕES COMPLETAS
  Future<ValidationResult> _validateOrderRequest({
    required CartProvider cartProvider,
    required CheckoutFormData formData,
    required AuthProvider authProvider,
    File? proofImage,
  }) async {
    // Validar carrinho
    final cartValidation = _validationService.validateCart(cartProvider);
    if (!cartValidation.isValid) {
      return cartValidation;
    }

    // Validar dados do formulário
    final formValidation = _validationService.validateCheckoutForm(formData);
    if (!formValidation.isValid) {
      return formValidation;
    }

    // Validar comprovante PIX (se necessário)
    if (formData.paymentMethod == 'pix') {
      final proofValidation = await _validationService.validatePaymentProof(proofImage);
      if (!proofValidation.isValid) {
        return proofValidation;
      }
    }

    // Validar autenticação
    if (authProvider.currentUser == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Usuário não autenticado',
      );
    }

    if (authProvider.apiService == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Serviço de API não disponível',
      );
    }

    // Validar produtos no carrinho
    final invalidProducts = <String>[];
    for (final item in cartProvider.cartItems) {
      if (item.product.id.isEmpty || 
          item.product.id == 'None' || 
          item.product.id == 'null' ||
          item.product.id == 'undefined') {
        invalidProducts.add(item.product.name);
      }
    }

    if (invalidProducts.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Produtos com dados inválidos: ${invalidProducts.join(', ')}. '
                     'Remova e adicione novamente.',
      );
    }

    return ValidationResult(isValid: true);
  }

  // UPLOAD DO COMPROVANTE
  Future<String?> _uploadPaymentProof(AuthProvider authProvider, File proofImage) async {
    try {
      Logger.info('CartOrderService: Iniciando upload do comprovante');

      final apiService = authProvider.apiService;

      if (apiService == null) {
        Logger.error('CartOrderService: Serviço de API não disponível para upload');
        return null;
      }

      final paymentProofUrl = await apiService.uploadPaymentProof(
        imageFile: proofImage,
        description: 'Comprovante de pedido',
      );

      Logger.info('CartOrderService: Upload concluído: $paymentProofUrl');
      return paymentProofUrl;

    } catch (e) {
      Logger.error('CartOrderService: Erro no upload do comprovante', error: e);
      return null;
    }
  }

  // CRIAÇÃO DO PEDIDO
  Future<bool> _createOrder({
    required CartProvider cartProvider,
    required CheckoutFormData formData,
    required StorePaymentInfo storeInfo,
    required OrderProvider orderProvider,
    required AuthProvider authProvider,
    String? paymentProofUrl,
  }) async {
    try {
      final currentClient = authProvider.currentUser!;
      final storeOwnerId = cartProvider.cartItems.first.product.userId;

      // ===================== INÍCIO DA INTERVENÇÃO CIRÚRGICA =====================
      // DIAGNÓSTICO: O log anterior mostrava que 'delivery_address' era uma string.
      // O backend espera um objeto (Map).
      //
      // PROCEDIMENTO: Montar um Map para 'delivery_address' quando for entrega,
      // e enviar 'null' quando for retirada.
      
      final Map<String, dynamic>? deliveryAddressData = formData.isDelivery
          ? {
              'street': formData.address,
              'number': '', // O backend pode lidar com número vazio, se necessário
              'city': formData.city,
            }
          : null;

      // ===================== FIM DA INTERVENÇÃO CIRÚRGICA ======================

      // Preparar dados do pedido
      final orderData = {
        'user_id': storeOwnerId,
        'items': cartProvider.toOrderItems().map((item) => item.toJson()).toList(),
        'total_amount': cartProvider.totalAmount,
        'customer_info': {
          'client_uid': currentClient.uid,
          'name': formData.name,
          'email': formData.email,
          'phone': formData.phone,
          'is_delivery': formData.isDelivery,
        },
        'delivery_method': formData.isDelivery ? 'delivery' : 'pickup',
        'delivery_address': deliveryAddressData, // ✅ OBJETO CORRIGIDO
        'payment_method': formData.paymentMethod,
        'payment_proof_url': paymentProofUrl,
        'store_info': {
          'store_name': storeInfo.storeName,
          'phone_number': storeInfo.phoneNumber,
          'pix_key': storeInfo.pixKey,
        },
      };

      Logger.info('CartOrderService: Enviando pedido para API');
      
      final debugData = {
        'store_owner_id': storeOwnerId,
        'payment_method': formData.paymentMethod,
        'has_proof': paymentProofUrl != null,
        'is_delivery': formData.isDelivery,
        'item_count': cartProvider.cartItems.length,
        'total_amount': cartProvider.totalAmount,
      };
      Logger.debug('CartOrderService: Dados do pedido: ${debugData.toString()}');

      final success = await orderProvider.placeOrder(orderData);

      if (success) {
        Logger.info('CartOrderService: ✅ Pedido criado com sucesso');
        return true;
      } else {
        Logger.error('CartOrderService: ❌ Falha ao criar pedido: ${orderProvider.errorMessage}');
        return false;
      }

    } catch (e) {
      Logger.error('CartOrderService: Erro ao criar pedido', error: e);
      return false;
    }
  }

  /// Método para obter detalhes do erro do último pedido
  String? getLastOrderError(OrderProvider orderProvider) {
    return orderProvider.errorMessage ?? 'Erro desconhecido ao processar pedido';
  }

  /// Método para limpar estado após pedido processado
  void clearOrderState() {
    Logger.info('CartOrderService: Limpando estado do serviço');
    // Aqui podemos limpar qualquer estado interno se necessário
  }

  /// Método para obter resumo do pedido antes de processar
  OrderSummary getOrderSummary({
    required CartProvider cartProvider,
    required CheckoutFormData formData,
  }) {
    return OrderSummary(
      itemCount: cartProvider.cartItems.length,
      totalAmount: cartProvider.totalAmount,
      paymentMethod: formData.paymentMethod,
      isDelivery: formData.isDelivery,
      customerName: formData.name,
    );
  }
}

/// Classe para resumo do pedido
class OrderSummary {
  final int itemCount;
  final double totalAmount;
  final String paymentMethod;
  final bool isDelivery;
  final String customerName;

  OrderSummary({
    required this.itemCount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.isDelivery,
    required this.customerName,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_count': itemCount,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'is_delivery': isDelivery,
      'customer_name': customerName,
    };
  }

  @override
  String toString() {
    return 'OrderSummary(items: $itemCount, total: R\$ ${totalAmount.toStringAsFixed(2)}, '
           'payment: $paymentMethod, delivery: $isDelivery)';
  }
}
