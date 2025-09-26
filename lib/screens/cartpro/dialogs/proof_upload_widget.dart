// lib/screens/cartpro/dialogs/proof_upload_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/logger.dart';

class ProofUploadWidget extends StatelessWidget {
  final File? proofImage;
  final bool isUploading;
  final VoidCallback onSelectImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback? onEditImage;

  const ProofUploadWidget({
    super.key,
    required this.proofImage,
    required this.isUploading,
    required this.onSelectImage,
    this.onRemoveImage,
    this.onEditImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUploadArea(),
        if (proofImage != null) ...[
          const SizedBox(height: 12),
          _buildImageActions(),
        ],
      ],
    );
  }

  Widget _buildUploadArea() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: proofImage != null ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: proofImage != null ? Colors.green : Colors.grey,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploading ? null : onSelectImage,
          borderRadius: BorderRadius.circular(8),
          child: _buildUploadContent(),
        ),
      ),
    );
  }

  Widget _buildUploadContent() {
    if (isUploading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF9147FF)),
          SizedBox(height: 8),
          Text(
            'Preparando imagem...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (proofImage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comprovante Anexado',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toque para alterar',
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.upload_file,
            color: Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toque para anexar',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'comprovante de pagamento',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImageActions() {
    return Row(
      children: [
        if (onEditImage != null)
          Expanded(
            child: TextButton.icon(
              onPressed: onEditImage,
              icon: const Icon(Icons.edit, color: Color(0xFF9147FF), size: 16),
              label: const Text(
                'Alterar Imagem',
                style: TextStyle(
                  color: Color(0xFF9147FF),
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        if (onEditImage != null && onRemoveImage != null)
          const SizedBox(width: 8),
        if (onRemoveImage != null)
          Expanded(
            child: TextButton.icon(
              onPressed: onRemoveImage,
              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
              label: const Text(
                'Remover',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
      ],
    );
  }
}

class ProofUploadService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> selectImage() async {
    try {
      Logger.info('ProofUploadService: Selecionando imagem de comprovante');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        Logger.info('ProofUploadService: Imagem selecionada: ${image.path}');
        return File(image.path);
      }

      Logger.info('ProofUploadService: Seleção de imagem cancelada');
      return null;
      
    } catch (e) {
      Logger.error('ProofUploadService: Erro ao selecionar imagem', error: e);
      rethrow;
    }
  }

  static Future<File?> selectImageFromCamera() async {
    try {
      Logger.info('ProofUploadService: Capturando imagem da câmera');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        Logger.info('ProofUploadService: Imagem capturada: ${image.path}');
        return File(image.path);
      }

      Logger.info('ProofUploadService: Captura de imagem cancelada');
      return null;
      
    } catch (e) {
      Logger.error('ProofUploadService: Erro ao capturar imagem', error: e);
      rethrow;
    }
  }

  static void showImageSourceDialog(
    BuildContext context, {
    required Function(File) onImageSelected,
    required VoidCallback onError,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          title: const Text(
            'Selecionar Comprovante',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Como você quer anexar o comprovante de pagamento?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final image = await selectImageFromCamera();
                  if (image != null) {
                    onImageSelected(image);
                  }
                } catch (e) {
                  onError();
                }
              },
              icon: const Icon(Icons.camera_alt, color: Color(0xFF9147FF)),
              label: const Text(
                'Câmera',
                style: TextStyle(color: Color(0xFF9147FF)),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final image = await selectImage();
                  if (image != null) {
                    onImageSelected(image);
                  }
                } catch (e) {
                  onError();
                }
              },
              icon: const Icon(Icons.photo_library, color: Color(0xFF9147FF)),
              label: const Text(
                'Galeria',
                style: TextStyle(color: Color(0xFF9147FF)),
              ),
            ),
          ],
        );
      },
    );
  }
}