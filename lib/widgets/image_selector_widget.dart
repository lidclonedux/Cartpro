import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/services/permissions_service.dart';

enum ImageSourceOption {
  camera,
  gallery,
  file,
}

class ImageSelectorWidget extends StatefulWidget {
  final String? currentImageUrl;
  final String placeholderText;
  final IconData placeholderIcon;
  final Function(File? imageFile, String? fileName, Uint8List? webBytes) onImageSelected;
  final VoidCallback? onImageRemoved;
  final double maxWidth;
  final double maxHeight;
  final int imageQuality;
  final List<String> allowedExtensions;

  const ImageSelectorWidget({
    super.key,
    this.currentImageUrl,
    this.placeholderText = 'Selecionar Imagem',
    this.placeholderIcon = Icons.add_a_photo,
    required this.onImageSelected,
    this.onImageRemoved,
    this.maxWidth = 1024,
    this.maxHeight = 1024,
    this.imageQuality = 80,
    this.allowedExtensions = const ['jpg', 'jpeg', 'png', 'webp'],
  });

  @override
  State<ImageSelectorWidget> createState() => _ImageSelectorWidgetState();
}

class _ImageSelectorWidgetState extends State<ImageSelectorWidget> {
  File? _selectedFile;
  String? _selectedFileName;
  Uint8List? _webImageBytes;
  String? _displayImageUrl;

  @override
  void initState() {
    super.initState();
    _displayImageUrl = widget.currentImageUrl;
  }

  @override
  void didUpdateWidget(covariant ImageSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentImageUrl != oldWidget.currentImageUrl) {
      setState(() {
        _displayImageUrl = widget.currentImageUrl;
        _selectedFile = null;
        _selectedFileName = null;
        _webImageBytes = null;
      });
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      await _pickImageWeb();
    } else {
      await _pickImageMobile();
    }
  }

  Future<void> _pickImageWeb() async {
    try {
      Logger.info('ImageSelector: Iniciando seleção de arquivo web');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes == null) {
          _showSnackBar('Erro: arquivo sem dados válidos', Colors.red);
          return;
        }

        // Validações de tamanho e extensão
        if (file.size > 10 * 1024 * 1024) { // 10MB
          _showSnackBar("Arquivo muito grande. Tamanho máximo: 10MB", Colors.red);
          return;
        }
        final fileExtension = file.extension?.toLowerCase();
        if (fileExtension == null || !widget.allowedExtensions.contains(fileExtension)) {
          _showSnackBar('Tipo de arquivo não suportado. Use ${widget.allowedExtensions.join(', ').toUpperCase()}', Colors.red);
          return;
        }

        final tempFile = await _createTempFileFromBytes(file.bytes!, file.name);

        setState(() {
          _selectedFile = tempFile;
          _selectedFileName = file.name;
          _webImageBytes = file.bytes;
          _displayImageUrl = null; // Limpa a URL atual se uma nova imagem for selecionada
        });
        widget.onImageSelected(_selectedFile, _selectedFileName, _webImageBytes);
        Logger.info('ImageSelector: Arquivo web selecionado: ${file.name}');
        _showSnackBar('Arquivo "${file.name}" selecionado!', Colors.green);
      }
    } catch (e) {
      Logger.error('ImageSelector: Erro ao selecionar arquivo na web', error: e);
      _showSnackBar('Erro ao selecionar arquivo: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _pickImageMobile() async {
    try {
      Logger.info('ImageSelector: Iniciando seleção de imagem mobile');
      final ImageSourceOption? source = await _showImageSourceDialog();

      if (source == null) {
        Logger.info('ImageSelector: Seleção cancelada pelo usuário');
        return;
      }

      final ImagePicker picker = ImagePicker();
      XFile? pickedFile;

      if (source == ImageSourceOption.camera) {
        pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          imageQuality: widget.imageQuality,
        );
      } else if (source == ImageSourceOption.gallery) {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          imageQuality: widget.imageQuality,
        );
      } else if (source == ImageSourceOption.file) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: widget.allowedExtensions,
        );
        if (result != null && result.files.isNotEmpty) {
          pickedFile = XFile(result.files.first.path!);
        }
      }

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // Validações de tamanho e extensão
        final fileSize = await imageFile.length();
        if (fileSize > 10 * 1024 * 1024) { // 10MB
          _showSnackBar("Arquivo muito grande. Tamanho máximo: 10MB", Colors.red);
          return;
        }
        final fileExtension = pickedFile.path.split('.').last.toLowerCase();
        if (!widget.allowedExtensions.contains(fileExtension)) {
          _showSnackBar('Tipo de arquivo não suportado. Use ${widget.allowedExtensions.join(', ').toUpperCase()}', Colors.red);
          return;
        }

        setState(() {
          _selectedFile = imageFile;
          _selectedFileName = pickedFile!.name;
          _displayImageUrl = null; // Limpa a URL atual se uma nova imagem for selecionada
        });
        widget.onImageSelected(_selectedFile, _selectedFileName, null);
        Logger.info('ImageSelector: Imagem mobile selecionada: ${pickedFile.path}');
        _showSnackBar('Imagem selecionada!', Colors.green);
      }
    } catch (e) {
      Logger.error('ImageSelector: Erro ao selecionar imagem mobile', error: e);
      _showSnackBar('Erro ao selecionar imagem: ${e.toString()}', Colors.red);
    }
  }

  Future<ImageSourceOption?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSourceOption>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white70),
                title: const Text('Câmera', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSourceOption.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white70),
                title: const Text('Galeria', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSourceOption.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.white70),
                title: const Text('Arquivos', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSourceOption.file),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> _createTempFileFromBytes(Uint8List bytes, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$filename');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  void _removeImage() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _webImageBytes = null;
      _displayImageUrl = null;
    });
    widget.onImageRemoved?.call();
    _showSnackBar('Imagem removida.', Colors.orange);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        border: Border.all(color: _getBorderColor(), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildContent(),
    );
  }

  Color _getBackgroundColor() {
    if (_displayImageUrl != null || _selectedFile != null) return Colors.green.withOpacity(0.1);
    return Colors.grey.withOpacity(0.1);
  }

  Color _getBorderColor() {
    if (_displayImageUrl != null || _selectedFile != null) return Colors.green;
    return Colors.white30;
  }

  Widget _buildContent() {
    if (_displayImageUrl != null) {
      return _buildImagePreview();
    } else if (_selectedFile != null) {
      return _buildFileSelected();
    } else {
      return _buildImageSelector();
    }
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _displayImageUrl!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.red.withOpacity(0.1),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 32),
                    Text('Erro ao carregar', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.edit, Colors.blue, _pickImage),
              const SizedBox(width: 4),
              _buildActionButton(Icons.close, Colors.red, _removeImage),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileSelected() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.blue, size: 40),
        const SizedBox(height: 8),
        const Text(
          'Arquivo Selecionado',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (_selectedFileName != null) ...[
          const SizedBox(height: 4),
          Text(
            _selectedFileName!,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Será enviado ao salvar o produto',
          style: TextStyle(color: Colors.blue.shade300, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Trocar'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
            TextButton.icon(
              onPressed: _removeImage,
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Remover'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageSelector() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.placeholderIcon, color: Colors.blue, size: 48),
          const SizedBox(height: 12),
          Text(
            widget.placeholderText,
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.allowedExtensions.map((e) => e.toUpperCase()).join(', ')} até 10MB',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload será feito ao salvar',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 16),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      ),
    );
  }
}


