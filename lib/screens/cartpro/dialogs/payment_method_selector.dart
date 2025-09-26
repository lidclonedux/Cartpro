// lib/screens/cartpro/dialogs/payment_method_selector.dart

import 'package:flutter/material.dart';
import '../models/payment_method_info.dart';
import '../../../utils/logger.dart';

class PaymentMethodSelector extends StatelessWidget {
  final String selectedPaymentMethod;
  final List<PaymentMethodInfo> availableMethods;
  final Function(String) onMethodChanged;

  const PaymentMethodSelector({
    super.key,
    required this.selectedPaymentMethod,
    required this.availableMethods,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Como você quer pagar?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...availableMethods.map((method) => _buildMethodOption(method)),
      ],
    );
  }

  Widget _buildMethodOption(PaymentMethodInfo method) {
    final isSelected = selectedPaymentMethod == method.method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF9147FF) : Colors.white24,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFF9147FF).withOpacity(0.1) : Colors.transparent,
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: method.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                method.icon,
                color: method.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        value: method.method,
        groupValue: selectedPaymentMethod,
        activeColor: const Color(0xFF9147FF),
        onChanged: (value) {
          if (value != null) {
            Logger.info('PaymentMethodSelector: Método selecionado: $value');
            onMethodChanged(value);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class PaymentInstructionsDisplay extends StatelessWidget {
  final String paymentMethod;
  final StorePaymentInfo storeInfo;
  final double totalAmount;

  const PaymentInstructionsDisplay({
    super.key,
    required this.paymentMethod,
    required this.storeInfo,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    if (paymentMethod != 'pix') return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Instruções para PIX',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildInstructions(),
        ],
      ),
    );
  }

  List<Widget> _buildInstructions() {
    final instructions = <Widget>[];
    int step = 1;

    if (storeInfo.hasPixKey) {
      instructions.add(_buildInstructionStep(
        step++,
        'Faça o PIX para: ${storeInfo.pixKey}',
      ));
    } else {
      instructions.add(_buildInstructionStep(
        step++,
        'Faça o PIX (chave será informada pelo vendedor)',
      ));
    }

    instructions.add(_buildInstructionStep(
      step++,
      'Valor: R\$ ${totalAmount.toStringAsFixed(2)}',
    ));

    instructions.add(_buildInstructionStep(
      step++,
      'Anexe o comprovante abaixo',
    ));

    return instructions;
  }

  Widget _buildInstructionStep(int step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


