// lib/screens/cartpro/models/payment_method_info.dart

import 'package:flutter/material.dart';

// MODELO 1: Define a estrutura de um método de pagamento
class PaymentMethodInfo {
  final String method;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final bool requiresProof;

  PaymentMethodInfo({
    required this.method,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    this.requiresProof = false,
  });

  // O método estático 'defaultMethods' foi removido daqui porque ele
  // depende de 'Icons' e 'Color', que são mais apropriados para a camada
  // de serviço ou UI, não no modelo puro. Ele será recriado no
  // 'cart_payment_service.dart'.
}

// MODELO 2: Define a estrutura das informações de pagamento da loja
class StorePaymentInfo {
  final String storeName;
  final String? phoneNumber;
  final String? pixKey;

  StorePaymentInfo({
    required this.storeName,
    this.phoneNumber,
    this.pixKey,
  });

  bool get hasPixKey => pixKey != null && pixKey!.isNotEmpty;
  bool get hasPhone => phoneNumber != null && phoneNumber!.isNotEmpty;

  factory StorePaymentInfo.fromJson(Map<String, dynamic> json) {
    return StorePaymentInfo(
      storeName: json['store_name'] ?? 'Loja',
      phoneNumber: json['phone_number'],
      pixKey: json['pix_key'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_name': storeName,
      'phone_number': phoneNumber,
      'pix_key': pixKey,
    };
  }
}
