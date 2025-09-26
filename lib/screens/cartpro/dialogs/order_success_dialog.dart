// lib/screens/cartpro/dialogs/order_success_dialog.dart
import '../models/payment_method_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_method_selector.dart'; // Para StorePaymentInfo
import '../widgets/cart_base_widget.dart';
import '../../../utils/logger.dart';

class OrderSuccessDialog {
  static void show(
    BuildContext context, {
    required StorePaymentInfo storeInfo,
    required String paymentMethod,
  }) {
    Logger.info('OrderSuccessDialog: Exibindo dialog de sucesso para método: $paymentMethod');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _OrderSuccessDialogWidget(
        storeInfo: storeInfo,
        paymentMethod: paymentMethod,
      ),
    );
  }
}

class _OrderSuccessDialogWidget extends StatelessWidget {
  final StorePaymentInfo storeInfo;
  final String paymentMethod;

  const _OrderSuccessDialogWidget({
    required this.storeInfo,
    required this.paymentMethod,
  });

  bool get isPix => paymentMethod == 'pix';
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: _buildTitle(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessage(),
            const SizedBox(height: 20),
            _buildStatusCard(),
            if (!isPix && storeInfo.hasPhone) ...[
              const SizedBox(height: 20),
              _buildContactInfo(context),
            ],
            const SizedBox(height: 16),
            _buildNextSteps(),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'OK, ENTENDI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Pedido Enviado!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return Text(
      isPix 
          ? 'Seu pedido foi enviado com sucesso junto com o comprovante de pagamento.'
          : 'Seu pedido foi enviado! Entre em contato com o vendedor para combinar o pagamento.',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusCard() {
    return CartBaseWidget.buildInfoContainer(
      color: Colors.green,
      borderColor: Colors.green,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPix ? Icons.receipt_long : Icons.handshake,
              color: Colors.green,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPix ? 'Comprovante Anexado' : 'Pagamento a Combinar',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPix 
                ? 'Aguarde a confirmação do pagamento'
                : 'O vendedor entrará em contato',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    return CartBaseWidget.buildInfoContainer(
      color: const Color(0xFF9147FF),
      borderColor: const Color(0xFF9147FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9147FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.store,
                  color: Color(0xFF9147FF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Informações do Vendedor',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            context: context,
            icon: Icons.store_outlined,
            label: storeInfo.storeName,
            color: const Color(0xFF9147FF),
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            context: context,
            icon: Icons.phone,
            label: storeInfo.phoneNumber!,
            color: Colors.blue,
            canCopy: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    bool canCopy = false,
  }) {
    Widget content = Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        if (canCopy) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.content_copy,
            color: Colors.white54,
            size: 14,
          ),
        ],
      ],
    );

    if (canCopy) {
      return InkWell(
        onTap: () => _copyToClipboard(context, label),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildNextSteps() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Próximos Passos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...isPix ? _buildPixNextSteps() : _buildOtherNextSteps(),
        ],
      ),
    );
  }

  List<Widget> _buildPixNextSteps() {
    return [
      _buildStepText('1. O vendedor analisará seu comprovante'),
      _buildStepText('2. Você receberá uma confirmação do pedido'),
      _buildStepText('3. O vendedor entrará em contato para entrega/retirada'),
    ];
  }

  List<Widget> _buildOtherNextSteps() {
    return [
      _buildStepText('1. O vendedor receberá seu pedido'),
      _buildStepText('2. Ele entrará em contato para combinar o pagamento'),
      _buildStepText('3. Após acertarem, organizarão entrega/retirada'),
    ];
  }

  Widget _buildStepText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contato copiado para área de transferência'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      Logger.info('OrderSuccessDialog: Contato copiado: $text');
    } catch (e) {
      Logger.error('OrderSuccessDialog: Erro ao copiar contato', error: e);
    }
  }
}

/// Widget de informações rápidas para usar em outras partes da app
class OrderStatusCard extends StatelessWidget {
  final String status;
  final String paymentMethod;
  final bool isPaid;

  const OrderStatusCard({
    super.key,
    required this.status,
    required this.paymentMethod,
    this.isPaid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _getPaymentText(),
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
      ),
    );
  }

  Color _getStatusColor() {
    if (isPaid) return Colors.green;
    if (paymentMethod == 'pix') return Colors.orange;
    return Colors.blue;
  }

  IconData _getStatusIcon() {
    if (isPaid) return Icons.check_circle;
    if (paymentMethod == 'pix') return Icons.receipt_long;
    return Icons.handshake;
  }

  String _getPaymentText() {
    if (isPaid) return 'Pagamento confirmado';
    if (paymentMethod == 'pix') return 'Aguardando confirmação do PIX';
    return 'Pagamento a combinar';
  }
}