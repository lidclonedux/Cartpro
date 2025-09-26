// lib/screens/cartpro/sections/widgets/cart_item_card.dart

import 'package:flutter/material.dart';

// Models
import '../../../../models/cart_item.dart';

// Widgets
import '../../widgets/cart_base_widget.dart';
import 'quantity_controls.dart';

// Utils
import '../../../../utils/logger.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasInvalidId = item.product.id.isEmpty || 
                        item.product.id == 'None' || 
                        item.product.id == 'null';

    return CartBaseWidget.buildCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildProductImage(),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProductInfo(hasInvalidId),
              ),
              const SizedBox(width: 8),
              QuantityControls(
                quantity: item.quantity,
                onIncrease: onIncrease,
                onDecrease: onDecrease,
                maxQuantity: item.product.stockQuantity,
              ),
            ],
          ),
          
          // Mostrar erro se ID inválido
          if (hasInvalidId) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(),
          ],
          
          // Linha de total
          const SizedBox(height: 12),
          _buildItemTotal(),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[300],
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
            ? Image.network(
                item.product.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  Logger.warning('CartPro: Falha ao carregar imagem do produto "${item.product.name}"');
                  return const Icon(Icons.image_not_supported, color: Colors.grey, size: 24);
                },
              )
            : const Icon(Icons.inventory_2, color: Colors.grey, size: 24),
      ),
    );
  }

  Widget _buildProductInfo(bool hasInvalidId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.product.name,
          style: TextStyle(
            color: hasInvalidId ? Colors.red : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'R\$ ${item.product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF9147FF),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'cada',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              item.product.isInStock ? Icons.check_circle : Icons.error,
              color: item.product.isInStock ? Colors.green : Colors.orange,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              item.product.isInStock 
                ? 'Estoque: ${item.product.stockQuantity}'
                : 'Sem estoque',
              style: TextStyle(
                color: item.product.isInStock ? Colors.white70 : Colors.orange,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Produto com dados inválidos será removido',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'REMOVER',
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTotal() {
    final itemTotal = item.product.price * item.quantity;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF9147FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF9147FF).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Subtotal:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'R\$ ${itemTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF9147FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}