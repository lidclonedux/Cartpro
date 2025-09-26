// lib/screens/admin/tabs/products/dialogs/delete_product_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Models
import '../../../../../models/product.dart';

// Providers
import '../../../../../providers/product_provider.dart';

// Utils
import '../../../../../utils/logger.dart';

class DeleteProductDialog extends StatefulWidget {
  final Product product;
  final Function(bool success, String message) onConfirm;

  const DeleteProductDialog({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  @override
  State<DeleteProductDialog> createState() => _DeleteProductDialogState();
}

class _DeleteProductDialogState extends State<DeleteProductDialog> {
  bool _isLoading = false;
  bool _permanentDelete = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: Colors.red.shade400,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Confirmar Exclusão',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tem certeza que deseja excluir este produto?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildProductInfo(),
          const SizedBox(height: 20),
          _buildDeleteOptions(),
          const SizedBox(height: 16),
          _buildWarningInfo(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            Logger.info('DeleteProductDialog: Cancelado pelo usuário');
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_permanentDelete ? 'Excluir Permanentemente' : 'Desativar'),
        ),
      ],
    );
  }

  Widget _buildProductInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.inventory_2, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.inventory_2, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFF9147FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Estoque: ${widget.product.stockQuantity}',
                      style: TextStyle(
                        color: widget.product.stockQuantity > 0 ? Colors.green : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.product.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Text(
              widget.product.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeleteOptions() {
    return Column(
      children: [
        RadioListTile<bool>(
          title: const Text(
            'Apenas desativar produto',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: const Text(
            'O produto ficará oculto para os clientes, mas seus dados serão preservados',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          value: false,
          groupValue: _permanentDelete,
          activeColor: Colors.orange,
          onChanged: (value) => setState(() => _permanentDelete = value ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        RadioListTile<bool>(
          title: const Text(
            'Excluir permanentemente',
            style: TextStyle(color: Colors.red, fontSize: 14),
          ),
          subtitle: Text(
  "...", 
  style: TextStyle(color: Colors.red.shade300, fontSize: 12),
),
          value: true,
          groupValue: _permanentDelete,
          activeColor: Colors.red,
          onChanged: (value) => setState(() => _permanentDelete = value ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildWarningInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _permanentDelete 
            ? Colors.red.withOpacity(0.1) 
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _permanentDelete ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _permanentDelete ? Icons.delete_forever : Icons.visibility_off,
            color: _permanentDelete ? Colors.red : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _permanentDelete
                  ? 'Exclusão permanente: O produto será removido completamente do sistema.'
                  : 'Desativação: O produto ficará oculto mas poderá ser reativado posteriormente.',
              style: TextStyle(
                color: _permanentDelete ? Colors.red : Colors.orange,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    setState(() => _isLoading = true);

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      bool success;
      String message;

      if (_permanentDelete) {
        Logger.info('DeleteProductDialog: Excluindo permanentemente produto "${widget.product.name}"');
        success = await productProvider.deleteProduct(widget.product.id);
        message = success 
            ? 'Produto "${widget.product.name}" excluído permanentemente'
            : 'Erro ao excluir produto';
      } else {
        Logger.info('DeleteProductDialog: Desativando produto "${widget.product.name}"');
        final updatedProduct = widget.product.copyWith(isActive: false);
        success = await productProvider.updateProduct(updatedProduct);
        message = success 
            ? 'Produto "${widget.product.name}" desativado com sucesso'
            : 'Erro ao desativar produto';
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onConfirm(
          success, 
          success ? message : productProvider.errorMessage ?? message,
        );
      }

    } catch (e) {
      Logger.error('DeleteProductDialog: Erro durante exclusão/desativação', error: e);
      
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onConfirm(false, 'Erro: ${e.toString()}');
      }
    }
  }
}

/// Dialog simplificado para confirmação rápida de desativação
class QuickDeactivateDialog extends StatelessWidget {
  final Product product;
  final Function(bool success, String message) onConfirm;

  const QuickDeactivateDialog({
    super.key,
    required this.product,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.visibility_off, color: Colors.orange),
          SizedBox(width: 8),
          Text(
            'Desativar Produto',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Deseja desativar o produto "${product.name}"?',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O produto ficará oculto para os clientes, mas poderá ser reativado posteriormente.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              final updatedProduct = product.copyWith(isActive: false);
              final success = await productProvider.updateProduct(updatedProduct);
              
              if (context.mounted) {
                Navigator.of(context).pop();
                onConfirm(
                  success,
                  success 
                      ? 'Produto desativado com sucesso'
                      : productProvider.errorMessage ?? 'Erro ao desativar produto',
                );
              }
            } catch (e) {
              Logger.error('QuickDeactivateDialog: Erro', error: e);
              if (context.mounted) {
                Navigator.of(context).pop();
                onConfirm(false, 'Erro: ${e.toString()}');
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Desativar'),
        ),
      ],
    );
  }

}

