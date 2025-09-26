// lib/screens/cartpro/sections/cart_empty_section.dart

import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

class CartEmptySection extends StatelessWidget {
  const CartEmptySection({super.key});

  @override
  Widget build(BuildContext context) {
    Logger.info('CartPro: Exibindo seção de carrinho vazio');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Carrinho Vazio',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Adicione produtos à sua lista de compras\ne finalize seu pedido',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9147FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF9147FF).withOpacity(0.3),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF9147FF),
                    size: 24,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Dica',
                    style: TextStyle(
                      color: Color(0xFF9147FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Browse pela loja e adicione produtos\nque deseja comprar ao carrinho',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}