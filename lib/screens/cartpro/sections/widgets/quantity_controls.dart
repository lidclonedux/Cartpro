// lib/screens/cartpro/sections/widgets/quantity_controls.dart

import 'package:flutter/material.dart';
import '../../../../utils/logger.dart';

class QuantityControls extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final int maxQuantity;
  final bool isEnabled;

  const QuantityControls({
    super.key,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
    required this.maxQuantity,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final canIncrease = isEnabled && quantity < maxQuantity;
    final canDecrease = isEnabled && quantity > 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: Icons.remove,
            onPressed: canDecrease ? onDecrease : null,
            isDecrease: true,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 45),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          _buildControlButton(
            icon: Icons.add,
            onPressed: canIncrease ? onIncrease : null,
            isDecrease: false,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDecrease,
  }) {
    final isEnabled = onPressed != null;
    final color = isEnabled 
        ? (isDecrease ? Colors.red : const Color(0xFF9147FF))
        : Colors.white24;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed != null ? () {
          Logger.info('CartPro: ${isDecrease ? 'Diminuindo' : 'Aumentando'} quantidade');
          onPressed();
        } : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isEnabled ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }
}