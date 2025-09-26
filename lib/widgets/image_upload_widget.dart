// lib/widgets/image_upload_widget.dart - VERSÃO CORRIGIDA E OTIMIZADA

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/permissions_service.dart';
import '../utils/logger.dart';

enum ImageUploadType {
  productImage,
  paymentProof,
  pixQrCode,
}

class ImageUploadWidget extends StatefulWidget {
  final ImageUploadType uploadType;
  final String? currentImageUrl;
  final Function(String imageUrl, String publicId) onImageUploaded;
  final Function()? onImageRemoved;
  final String? productId;
  final String? userId;
  final String? orderId;
  final String? description;
  final double width;
  final double height;
  final bool isRequired;
  final String placeholder;

  // ✅ NOVOS: Parâmetros para compatibilidade com product_dialog.dart
  final String? placeholderText;
  final IconData? placeholderIcon;
  final Function(File)? onImageSelected; // ✅ CRÍTICO: Callback direto para arquivo
  final String? initialImageUrl;

  const ImageUploadWidget({
    super.key,
    required this.uploadType,
    required this.onImageUploaded,
    this.currentImageUrl,
    this.onImageRemoved,
    this.productId,
    this.userId,
    this.orderId,
    this.description,
    this.width = 200,
    this.height = 200,
    this.isRequired = false,
    this.placeholder = 'Toque para adicionar imagem',
    this.placeholderText,
    this.placeholderIcon,
    this.onImageSelected, // ✅ NOVO: Permite callback direto
    this.initialImageUrl,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  bool _isUploading = false;
  File? _selectedFile;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.initialImageUrl ?? widget.currentImageUrl;
    
    Logger.info('ImageUploadWidget: Inicializado para ${widget.uploadType}');
    if (_currentImageUrl != null) {
      Logger.info('ImageUploadWidget: URL inicial definida');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CORREÇÃO: Web version mais robusta
    if (kIsWeb) {
      return _buildWebVersion();
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildContent(),
    );
  }

  // ✅ MELHORIA: Versão web mais informativa
  Widget _buildWebVersion() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: _currentImageUrl != null 
            ? Colors.green.withOpacity(0.1) 
            : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: _currentImageUrl != null ? Colors.green : Colors.grey.withOpacity(0.5), 
          width: 1
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _currentImageUrl != null 
          ? _buildWebImagePreview()
          : _buildWebPlaceholder(),
    );
  }

  Widget _buildWebImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _currentImageUrl!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.blue,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              Logger.error('ImageUploadWidget: Erro ao carregar imagem web', error: error);
              return Container(
                color: Colors.red.withOpacity(0.1),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 32),
                    SizedBox(height: 8),
                    Text('Erro ao carregar', 
                         style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.onImageRemoved != null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () {
                  setState(() => _currentImageUrl = null);
                  widget.onImageRemoved!();
                  _showSnackBar('Imagem removida', Colors.orange);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.web, color: Colors.grey, size: 32),
        const SizedBox(height: 8),
        Text(
          'Upload via navegador',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Use o ProductDialog para seleção',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getBackgroundColor() {
    if (_currentImageUrl != null) {
      return Colors.green.withOpacity(0.1);
    }
    if (_isUploading) {
      return const Color(0xFF9147FF).withOpacity(0.1);
    }
    if (widget.isRequired) {
      return Colors.red.withOpacity(0.1);
    }
    return Colors.grey.withOpacity(0.1);
  }

  Color _getBorderColor() {
    if (_currentImageUrl != null) {
      return Colors.green;
    }
    if (_isUploading) {
      return const Color(0xFF9147FF);
    }
    if (widget.isRequired) {
      return Colors.red;
    }
    return Colors.grey;
  }

  Widget _buildContent() {
    if (_isUploading) {
      return _buildUploadingState();
    }
    
    if (_currentImageUrl != null) {
      return _buildImagePreview();
    }
    
    return _buildPlaceholder();
  }

  Widget _buildUploadingState() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Color(0xFF9147FF)),
        SizedBox(height: 12),
        Text(
          'Preparando...',
          style: TextStyle(
            color: Color(0xFF9147FF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _currentImageUrl!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFF9147FF),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              Logger.error('ImageUploadWidget: Erro ao carregar imagem', error: error);
              return Container(
                color: Colors.grey.withOpacity(0.3),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Erro ao carregar\nimagem',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withOpacity(0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _selectImage,
                      icon: const Icon(Icons.edit, color: Colors.white),
                      tooltip: 'Trocar imagem',
                    ),
                    IconButton(
                      onPressed: () => _showImagePreview(context),
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      tooltip: 'Visualizar',
                    ),
                    if (widget.onImageRemoved != null)
                      IconButton(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remover imagem',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return InkWell(
      onTap: _selectImage,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.placeholderIcon ?? _getPlaceholderIcon(),
            color: Colors.grey,
            size: 48,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.placeholderText ?? widget.placeholder,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.isRequired) ...[
            const SizedBox(height: 8),
            const Text(
              'Obrigatório',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getPlaceholderIcon() {
    switch (widget.uploadType) {
      case ImageUploadType.productImage:
        return Icons.add_a_photo;
      case ImageUploadType.paymentProof:
        return Icons.receipt_long;
      case ImageUploadType.pixQrCode:
        return Icons.qr_code;
    }
  }

  // ✅ CORREÇÃO PRINCIPAL: Método de seleção otimizado
  Future<void> _selectImage() async {
    if (_isUploading) {
      Logger.warning('ImageUploadWidget: Upload em andamento, ignorando nova seleção');
      return;
    }

    if (kIsWeb) {
      Logger.info('ImageUploadWidget: Seleção na web não suportada diretamente');
      _showSnackBar('Use o formulário principal para seleção de imagem na web', Colors.blue);
      return;
    }

    try {
      setState(() => _isUploading = true);
      
      Logger.info('ImageUploadWidget: Iniciando seleção de imagem');
      
      final file = await PermissionsService.showImageSourceDialog(
        context: context,
        title: _getDialogTitle(),
        maxWidth: _getMaxWidth(),
        maxHeight: _getMaxHeight(),
        imageQuality: _getImageQuality(),
      );

      if (file != null) {
        Logger.info('ImageUploadWidget: Arquivo selecionado: ${file.path}');
        
        setState(() {
          _selectedFile = file;
        });

        // ✅ CORREÇÃO CRÍTICA: Prioriza callback direto se fornecido
        if (widget.onImageSelected != null) {
          Logger.info('ImageUploadWidget: Delegando upload via callback');
          widget.onImageSelected!(file);
        } else {
          // ✅ FALLBACK: Se não há callback, informa erro
          Logger.error('ImageUploadWidget: Nenhum callback de upload configurado');
          _showSnackBar('Erro: Sistema de upload não configurado', Colors.red);
        }
      } else {
        Logger.info('ImageUploadWidget: Seleção cancelada pelo usuário');
      }
      
    } catch (e) {
      Logger.error('ImageUploadWidget: Erro ao selecionar imagem', error: e);
      _showSnackBar('Erro ao selecionar imagem: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _getDialogTitle() {
    switch (widget.uploadType) {
      case ImageUploadType.productImage:
        return 'Foto do Produto';
      case ImageUploadType.paymentProof:
        return 'Comprovante de Pagamento';
      case ImageUploadType.pixQrCode:
        return 'QR Code PIX';
    }
  }

  int _getMaxWidth() {
    switch (widget.uploadType) {
      case ImageUploadType.productImage:
        return 1024;
      case ImageUploadType.paymentProof:
        return 800;
      case ImageUploadType.pixQrCode:
        return 512;
    }
  }

  int _getMaxHeight() {
    switch (widget.uploadType) {
      case ImageUploadType.productImage:
        return 1024;
      case ImageUploadType.paymentProof:
        return 800;
      case ImageUploadType.pixQrCode:
        return 512;
    }
  }

  int _getImageQuality() {
    switch (widget.uploadType) {
      case ImageUploadType.productImage:
        return 85;
      case ImageUploadType.paymentProof:
        return 90;
      case ImageUploadType.pixQrCode:
        return 100;
    }
  }

  void _removeImage() {
    setState(() {
      _currentImageUrl = null;
      _selectedFile = null;
    });
    
    if (widget.onImageRemoved != null) {
      widget.onImageRemoved!();
    }
    
    _showSnackBar('Imagem removida', Colors.orange);
  }

  void _showImagePreview(BuildContext context) {
    if (_currentImageUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  _currentImageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF9147FF),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.black54,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Erro ao carregar imagem',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: color == Colors.red ? 4 : 2),
      ),
    );
  }

  // ✅ NOVO: Método público para atualizar URL externamente
  void updateImageUrl(String? url) {
    if (mounted) {
      setState(() {
        _currentImageUrl = url;
        _selectedFile = null;
      });
      
      if (url != null) {
        Logger.info('ImageUploadWidget: URL atualizada externamente');
      }
    }
  }

  // ✅ NOVO: Getter para verificar se há imagem
  bool get hasImage => _currentImageUrl != null || _selectedFile != null;

  // ✅ NOVO: Getter para URL atual
  String? get currentImageUrl => _currentImageUrl;
}