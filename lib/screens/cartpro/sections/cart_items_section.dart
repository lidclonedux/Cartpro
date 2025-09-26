// lib/screens/cartpro/sections/cart_items_section.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../providers/cart_provider.dart';

// Services
import '../services/cart_validation_service.dart';

// Widgets
import '../widgets/cart_snackbar_utils.dart';
import 'widgets/cart_item_card.dart';

// Utils
import '../../../utils/logger.dart';

class CartItemsSection extends StatelessWidget {
  final CartValidationService validationService;

  const CartItemsSection({
    super.key,
    required this.validationService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        Logger.info('CartPro: Renderizando ${cartProvider.cartItems.length} itens');
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cartProvider.cartItems.length,
          itemBuilder: (context, index) {
            final item = cartProvider.cartItems[index];
            
            return CartItemCard(
              item: item,
              onIncrease: () => _handleIncrease(item, cartProvider, context),
              onDecrease: () => _handleDecrease(item, cartProvider, context),
              onRemove: () => _handleRemove(item, cartProvider, context),
            );
          },
        );
      },
    );
  }

  void _handleIncrease(dynamic item, CartProvider cartProvider, BuildContext context) {
    try {
      // ===== INÍCIO DA CORREÇÃO =====
      // As linhas a seguir foram comentadas porque o método 'validateProductId' não existe.
      // final validation = validationService.validateProductId(item.product.id, item.product.name);
      
      // if (!validation.isValid) {
      //   Logger.error('CartPro: Produto com ID inválido ao tentar aumentar quantidade');
      //   CartSnackBarUtils.showError(context, validation.errorMessage!);
      //   cartProvider.removeFromCart(item.product.id);
      //   return;
      // }
      // ===== FIM DA CORREÇÃO =====

      if (item.quantity < item.product.stockQuantity) {
        cartProvider.updateQuantity(item.product.id, item.quantity + 1);
        Logger.info('CartPro: Quantidade aumentada para ${item.quantity + 1} - Produto: ${item.product.name}');
      } else {
        CartSnackBarUtils.showWarning(context, 'Estoque insuficiente para este produto');
        Logger.warning('CartPro: Tentativa de aumentar quantidade além do estoque - Produto: ${item.product.name}');
      }
    } catch (e) {
      Logger.error('CartPro: Erro ao aumentar quantidade', error: e);
      CartSnackBarUtils.showError(context, 'Erro ao atualizar quantidade: ${e.toString()}');
    }
  }

  void _handleDecrease(dynamic item, CartProvider cartProvider, BuildContext context) {
    try {
      // ===== INÍCIO DA CORREÇÃO =====
      // As linhas a seguir foram comentadas porque o método 'validateProductId' não existe.
      // final validation = validationService.validateProductId(item.product.id, item.product.name);
      
      // if (!validation.isValid) {
      //   Logger.error('CartPro: Produto com ID inválido ao tentar diminuir quantidade');
      //   CartSnackBarUtils.showError(context, validation.errorMessage!);
      //   cartProvider.removeFromCart(item.product.id);
      //   return;
      // }
      // ===== FIM DA CORREÇÃO =====

      if (item.quantity > 1) {
        cartProvider.updateQuantity(item.product.id, item.quantity - 1);
        Logger.info('CartPro: Quantidade diminuída para ${item.quantity - 1} - Produto: ${item.product.name}');
      } else {
        cartProvider.removeFromCart(item.product.id);
        CartSnackBarUtils.showInfo(context, 'Item removido do carrinho');
        Logger.info('CartPro: Item removido do carrinho - Produto: ${item.product.name}');
      }
    } catch (e) {
      Logger.error('CartPro: Erro ao diminuir quantidade', error: e);
      CartSnackBarUtils.showError(context, 'Erro ao atualizar quantidade: ${e.toString()}');
    }
  }

  void _handleRemove(dynamic item, CartProvider cartProvider, BuildContext context) {
    try {
      cartProvider.removeFromCart(item.product.id);
      CartSnackBarUtils.showInfo(context, '${item.product.name} removido do carrinho');
      Logger.info('CartPro: Item removido do carrinho - Produto: ${item.product.name}');
    } catch (e) {
      Logger.error('CartPro: Erro ao remover item', error: e);
      CartSnackBarUtils.showError(context, 'Erro ao remover item: ${e.toString()}');
    }
  }
}
