
 // lib/screens/cartpro/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';

// Services
import 'cartpro/services/cart_validation_service.dart';
import 'cartpro/services/cart_payment_service.dart';
import 'cartpro/services/cart_order_service.dart';

// Widgets
import 'cartpro/widgets/cart_snackbar_utils.dart';

// Sections
import 'cartpro/sections/cart_empty_section.dart';
import 'cartpro/sections/cart_items_section.dart';
import 'cartpro/sections/cart_checkout_section.dart';

// Dialogs
import 'cartpro/dialogs/checkout_dialog.dart';
import 'cartpro/dialogs/confirmation_dialogs.dart';

// Utils
import '../../utils/logger.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late CartValidationService _validationService;
  late CartPaymentService _paymentService;
  late CartOrderService _orderService;

  @override
  void initState() {
    super.initState();
    Logger.info('CartPro: Inicializando carrinho modular');
    
    _validationService = CartValidationService();
    _paymentService = CartPaymentService();
    _orderService = CartOrderService();
    
    Logger.info('CartPro: Inicialização concluída');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Carrinho'),
        backgroundColor: const Color(0xFF23272A),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.items.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () => _showClearCartDialog(cartProvider),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.items.isEmpty) {
            Logger.info('CartPro: Exibindo tela de carrinho vazio');
            return const CartEmptySection();
          }

          Logger.info('CartPro: Exibindo ${cartProvider.items.length} itens no carrinho');
          return Column(
            children: [
              Expanded(
                child: CartItemsSection(
                  validationService: _validationService,
                ),
              ),
              CartCheckoutSection(
                onCheckout: () => _handleCheckout(cartProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearCartDialog(CartProvider cartProvider) {
    ConfirmationDialogs.showClearCart(
      context,
      onConfirm: () {
        cartProvider.clearCart();
        CartSnackBarUtils.showSuccess(context, 'Carrinho limpo com sucesso');
      },
    );
  }

  Future<void> _handleCheckout(CartProvider cartProvider) async {
    Logger.info('CartPro: Iniciando processo de checkout');
    
    // Validar carrinho antes de abrir dialog
    final validation = _validationService.validateCart(cartProvider);
    if (!validation.isValid) {
      CartSnackBarUtils.showError(context, validation.errorMessage!);
      return;
    }

    // Abrir dialog de checkout
    CheckoutDialog.show(
      context,
      cartProvider: cartProvider,
      paymentService: _paymentService,
      orderService: _orderService,
    );
  }
}
