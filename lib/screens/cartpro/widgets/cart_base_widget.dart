
  //  Arquivo lib/screens/cartpro/widgets/cart_base_widget.dart


import 'package:flutter/material.dart';

class CartBaseWidget {
  static Widget buildCard({
    required Widget child,
    EdgeInsets? margin,
    EdgeInsets? padding,
    Color? color,
  }) {
    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      color: color ?? const Color(0xFF23272A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  static Widget buildSection({
    required String title,
    required Widget content,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  static Widget buildInfoContainer({
    required Widget child,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF9147FF)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? const Color(0xFF9147FF),
        ),
      ),
      child: child,
    );
  }
}

