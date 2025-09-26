// lib/screens/cartpro/dialogs/confirmation_dialogs.dart

import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

class ConfirmationDialogs {
  /// Dialog para confirmar limpeza do carrinho
  static Future<bool> showClearCart(
    BuildContext context, {
    VoidCallback? onConfirm,
  }) async {
    Logger.info('ConfirmationDialogs: Exibindo dialog de limpar carrinho');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Limpar Carrinho',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Tem certeza que deseja remover todos os itens do carrinho? '
            'Esta ação não pode ser desfeita.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Limpar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Dialog para confirmar remoção de um item específico
  static Future<bool> showRemoveItem(
    BuildContext context, {
    required String itemName,
    VoidCallback? onConfirm,
  }) async {
    Logger.info('ConfirmationDialogs: Exibindo dialog de remover item: $itemName');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.remove_shopping_cart, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Remover Item',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70),
              children: [
                const TextSpan(text: 'Deseja remover '),
                TextSpan(
                  text: '"$itemName"',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(text: ' do carrinho?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Remover',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Dialog para confirmar cancelamento do checkout
  static Future<bool> showCancelCheckout(
    BuildContext context, {
    VoidCallback? onConfirm,
  }) async {
    Logger.info('ConfirmationDialogs: Exibindo dialog de cancelar checkout');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Cancelar Pedido',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Tem certeza que deseja cancelar este pedido? '
            'Todas as informações preenchidas serão perdidas.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
              ),
              child: const Text(
                'Continuar Pedido',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm?.call();
              },
              child: const Text(
                'Cancelar Pedido',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Dialog para alertar sobre produto inválido
  static Future<void> showInvalidProduct(
    BuildContext context, {
    required String productName,
    VoidCallback? onConfirm,
  }) async {
    Logger.info('ConfirmationDialogs: Exibindo dialog de produto inválido: $productName');
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Produto Inválido',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70),
              children: [
                const TextSpan(text: 'O produto '),
                TextSpan(
                  text: '"$productName"',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(
                  text: ' possui dados inválidos e foi removido do carrinho.\n\n'
                        'Tente adicionar o produto novamente da página do produto.',
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
              ),
              child: const Text(
                'Entendi',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dialog para confirmar alteração de quantidade
  static Future<bool> showQuantityChange(
    BuildContext context, {
    required String productName,
    required int currentQuantity,
    required int newQuantity,
    VoidCallback? onConfirm,
  }) async {
    Logger.info('ConfirmationDialogs: Exibindo dialog de alteração de quantidade: $productName');
    
    final isIncrease = newQuantity > currentQuantity;
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                isIncrease ? Icons.add_circle : Icons.remove_circle,
                color: isIncrease ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                isIncrease ? 'Aumentar Quantidade' : 'Diminuir Quantidade',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70),
                  children: [
                    const TextSpan(text: 'Produto: '),
                    TextSpan(
                      text: productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'De: $currentQuantity',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Para: $newQuantity',
                    style: TextStyle(
                      color: isIncrease ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isIncrease ? Colors.green : Colors.orange,
              ),
              child: Text(
                'Confirmar',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Dialog genérico de confirmação
  static Future<bool> showGenericConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    Color? confirmColor,
    IconData? icon,
    VoidCallback? onConfirm,
  }) async {
    Logger.info('ConfirmationDialogs: Exibindo dialog genérico: $title');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (confirmColor ?? const Color(0xFF9147FF)).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: confirmColor ?? const Color(0xFF9147FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor ?? const Color(0xFF9147FF),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}