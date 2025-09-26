// lib/screens/cartpro/dialogs/payment_info_display.dart - PÓS-FISIOTERAPIA

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_method_info.dart'; // Corrigido para o caminho correto
import '../widgets/cart_base_widget.dart';
import '../../../utils/logger.dart';

class PaymentInfoDisplay extends StatelessWidget {
  final StorePaymentInfo storeInfo;
  final double totalAmount;

  const PaymentInfoDisplay({
    super.key,
    required this.storeInfo,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return CartBaseWidget.buildInfoContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          // ===================== INÍCIO DA INTERVENÇÃO =====================
          // Passando o contexto para o método para que ele possa mostrar o SnackBar
          _buildContactInfo(context),
          // ===================== FIM DA INTERVENÇÃO ======================
          if (storeInfo.hasPixKey) ...[
            const SizedBox(height: 12),
            _buildPixInfo(context),
          ],
          const SizedBox(height: 16),
          _buildTotalAmount(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9147FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.store,
            color: Color(0xFF9147FF),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeInfo.storeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Text(
                'Informações do Vendedor',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== INÍCIO DA INTERVENÇÃO =====================
  // A função agora recebe o BuildContext para poder usar o ScaffoldMessenger
  Widget _buildContactInfo(BuildContext context) {
    if (!storeInfo.hasPhone) return const SizedBox.shrink();

    return _buildInfoRow(
      icon: Icons.phone,
      label: 'Contato',
      value: storeInfo.phoneNumber!,
      color: Colors.blue,
      canCopy: true,
      // AÇÃO DE COPIAR CONECTADA
      onTap: () => _copyToClipboard(context, storeInfo.phoneNumber!, 'Número de contato'),
    );
  }
  // ===================== FIM DA INTERVENÇÃO ======================

  Widget _buildPixInfo(BuildContext context) {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.pix,
          label: 'Chave PIX',
          value: storeInfo.pixKey!,
          color: Colors.green,
          canCopy: true,
          onTap: () => _copyToClipboard(context, storeInfo.pixKey!, 'Chave PIX'),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Toque na chave PIX ou no contato para copiar', // Mensagem atualizada
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.content_copy,
                color: Colors.green.withOpacity(0.7),
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAmount() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF9147FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF9147FF).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF9147FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.payment,
              color: Color(0xFF9147FF),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Valor Total:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            'R\$ ${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF9147FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool canCopy = false,
    VoidCallback? onTap,
  }) {
    Widget content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (canCopy) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.content_copy,
            color: Colors.white54,
            size: 16,
          ),
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text, String label) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copiado para área de transferência'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
      
      Logger.info('PaymentInfoDisplay: $label copiado: $text');
    } catch (e) {
      Logger.error('PaymentInfoDisplay: Erro ao copiar $label', error: e);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao copiar $label'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class PaymentSummaryCard extends StatelessWidget {
  final String paymentMethod;
  final double totalAmount;
  final int itemCount;
  final bool isDelivery;

  const PaymentSummaryCard({
    super.key,
    required this.paymentMethod,
    required this.totalAmount,
    required this.itemCount,
    required this.isDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPaymentIcon(),
                  color: _getPaymentColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Resumo do Pedido',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Itens', '$itemCount produto${itemCount > 1 ? 's' : ''}'),
            _buildSummaryRow('Entrega', isDelivery ? 'Sim' : 'Retirada no local'),
            _buildSummaryRow('Pagamento', _getPaymentMethodText()),
            const Divider(color: Colors.white24),
            _buildSummaryRow(
              'Total',
              'R\$ ${totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? const Color(0xFF9147FF) : Colors.white,
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon() {
    switch (paymentMethod) {
      case 'pix':
        return Icons.pix;
      case 'other':
        return Icons.handshake;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentColor() {
    switch (paymentMethod) {
      case 'pix':
        return Colors.green;
      case 'other':
        return const Color(0xFF9147FF);
      default:
        return Colors.blue;
    }
  }

  String _getPaymentMethodText() {
    switch (paymentMethod) {
      case 'pix':
        return 'PIX com comprovante';
      case 'other':
        return 'A combinar';
      default:
        return 'Não definido';
    }
  }
}
