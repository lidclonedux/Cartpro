// lib/screens/admin/tabs/orders/dialogs/payment_proof_dialog.dart

import 'package:flutter/material.dart';
import '../../../../../utils/logger.dart';

class PaymentProofDialog {
  static void show(BuildContext context, String imageUrl) {
    Logger.info('PaymentProofDialog: Exibindo comprovante de pagamento: $imageUrl');
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(dialogContext, imageUrl),
              _buildImageViewer(imageUrl),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildHeader(BuildContext context, String imageUrl) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2F33),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: AppBar(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF9147FF)),
            SizedBox(width: 8),
            Text(
              'Comprovante de Pagamento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () {
            Logger.info('PaymentProofDialog: Dialog fechado pelo usuário');
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Color(0xFF9147FF)),
            tooltip: 'Abrir no navegador',
            onPressed: () => _openInBrowser(context, imageUrl),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF9147FF)),
            tooltip: 'Download (Em breve)',
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
    );
  }

  static Widget _buildImageViewer(String imageUrl) {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 600,
          maxWidth: 500,
          minHeight: 200,
        ),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                
                final progress = loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                    : null;

                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF9147FF),
                          value: progress,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Carregando comprovante...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFF9147FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                Logger.error('PaymentProofDialog: Erro ao carregar comprovante', error: error);
                return _buildErrorState();
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildErrorState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Erro ao carregar comprovante',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Verifique sua conexão com a internet ou tente novamente mais tarde',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static void _openInBrowser(BuildContext context, String imageUrl) {
    Logger.info('PaymentProofDialog: Solicitação para abrir no navegador: $imageUrl');
    
    // TODO: Implementar abertura no navegador usando url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Funcionalidade "Abrir no Navegador" em desenvolvimento'),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'COPIAR URL',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implementar cópia da URL para área de transferência
            Logger.info('PaymentProofDialog: Copiando URL para área de transferência');
          },
        ),
      ),
    );
  }

  static void _downloadImage(BuildContext context) {
    Logger.info('PaymentProofDialog: Solicitação de download de comprovante');
    
    // TODO: Implementar download da imagem
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Funcionalidade de download será implementada em breve'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Método utilitário para validar URL de imagem
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    // Verificar se é uma URL válida e se parece com uma imagem
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerUrl = url.toLowerCase();
    
    return imageExtensions.any((ext) => lowerUrl.contains(ext)) ||
           lowerUrl.contains('image') ||
           lowerUrl.contains('photo') ||
           lowerUrl.contains('picture');
  }
}