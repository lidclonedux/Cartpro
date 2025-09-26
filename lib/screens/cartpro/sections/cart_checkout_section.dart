// lib/screens/cartpro/sections/cart_checkout_section.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../providers/cart_provider.dart';

// Widgets
import '../widgets/cart_base_widget.dart';

// Utils
import '../../../utils/logger.dart';

class CartCheckoutSection extends StatelessWidget {
  final VoidCallback onCheckout;
  final bool? isProcessing;

  const CartCheckoutSection({
    super.key,
    required this.onCheckout,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final totalAmount = cartProvider.totalAmount;
        final itemCount = cartProvider.itemCount;
        
        Logger.info('CartPro: Renderizando seção checkout - Total: R\$ ${totalAmount.toStringAsFixed(2)}, Itens: $itemCount');
        
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF23272A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOrderSummary(itemCount, totalAmount),
                  const SizedBox(height: 16),
                  _buildCheckoutButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(int itemCount, double totalAmount) {
    return CartBaseWidget.buildInfoContainer(
      color: const Color(0xFF1E1E2C),
      borderColor: const Color(0xFF9147FF),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo do Pedido',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'R\$ ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF9147FF),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text(
                  'Pronto para finalizar',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isProcessing ?? false) ? null : () {
          Logger.info('CartPro: Botão de checkout pressionado');
          onCheckout();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9147FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: const Color(0xFF9147FF).withOpacity(0.3),
        ),
        child: (isProcessing ?? false)
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_checkout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'FINALIZAR PEDIDO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}