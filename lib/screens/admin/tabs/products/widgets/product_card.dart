// lib/screens/admin/tabs/products/widgets/product_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Models
import '../../../../../models/product.dart';

// Providers  
import '../../../../../providers/product_provider.dart';

// Utils
import '../../../../../utils/logger.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleActive;
  final bool showDetailedInfo;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    this.onToggleActive,
    this.showDetailedInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = Provider.of<ProductProvider>(context, listen: false)
        .getCategoryNameById(product.categoryId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: product.isActive 
          ? const Color(0xFF23272A) 
          : const Color(0xFF23272A).withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getCardBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildCardHeader(context, categoryName),
          if (showDetailedInfo) _buildCardDetails(),
          _buildCardActions(),
        ],
      ),
    );
  }

  Color _getCardBorderColor() {
    if (!product.isActive) return Colors.red.withOpacity(0.3);
    if (product.stockQuantity == 0) return Colors.orange.withOpacity(0.5);
    if (product.isLowStock) return Colors.yellow.withOpacity(0.5);
    return Colors.transparent;
  }

  Widget _buildCardHeader(BuildContext context, String categoryName) {
    return ListTile(
      leading: _buildProductImage(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              style: TextStyle(
                color: product.isActive ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!product.isActive) _buildInactiveIndicator(),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              _buildPriceChip(),
              const SizedBox(width: 8),
              _buildStockChip(),
            ],
          ),
          if (categoryName.isNotEmpty && categoryName != "Sem Categoria") ...[
            const SizedBox(height: 6),
            _buildCategoryChip(categoryName),
          ],
        ],
      ),
      trailing: _buildActionButton(),
    );
  }

  Widget _buildProductImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  Logger.warning('ProductCard: Falha ao carregar imagem do produto "${product.name}": ${product.imageUrl}');
                  return const Icon(Icons.inventory_2, color: Colors.grey, size: 30);
                },
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
              ),
            )
          : const Icon(Icons.inventory_2, color: Colors.grey, size: 30),
    );
  }

  Widget _buildInactiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: const Text(
        'INATIVO',
        style: TextStyle(
          color: Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9147FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9147FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_money, size: 12, color: Color(0xFF9147FF)),
          Text(
            product.formattedPrice,
            style: const TextStyle(
              color: Color(0xFF9147FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChip() {
    Color stockColor;
    IconData stockIcon;
    String stockText;

    if (product.stockQuantity == 0) {
      stockColor = Colors.red;
      stockIcon = Icons.remove_circle_outline;
      stockText = 'SEM ESTOQUE';
    } else if (product.isLowStock) {
      stockColor = Colors.orange;
      stockIcon = Icons.warning_amber_outlined;
      stockText = 'BAIXO (${product.stockQuantity})';
    } else {
      stockColor = Colors.green;
      stockIcon = Icons.check_circle_outline;
      stockText = '${product.stockQuantity}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: stockColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stockColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stockIcon, size: 12, color: stockColor),
          const SizedBox(width: 4),
          Text(
            stockText,
            style: TextStyle(
              color: stockColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.5)),
      ),
      child: Text(
        categoryName,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCardDetails() {
    if (product.description.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: product.isActive ? Colors.white54 : Colors.white30,
      ),
      color: const Color(0xFF2C2F33),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            Logger.info('ProductCard: Editando produto "${product.name}"');
            onEdit();
            break;
          case 'toggle_active':
            Logger.info('ProductCard: Alternando status do produto "${product.name}"');
            onToggleActive?.call();
            break;
          case 'delete':
            Logger.info('ProductCard: Solicitando exclusão do produto "${product.name}"');
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('Editar', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        if (onToggleActive != null)
          PopupMenuItem(
            value: 'toggle_active',
            child: Row(
              children: [
                Icon(
                  product.isActive ? Icons.visibility_off : Icons.visibility,
                  color: product.isActive ? Colors.orange : Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  product.isActive ? 'Desativar' : 'Ativar',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('Excluir', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardActions() {
    // Ações rápidas na parte inferior do card (opcional)
    if (!showDetailedInfo) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Data de criação
          Icon(
            Icons.schedule,
            size: 14,
            color: Colors.white38,
          ),
          const SizedBox(width: 4),
          Text(
            'Criado: ${_formatDate(product.createdAt)}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          // Data de atualização
          if (product.updatedAt != product.createdAt) ...[
            Icon(
              Icons.update,
              size: 14,
              color: Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              'Atualizado: ${_formatDate(product.updatedAt)}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// Variação compacta do ProductCard para listas densas
class CompactProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: const Color(0xFF23272A),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[800],
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    product.imageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.inventory_2, size: 20),
                  ),
                )
              : const Icon(Icons.inventory_2, size: 20),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            color: product.isActive ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              product.formattedPrice,
              style: const TextStyle(
                color: Color(0xFF9147FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Est: ${product.stockQuantity}',
              style: TextStyle(
                color: product.stockQuantity > 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}