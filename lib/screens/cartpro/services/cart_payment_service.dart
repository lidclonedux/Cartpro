import 'package:flutter/material.dart'; // <--- CORREÇÃO ADICIONADA AQUI

// lib/screens/cartpro/services/cart_payment_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/payment_method_info.dart';
import '../../../utils/logger.dart';

class CartPaymentService {
  /// Valida se o método de pagamento é suportado
  bool isPaymentMethodSupported(String paymentMethod) {
    final supportedMethods = ['pix', 'other'];
    return supportedMethods.contains(paymentMethod);
  }

  /// Valida se o comprovante de pagamento é necessário para o método escolhido
  bool requiresPaymentProof(String paymentMethod) {
    return paymentMethod == 'pix';
  }

  /// Valida arquivo de comprovante de pagamento
  Future<PaymentProofValidation> validatePaymentProof(File? proofFile) async {
    if (proofFile == null) {
      return PaymentProofValidation(
        isValid: false,
        errorMessage: 'Nenhum arquivo selecionado',
      );
    }

    try {
      // Verificar se o arquivo existe
      if (!await proofFile.exists()) {
        return PaymentProofValidation(
          isValid: false,
          errorMessage: 'Arquivo não encontrado',
        );
      }

      // Verificar tamanho do arquivo (máximo 10MB)
      final fileSize = await proofFile.length();
      const maxSize = 10 * 1024 * 1024; // 10MB

      if (fileSize > maxSize) {
        return PaymentProofValidation(
          isValid: false,
          errorMessage: 'Arquivo muito grande. Tamanho máximo: 10MB',
        );
      }

      if (fileSize == 0) {
        return PaymentProofValidation(
          isValid: false,
          errorMessage: 'Arquivo está vazio',
        );
      }

      // Verificar extensão do arquivo
      final extension = proofFile.path.toLowerCase().split('.').last;
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'];
      
      if (!allowedExtensions.contains(extension)) {
        return PaymentProofValidation(
          isValid: false,
          errorMessage: 'Formato não suportado. Use: ${allowedExtensions.join(', ').toUpperCase()}',
        );
      }

      Logger.info('CartPaymentService: Comprovante validado com sucesso');
      return PaymentProofValidation(
        isValid: true,
        fileSize: fileSize,
        extension: extension,
      );

    } catch (e) {
      Logger.error('CartPaymentService: Erro ao validar comprovante', error: e);
      return PaymentProofValidation(
        isValid: false,
        errorMessage: 'Erro ao validar arquivo: ${e.toString()}',
      );
    }
  }

  /// Obtém informações detalhadas sobre um método de pagamento
  PaymentMethodDetails getPaymentMethodDetails(String paymentMethod) {
    switch (paymentMethod) {
      case 'pix':
        return PaymentMethodDetails(
          method: paymentMethod,
          displayName: 'PIX',
          requiresProof: true,
          processingTime: 'Instantâneo',
          instructions: [
            'Faça o PIX usando a chave fornecida',
            'Tire uma foto do comprovante',
            'Anexe o comprovante no pedido',
            'Aguarde a confirmação do vendedor',
          ],
        );
      
      case 'other':
        return PaymentMethodDetails(
          method: paymentMethod,
          displayName: 'A Combinar',
          requiresProof: false,
          processingTime: 'Conforme acordo',
          instructions: [
            'O vendedor entrará em contato',
            'Vocês combinarão a forma de pagamento',
            'Definirão quando e como realizar o pagamento',
            'Organizarão a entrega ou retirada',
          ],
        );
      
      default:
        return PaymentMethodDetails(
          method: paymentMethod,
          displayName: 'Método Desconhecido',
          requiresProof: false,
          processingTime: 'Não definido',
          instructions: ['Método de pagamento não reconhecido'],
        );
    }
  }

  /// Obtém lista de métodos de pagamento disponíveis
  List<PaymentMethodInfo> getAvailablePaymentMethods({
    StorePaymentInfo? storeInfo,
  }) {
    final methods = <PaymentMethodInfo>[];

    // PIX sempre disponível
    methods.add(PaymentMethodInfo(
      method: 'pix',
      displayName: 'Pagar com PIX',
      description: storeInfo?.hasPixKey == true 
          ? 'PIX para: ${storeInfo!.pixKey}'
          : 'Você fará o PIX e enviará o comprovante',
      icon: Icons.pix,
      color: Colors.green,
      requiresProof: true,
    ));

    // Método "outro" sempre disponível
    methods.add(PaymentMethodInfo(
      method: 'other',
      displayName: 'Combinar Pagamento',
      description: 'Definir forma de pagamento diretamente com o vendedor',
      icon: Icons.handshake,
      color: const Color(0xFF9147FF),
      requiresProof: false,
    ));

    Logger.info('CartPaymentService: ${methods.length} métodos de pagamento disponíveis');
    return methods;
  }

  /// Calcula taxa ou desconto baseado no método de pagamento
  PaymentCalculation calculatePaymentDetails({
    required double baseAmount,
    required String paymentMethod,
  }) {
    double finalAmount = baseAmount;
    double discountAmount = 0.0;
    double feeAmount = 0.0;
    String? discountReason;
    String? feeReason;

    switch (paymentMethod) {
      case 'pix':
        // PIX pode ter desconto (exemplo: 2%)
        // discountAmount = baseAmount * 0.02;
        // finalAmount = baseAmount - discountAmount;
        // discountReason = 'Desconto PIX (2%)';
        break;
      
      case 'other':
        // Método "outro" não tem taxas ou descontos
        break;
    }

    return PaymentCalculation(
      baseAmount: baseAmount,
      discountAmount: discountAmount,
      feeAmount: feeAmount,
      finalAmount: finalAmount,
      discountReason: discountReason,
      feeReason: feeReason,
    );
  }

  /// Formata valor monetário para exibição
  String formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2)}';
  }

  /// Gera resumo do pagamento
  PaymentSummary generatePaymentSummary({
    required String paymentMethod,
    required double totalAmount,
    required bool hasProof,
    StorePaymentInfo? storeInfo,
  }) {
    final methodDetails = getPaymentMethodDetails(paymentMethod);
    final calculation = calculatePaymentDetails(
      baseAmount: totalAmount,
      paymentMethod: paymentMethod,
    );

    return PaymentSummary(
      paymentMethod: paymentMethod,
      methodDisplayName: methodDetails.displayName,
      totalAmount: calculation.finalAmount,
      hasDiscount: calculation.discountAmount > 0,
      discountAmount: calculation.discountAmount,
      hasFee: calculation.feeAmount > 0,
      feeAmount: calculation.feeAmount,
      requiresProof: methodDetails.requiresProof,
      hasProofAttached: hasProof,
      processingTime: methodDetails.processingTime,
      storeHasPixKey: storeInfo?.hasPixKey ?? false,
      storePixKey: storeInfo?.pixKey,
    );
  }
}

// Classes de modelo para o serviço

class PaymentProofValidation {
  final bool isValid;
  final String? errorMessage;
  final int? fileSize;
  final String? extension;

  PaymentProofValidation({
    required this.isValid,
    this.errorMessage,
    this.fileSize,
    this.extension,
  });

  String? get fileSizeFormatted {
    if (fileSize == null) return null;
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class PaymentMethodDetails {
  final String method;
  final String displayName;
  final bool requiresProof;
  final String processingTime;
  final List<String> instructions;

  PaymentMethodDetails({
    required this.method,
    required this.displayName,
    required this.requiresProof,
    required this.processingTime,
    required this.instructions,
  });
}

class PaymentCalculation {
  final double baseAmount;
  final double discountAmount;
  final double feeAmount;
  final double finalAmount;
  final String? discountReason;
  final String? feeReason;

  PaymentCalculation({
    required this.baseAmount,
    required this.discountAmount,
    required this.feeAmount,
    required this.finalAmount,
    this.discountReason,
    this.feeReason,
  });

  bool get hasDiscount => discountAmount > 0;
  bool get hasFee => feeAmount > 0;
  bool get hasAdjustments => hasDiscount || hasFee;
}

class PaymentSummary {
  final String paymentMethod;
  final String methodDisplayName;
  final double totalAmount;
  final bool hasDiscount;
  final double discountAmount;
  final bool hasFee;
  final double feeAmount;
  final bool requiresProof;
  final bool hasProofAttached;
  final String processingTime;
  final bool storeHasPixKey;
  final String? storePixKey;

  PaymentSummary({
    required this.paymentMethod,
    required this.methodDisplayName,
    required this.totalAmount,
    required this.hasDiscount,
    required this.discountAmount,
    required this.hasFee,
    required this.feeAmount,
    required this.requiresProof,
    required this.hasProofAttached,
    required this.processingTime,
    required this.storeHasPixKey,
    this.storePixKey,
  });

  bool get isReadyToProcess {
    if (requiresProof) {
      return hasProofAttached;
    }
    return true;
  }

  String get statusMessage {
    if (requiresProof && !hasProofAttached) {
      return 'Anexe o comprovante de pagamento';
    }
    if (requiresProof && hasProofAttached) {
      return 'Comprovante anexado';
    }
    return 'Pronto para enviar';
  }
}
