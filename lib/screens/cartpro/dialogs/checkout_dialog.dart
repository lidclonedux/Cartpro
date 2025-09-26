// lib/screens/cartpro/dialogs/checkout_dialog.dart - PÓS-CIRÚRGICO

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../providers/cart_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/auth_provider.dart';

// Services
import '../services/cart_validation_service.dart';
import '../services/cart_payment_service.dart';
import '../services/cart_order_service.dart';

// Models
import '../models/checkout_form_data.dart';
import '../models/payment_method_info.dart';

// Dialogs
import 'payment_method_selector.dart';
import 'order_success_dialog.dart';

// Widgets
import 'proof_upload_widget.dart';
import '../widgets/cart_snackbar_utils.dart';
import '../widgets/cart_base_widget.dart';

// Utils
import '../../../utils/logger.dart';

class CheckoutDialog {
  static Future<void> show(
    BuildContext context, {
    required CartProvider cartProvider,
    required CartPaymentService paymentService,
    required CartOrderService orderService,
  }) async {
    final validationService = CartValidationService();
    
    final validation = validationService.validateCart(cartProvider);
    if (!validation.isValid) {
      if (context.mounted) {
        CartSnackBarUtils.showError(context, validation.errorMessage!);
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = authProvider.apiService;
    final storeOwnerId = cartProvider.cartItems.first.product.userId;
    
    StorePaymentInfo? storeInfo;
    
    try {
      Logger.info('CheckoutDialog: Buscando informações da loja $storeOwnerId');
      final data = await apiService?.getStorePaymentInfo(storeOwnerId);
      if (data != null) {
        storeInfo = StorePaymentInfo.fromJson(data);
      }
    } catch (e) {
      Logger.error('CheckoutDialog: Erro ao buscar informações da loja', error: e);
      if (context.mounted) {
        CartSnackBarUtils.showError(context, 'Erro ao carregar dados da loja');
      }
      return;
    }

    if (!context.mounted || storeInfo == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => _CheckoutDialogWidget(
        cartProvider: cartProvider,
        storeInfo: storeInfo!,
        paymentService: paymentService,
        orderService: orderService,
      ),
    );
  }
}

class _CheckoutDialogWidget extends StatefulWidget {
  final CartProvider cartProvider;
  final StorePaymentInfo storeInfo;
  final CartPaymentService paymentService;
  final CartOrderService orderService;

  const _CheckoutDialogWidget({
    required this.cartProvider,
    required this.storeInfo,
    required this.paymentService,
    required this.orderService,
  });

  @override
  State<_CheckoutDialogWidget> createState() => _CheckoutDialogWidgetState();
}

class _CheckoutDialogWidgetState extends State<_CheckoutDialogWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  
  bool _isDelivery = true;
  bool _isProcessingOrder = false;
  String _selectedPaymentMethod = 'pix';
  File? _proofImage;

  List<PaymentMethodInfo> get availableMethods => [
    PaymentMethodInfo(
      method: 'pix',
      displayName: 'Pagar com PIX',
      description: 'Você fará o PIX e enviará o comprovante',
      icon: Icons.pix,
      color: Colors.green,
    ),
    PaymentMethodInfo(
      method: 'other',
      displayName: 'Combinar Pagamento',
      description: 'Definir forma de pagamento diretamente com o vendedor',
      icon: Icons.handshake,
      color: const Color(0xFF9147FF),
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF23272A),
      title: const Text(
        'Finalizar Pedido',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStoreInfo(),
                const SizedBox(height: 20),
                _buildCustomerForm(),
                const SizedBox(height: 20),
                _buildDeliveryOptions(),
                if (_isDelivery) ...[
                  const SizedBox(height: 16),
                  _buildDeliveryFields(),
                ],
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                _buildPaymentSection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _canConfirmOrder() && !_isProcessingOrder
              ? _processOrder
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9147FF),
          ),
          child: _isProcessingOrder
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_getConfirmButtonText()),
        ),
      ],
    );
  }

  Widget _buildStoreInfo() {
    return CartBaseWidget.buildInfoContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, color: Color(0xFF9147FF)),
              const SizedBox(width: 8),
              Text(
                widget.storeInfo.storeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (widget.storeInfo.hasPhone) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Contato: ${widget.storeInfo.phoneNumber}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
          if (widget.storeInfo.hasPixKey) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pix, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PIX: ${widget.storeInfo.pixKey}',
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nome Completo',
            hintText: 'Digite seu nome completo',
          ),
          validator: (value) => value?.trim().isEmpty == true ? 'Nome é obrigatório' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Digite seu email',
          ),
          validator: (value) {
            if (value?.trim().isEmpty == true) return 'Email é obrigatório';
            if (!value!.contains('@')) return 'Email inválido';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Telefone',
            hintText: 'Digite seu telefone',
          ),
          validator: (value) => value?.trim().isEmpty == true ? 'Telefone é obrigatório' : null,
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<bool>(
            title: const Text(
              'Entrega',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            value: true,
            groupValue: _isDelivery,
            onChanged: (value) => setState(() => _isDelivery = value!),
          ),
        ),
        Expanded(
          child: RadioListTile<bool>(
            title: const Text(
              'Retirada',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            value: false,
            groupValue: _isDelivery,
            onChanged: (value) => setState(() => _isDelivery = value!),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryFields() {
    return Column(
      children: [
        TextFormField(
          controller: _addressController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Endereço Completo',
            hintText: 'Rua, número, bairro',
          ),
          validator: (value) {
            if (_isDelivery && value?.trim().isEmpty == true) {
              return 'Endereço é obrigatório para entrega';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cityController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Cidade',
            hintText: 'Digite sua cidade',
          ),
          validator: (value) {
            if (_isDelivery && value?.trim().isEmpty == true) {
              return 'Cidade é obrigatória para entrega';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      children: [
        PaymentMethodSelector(
          selectedPaymentMethod: _selectedPaymentMethod,
          availableMethods: availableMethods,
          onMethodChanged: (method) {
            setState(() {
              _selectedPaymentMethod = method;
              _proofImage = null;
            });
          },
        ),
        const SizedBox(height: 16),
        PaymentInstructionsDisplay(
          paymentMethod: _selectedPaymentMethod,
          storeInfo: widget.storeInfo,
          totalAmount: widget.cartProvider.totalAmount,
        ),
        if (_selectedPaymentMethod == 'pix') ...[
          const SizedBox(height: 16),
          ProofUploadWidget(
            proofImage: _proofImage,
            isUploading: _isProcessingOrder,
            onSelectImage: () async {
              final image = await ProofUploadService.selectImage();
              if (image != null) {
                setState(() => _proofImage = image);
              }
            },
            onRemoveImage: () => setState(() => _proofImage = null),
          ),
        ],
      ],
    );
  }

  bool _canConfirmOrder() {
    if (_selectedPaymentMethod == 'pix') {
      return _proofImage != null;
    }
    return true;
  }

  String _getConfirmButtonText() {
    if (_selectedPaymentMethod == 'pix') {
      return 'Confirmar Pedido com PIX';
    }
    return 'Enviar Pedido';
  }

  // ===================== INÍCIO DA INTERVENÇÃO CIRÚRGICA =====================
  // DIAGNÓSTICO: O método original não orquestrava a sequência de upload e criação de pedido.
  // PROCEDIMENTO: Reescrita completa para implementar o arco reflexo correto.
  
  Future<void> _processOrder() async {
    // 1. Validação inicial do formulário
    if (!_formKey.currentState!.validate()) {
      Logger.warning('CheckoutDialog: Validação do formulário falhou.');
      return;
    }

    setState(() => _isProcessingOrder = true);

    try {
      String? uploadedProofUrl;

      // 2. ETAPA DE UPLOAD (condicional)
      // Executa somente se o método for PIX.
      if (_selectedPaymentMethod == 'pix') {
        if (_proofImage == null) {
          CartSnackBarUtils.showError(context, 'É obrigatório anexar o comprovante PIX');
          setState(() => _isProcessingOrder = false);
          return;
        }
        
        Logger.info('CheckoutDialog: Iniciando upload do comprovante...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final apiService = authProvider.apiService;
        
        // A chamada de upload acontece aqui, ANTES da criação do pedido.
        uploadedProofUrl = await apiService?.uploadPaymentProof(
          imageFile: _proofImage!,
          description: 'Comprovante de pedido via App',
        );

        if (uploadedProofUrl == null) {
          throw Exception('Falha no upload do comprovante. Tente novamente.');
        }
        Logger.info('CheckoutDialog: Upload bem-sucedido. URL: $uploadedProofUrl');
      }

      // 3. ETAPA DE CRIAÇÃO DO PEDIDO
      // Monta os dados do formulário.
      final formData = CheckoutFormData(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        isDelivery: _isDelivery,
        address: _isDelivery ? _addressController.text.trim() : null,
        city: _isDelivery ? _cityController.text.trim() : null,
        paymentMethod: _selectedPaymentMethod,
      );

      Logger.info('CheckoutDialog: Formulário validado. Preparando para criar o pedido.');

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Chama o `CartOrderService`, que agora receberá a URL do comprovante (se houver).
      final success = await widget.orderService.processOrder(
        cartProvider: widget.cartProvider,
        formData: formData,
        storeInfo: widget.storeInfo,
        orderProvider: orderProvider,
        authProvider: authProvider,
        proofImage: _proofImage, // Mantido para validação, mas o upload já foi feito.
        // A URL do upload será passada internamente pelo `processOrder` para o `_createOrder`.
      );

      if (!mounted) return;

      Navigator.of(context).pop(); // Fecha o dialog de checkout

      // 4. ETAPA DE FEEDBACK
      if (success) {
        Logger.info('CheckoutDialog: Pedido processado com sucesso pelo serviço.');
        widget.cartProvider.clearCart();
        _clearForm();

        OrderSuccessDialog.show(
          context,
          storeInfo: widget.storeInfo,
          paymentMethod: _selectedPaymentMethod,
        );
      } else {
        final errorMessage = widget.orderService.getLastOrderError(orderProvider);
        Logger.error('CheckoutDialog: Falha no processamento do pedido: $errorMessage');
        CartSnackBarUtils.showError(
          context,
          errorMessage ?? 'Erro ao processar pedido. Tente novamente.',
        );
      }
    } catch (e) {
      Logger.error('CheckoutDialog: Erro inesperado no _processOrder', error: e);
      if (mounted) {
        Navigator.of(context).pop();
        CartSnackBarUtils.showError(context, 'Erro: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOrder = false);
      }
    }
  }
  // ===================== FIM DA INTERVENÇÃO CIRÚRGICA ======================

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _cityController.clear();
    _proofImage = null;
    _selectedPaymentMethod = 'pix';
    _isDelivery = true;
  }
}
