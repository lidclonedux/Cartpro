// lib/screens/admin/tabs/orders/widgets/order_status_badge.dart

import 'package:flutter/material.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool isSmall;
  final bool showIcon;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.isSmall = false,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(status);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: statusInfo['color'].withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusInfo['color']),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              statusInfo['icon'],
              size: isSmall ? 12 : 14,
              color: statusInfo['color'],
            ),
            SizedBox(width: isSmall ? 2 : 4),
          ],
          Text(
            statusInfo['text'],
            style: TextStyle(
              color: statusInfo['color'],
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'text': 'Pendente',
          'color': Colors.orange,
          'icon': Icons.pending,
        };
      case 'confirmed':
        return {
          'text': 'Confirmado',
          'color': Colors.blue,
          'icon': Icons.check_circle,
        };
      case 'completed':
      case 'delivered':
        return {
          'text': 'Entregue',
          'color': Colors.green,
          'icon': Icons.local_shipping,
        };
      case 'cancelled':
        return {
          'text': 'Cancelado',
          'color': Colors.red,
          'icon': Icons.cancel,
        };
      case 'processing':
        return {
          'text': 'Processando',
          'color': Colors.purple,
          'icon': Icons.autorenew,
        };
      case 'shipped':
        return {
          'text': 'Enviado',
          'color': Colors.indigo,
          'icon': Icons.local_shipping,
        };
      default:
        return {
          'text': 'Desconhecido',
          'color': Colors.grey,
          'icon': Icons.help,
        };
    }
  }
}

/// Badge personalizado para método de pagamento
class PaymentMethodBadge extends StatelessWidget {
  final String paymentMethod;
  final String? proofUrl;
  final bool isSmall;

  const PaymentMethodBadge({
    super.key,
    required this.paymentMethod,
    this.proofUrl,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final paymentInfo = _getPaymentInfo();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: paymentInfo['color'].withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paymentInfo['color']),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paymentInfo['icon'],
            size: isSmall ? 12 : 14,
            color: paymentInfo['color'],
          ),
          SizedBox(width: isSmall ? 2 : 4),
          Text(
            paymentInfo['text'],
            style: TextStyle(
              color: paymentInfo['color'],
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getPaymentInfo() {
    bool hasPixProof = paymentMethod == 'pix' && 
                       proofUrl != null && 
                       proofUrl!.isNotEmpty;

    if (hasPixProof) {
      return {
        'text': 'PIX (Comprovante)',
        'color': Colors.blue,
        'icon': Icons.receipt_long,
      };
    } else if (paymentMethod == 'pix') {
      return {
        'text': 'PIX',
        'color': Colors.green,
        'icon': Icons.pix,
      };
    } else if (paymentMethod == 'credit_card') {
      return {
        'text': 'Cartão',
        'color': Colors.purple,
        'icon': Icons.credit_card,
      };
    } else if (paymentMethod == 'cash') {
      return {
        'text': 'Dinheiro',
        'color': Colors.teal,
        'icon': Icons.money,
      };
    } else {
      return {
        'text': 'A Combinar',
        'color': Colors.orange,
        'icon': Icons.handshake,
      };
    }
  }
}

/// Badge de prioridade do pedido
class OrderPriorityBadge extends StatelessWidget {
  final String priority;
  final bool isSmall;

  const OrderPriorityBadge({
    super.key,
    required this.priority,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final priorityInfo = _getPriorityInfo();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 4 : 6,
        vertical: isSmall ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: priorityInfo['color'].withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityInfo['color'], width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            priorityInfo['icon'],
            size: isSmall ? 10 : 12,
            color: priorityInfo['color'],
          ),
          SizedBox(width: isSmall ? 2 : 3),
          Text(
            priorityInfo['text'],
            style: TextStyle(
              color: priorityInfo['color'],
              fontSize: isSmall ? 9 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getPriorityInfo() {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return {
          'text': 'URGENTE',
          'color': Colors.red,
          'icon': Icons.priority_high,
        };
      case 'medium':
      case 'normal':
        return {
          'text': 'NORMAL',
          'color': Colors.blue,
          'icon': Icons.remove,
        };
      case 'low':
        return {
          'text': 'BAIXA',
          'color': Colors.green,
          'icon': Icons.keyboard_arrow_down,
        };
      default:
        return {
          'text': 'NORMAL',
          'color': Colors.grey,
          'icon': Icons.remove,
        };
    }
  }
}

/// Badge personalizado genérico
class CustomBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool isSmall;
  final bool isOutlined;

  const CustomBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.isSmall = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isSmall ? 12 : 14,
              color: color,
            ),
            SizedBox(width: isSmall ? 2 : 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge com animação pulsante para status críticos
class AnimatedStatusBadge extends StatefulWidget {
  final String status;
  final bool isSmall;
  final bool shouldAnimate;

  const AnimatedStatusBadge({
    super.key,
    required this.status,
    this.isSmall = false,
    this.shouldAnimate = true,
  });

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.shouldAnimate && _shouldPulse()) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _shouldPulse() {
    return widget.status == 'pending' || widget.status == 'urgent';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.shouldAnimate && _shouldPulse() ? _pulseAnimation.value : 1.0,
          child: OrderStatusBadge(
            status: widget.status,
            isSmall: widget.isSmall,
          ),
        );
      },
    );
  }
}