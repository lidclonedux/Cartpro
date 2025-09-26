// lib/screens/cartpro/widgets/cart_loading_widget.dart

import 'package:flutter/material.dart';

class CartLoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const CartLoadingWidget({
    super.key,
    this.message,
    this.size = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: color ?? const Color(0xFF9147FF),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class CartLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;

  const CartLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                color: const Color(0xFF23272A),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CartLoadingWidget(
                    message: loadingMessage ?? 'Processando...',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}