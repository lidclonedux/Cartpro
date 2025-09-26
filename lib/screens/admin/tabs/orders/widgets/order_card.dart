// lib/screens/admin/tabs/orders/widgets/order_card.dart

import 'package:flutter/material.dart';

// Models
import '../../../../../models/order.dart';

// Widgets
import 'order_status_badge.dart';

// Utils
import '../../../../../utils/logger.dart';

class OrderCard extends StatefulWidget {
  final Order order;
  final Function(String newStatus) onStatusUpdate;
  final VoidCallback? onViewProof;
  final bool isCompact;

  const OrderCard({
    super.key,
    required this.order,
    required this.onStatusUpdate,
    this.onViewProof,
    this.isCompact = false,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactCard();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
            Logger.info('OrderCard: ${expanded ? 'Expandindo' : 'Contraindo'} pedido ${widget.order.id}');
          },
          title: _buildOrderTitle(),
          subtitle: _buildOrderSubtitle(),
          children: [_buildExpandedContent()],
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF23272A),
      child: ListTile(
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Pedido #${widget.order.id.substring(0, 8)}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            OrderStatusBadge(status: widget.order.status),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                widget.order.customerInfo.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              'R\$ ${widget.order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF9147FF),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => setState(() => _isExpanded = !_isExpanded),
      ),
    );
  }

  Widget _buildOrderTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Pedido #${widget.order.id.substring(0, 8)}...',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        OrderStatusBadge(status: widget.order.status),
      ],
    );
  }

  Widget _buildOrderSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          widget.order.customerInfo.name,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildPaymentMethodBadge(),
            const Spacer(),
            Text(
              'R\$ ${widget.order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF9147FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(widget.order.createdAt),
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodBadge() {
    Color paymentMethodColor;
    String paymentMethodText;
    IconData paymentMethodIcon;

    bool hasPixProof = widget.order.payment_method == 'pix' && 
                       widget.order.payment_proof_url != null && 
                       widget.order.payment_proof_url!.isNotEmpty;

    if (hasPixProof) {
      paymentMethodColor = Colors.blue;
      paymentMethodText = 'PIX (Comprovante)';
      paymentMethodIcon = Icons.receipt_long;
    } else if (widget.order.payment_method == 'pix') {
      paymentMethodColor = Colors.green;
      paymentMethodText = 'PIX';
      paymentMethodIcon = Icons.pix;
    } else {
      paymentMethodColor = Colors.orange;
      paymentMethodText = 'A Combinar';
      paymentMethodIcon = Icons.handshake;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: paymentMethodColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paymentMethodColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(paymentMethodIcon, size: 12, color: paymentMethodColor),
          const SizedBox(width: 4),
          Text(
            paymentMethodText,
            style: TextStyle(color: paymentMethodColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerInfo(),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 12),
          _buildPaymentInfo(),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 12),
          _buildOrderItems(),
          const SizedBox(height: 16),
          _buildOrderTotal(),
          const SizedBox(height: 16),
          if (widget.order.status == 'pending' || widget.order.status == 'confirmed')
            _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.person, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text(
              'Informações do Cliente:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Nome:', widget.order.customerInfo.name),
        _buildInfoRow('Email:', widget.order.customerInfo.email),
        _buildInfoRow('Telefone:', widget.order.customerInfo.phone),
        
        // ✅ CORREÇÃO APLICADA AQUI
        if (widget.order.deliveryAddress != null)
          _buildInfoRow('Endereço:', widget.order.deliveryAddress.toString()),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    Widget paymentContent;

    if (widget.order.payment_method == 'pix' && 
        widget.order.payment_proof_url != null && 
        widget.order.payment_proof_url!.isNotEmpty) {
      paymentContent = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Comprovante de pagamento anexado',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.onViewProof != null)
              ElevatedButton.icon(
                onPressed: widget.onViewProof,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Ver', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
    } else if (widget.order.payment_method == 'pix') {
      paymentContent = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aguardando comprovante de pagamento PIX',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      paymentContent = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: const Row(
          children: [
            Icon(Icons.handshake, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pagamento a combinar com o cliente',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.payment, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text(
              'Informações de Pagamento:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        paymentContent,
      ],
    );
  }

  Widget _buildOrderItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Itens do Pedido:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF9147FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9147FF)),
              ),
              child: Text(
                '${widget.order.items.length} ${widget.order.items.length == 1 ? 'item' : 'itens'}',
                style: const TextStyle(
                  color: Color(0xFF9147FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.order.items.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Nenhum item encontrado neste pedido',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
          )
        else
          ...widget.order.items.asMap().entries.map((entry) {
            final int index = entry.key;
            final item = entry.value;
            final bool isLast = index == widget.order.items.length - 1;
            
            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9147FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Qtd: ${item.quantity}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Unit.: R\$ ${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'R\$ ${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF9147FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildOrderTotal() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF9147FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF9147FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.monetization_on, color: Color(0xFF9147FF), size: 18),
              SizedBox(width: 8),
              Text(
                'Total do Pedido:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Text(
            'R\$ ${widget.order.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF9147FF),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.order.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Logger.info('OrderCard: Confirmando pedido ${widget.order.id}');
                widget.onStatusUpdate('confirmed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirmar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Logger.info('OrderCard: Cancelando pedido ${widget.order.id}');
                widget.onStatusUpdate('cancelled');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancelar'),
            ),
          ),
        ],
      );
    } else if (widget.order.status == 'confirmed') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Logger.info('OrderCard: Marcando pedido ${widget.order.id} como entregue');
            widget.onStatusUpdate('delivered');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.local_shipping),
          label: const Text('Marcar como Entregue'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Versão simplificada do OrderCard para listas densas
class CompactOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactOrderCard({
    super.key,
    required this.order,
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
          radius: 16,
          backgroundColor: _getStatusColor().withOpacity(0.2),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 16,
          ),
        ),
        title: Text(
          'Pedido #${order.id.substring(0, 8)}...',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                order.customerInfo.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'R\$ ${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF9147FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: trailing ?? OrderStatusBadge(status: order.status, isSmall: true),
      ),
    );
  }

  Color _getStatusColor() {
    switch (order.status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (order.status) {
      case 'pending':
        return Icons.pending;
      case 'confirmed':
        return Icons.check_circle;
      case 'delivered':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

}
