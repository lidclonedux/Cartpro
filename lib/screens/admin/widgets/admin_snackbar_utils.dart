// lib/screens/admin/widgets/admin_snackbar_utils.dart

import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

class AdminSnackBarUtils {
  
  /// Exibe SnackBar de erro com opção de retry
  static void showError(BuildContext context, String message, {VoidCallback? onRetry}) {
    if (!context.mounted) return;
    
    Logger.warning('AdminSnackBar: Exibindo erro - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: onRetry != null ? SnackBarAction(
          label: 'TENTAR NOVAMENTE',
          textColor: Colors.white,
          backgroundColor: Colors.red.shade900,
          onPressed: onRetry,
        ) : null,
      ),
    );
  }

  /// Exibe SnackBar de sucesso
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Exibindo sucesso - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Exibe SnackBar de aviso
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Exibindo aviso - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Exibe SnackBar de informação
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Exibindo informação - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Exibe SnackBar de carregamento com indicador
  static void showLoading(BuildContext context, String message) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Exibindo carregamento - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF9147FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Exibe SnackBar de confirmação com ação
  static void showConfirmation(
    BuildContext context, 
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Exibindo confirmação - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF23272A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: actionLabel.toUpperCase(),
          textColor: const Color(0xFF9147FF),
          backgroundColor: Colors.white.withOpacity(0.1),
          onPressed: onAction,
        ),
      ),
    );
  }

  /// Remove todos os SnackBars ativos
  static void dismissAll(BuildContext context) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Removendo todos os SnackBars');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Exibe SnackBar personalizado com cores customizadas
  static void showCustom(
    BuildContext context, 
    String message, {
    required Color backgroundColor,
    required IconData icon,
    Color? textColor,
    Color? iconColor,
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    Logger.info('AdminSnackBar: Exibindo SnackBar customizado - $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon, 
              color: iconColor ?? textColor ?? Colors.white, 
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor ?? Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: duration ?? const Duration(seconds: 3),
        action: action,
      ),
    );
  }
}