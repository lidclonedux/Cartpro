// lib/screens/admin/tabs/products/dialogs/product_dialog.dart - VERSÃO CORRIGIDA

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

// Models
import '../../../../../models/product.dart';

// Providers
import '../../../../../providers/product_provider.dart';
import '../../../../../providers/auth_provider.dart';

// Widgets
import '../../../../../widgets/image_selector_widget.dart';

// Utils
import '../../../../../utils/logger.dart';

class ProductDialog extends StatefulWidget {
  final Product? product;
  final Function(bool success, String message) onSave;

  const ProductDialog({
    super.key,
    this.product,
    required this.onSave,
  });

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  
  // Variáveis para o fluxo de upload OTIMIZADAS
  String? _uploadedImageUrl;
  String? _uploadedImagePublicId;
  File? _selectedImageFile;
  String? _selectedFileName; // Para web
  Uint8List? _webImageBytes; // Para web
  
  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    
    if (_isEditing) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stockQuantity.toString();
      _selectedCategoryId = widget.product!.categoryId;
      _uploadedImageUrl = widget.product!.imageUrl;
    }

    Logger.info('ProductDialog: ${_isEditing ? 'Editando' : 'Criando'} produto');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductProvider, AuthProvider>(
      builder: (context, productProvider, authProvider, child) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                _isEditing ? Icons.edit : Icons.add,
                color: const Color(0xFF9147FF),
              ),
              const SizedBox(width: 8),
              Text(
                _isEditing ? 'Editar Produto' : 'Novo Produto',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildDescriptionField(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildPriceField()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStockField()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Novo sistema de seleção de imagem
                    _buildImageSelectorSection(),
                    
                    const SizedBox(height: 16),
                    _buildCategoryDropdown(productProvider),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () {
                Logger.info('ProductDialog: Cancelado pelo usuário');
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _saveProduct(productProvider, authProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_isEditing ? 'Atualizar' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // ========= SEÇÃO DE UPLOAD DE IMAGEM COMPLETAMENTE REESCRITA ============
  // =========================================================================



  // ===== UPLOAD WEB FUNCIONAL =====
  Widget _buildWebImageUpload() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: _getWebUploadBackgroundColor(),
        border: Border.all(color: _getWebUploadBorderColor(), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildWebUploadContent(),
    );
  }

  Color _getWebUploadBackgroundColor() {
    if (_uploadedImageUrl != null) return Colors.green.withOpacity(0.1);
    if (_selectedImageFile != null) return Colors.blue.withOpacity(0.1);
    return Colors.grey.withOpacity(0.1);
  }

  Color _getWebUploadBorderColor() {
    if (_uploadedImageUrl != null) return Colors.green;
    if (_selectedImageFile != null) return Colors.blue;
    return Colors.white30;
  }

  Widget _buildWebUploadContent() {
    if (_uploadedImageUrl != null) {
      return _buildWebImagePreview();
    } else if (_selectedImageFile != null) {
      return _buildWebFileSelected();
    } else {
      return _buildWebImageSelector();
    }
  }

  Widget _buildWebImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _uploadedImageUrl!,
            width: double.infinity,
            height: 150,
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
              _buildActionButton(Icons.edit, Colors.blue, _selectImageWeb),
              const SizedBox(width: 4),
              _buildActionButton(Icons.close, Colors.red, () {
                setState(() {
                  _uploadedImageUrl = null;
                  _uploadedImagePublicId = null;
                  _clearSelectedFiles();
                });
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebFileSelected() {
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
              onPressed: _selectImageWeb,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Trocar'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
            TextButton.icon(
              onPressed: _clearSelectedFiles,
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Remover'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebImageSelector() {
    return InkWell(
      onTap: _selectImageWeb,
      borderRadius: BorderRadius.circular(8),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload, color: Colors.blue, size: 48),
          SizedBox(height: 12),
          Text(
            'Clique para Selecionar Imagem',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'JPG, PNG ou WEBP até 5MB',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
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

  // ===== SELEÇÃO DE IMAGEM MOBILE/WEB (UNIFICADO) =====
  Widget _buildImageSelectorSection() {
    return ImageSelectorWidget(
      currentImageUrl: _uploadedImageUrl,
      placeholderText: 'Adicionar foto do produto',
      placeholderIcon: Icons.camera_alt,
      onImageSelected: (imageFile, fileName, webBytes) {
        setState(() {
          _selectedImageFile = imageFile;
          _selectedFileName = fileName;
          _webImageBytes = webBytes;
          if (!_isEditing) {
            _uploadedImageUrl = null;
          }
        });
        _showMessage('Imagem selecionada! Será enviada ao salvar o produto.', Colors.green);
      },
      onImageRemoved: () {
        setState(() {
          _clearSelectedFiles();
          _uploadedImageUrl = null;
          _uploadedImagePublicId = null;
        });
        _showMessage('Imagem removida.', Colors.orange);
      },
    );
  }

  // ===== SELEÇÃO DE IMAGEM WEB CORRIGIDA =====
  Future<void> _selectImageWeb() async {
    if (!kIsWeb) return;

    try {
      Logger.info('ProductDialog: Iniciando seleção de arquivo web');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validações
        if (file.size > 10 * 1024 * 1024) {
          _showMessage("Arquivo muito grande. Tamanho máximo: 10MB", Colors.red);
          return;
        }

        final allowedTypes = ['jpg', 'jpeg', 'png', 'webp'];
        final fileExtension = file.extension?.toLowerCase();
        if (fileExtension == null || !allowedTypes.contains(fileExtension)) {
          _showMessage('Tipo de arquivo não suportado. Use JPG, PNG ou WEBP', Colors.red);
          return;
        }

        if (file.bytes == null) {
          _showMessage('Erro: arquivo sem dados válidos', Colors.red);
          return;
        }

        // CORREÇÃO CRÍTICA: Criar arquivo temporário corretamente
        final tempFile = await _createTempFileFromBytes(file.bytes!, file.name);
        
        setState(() {
          _selectedImageFile = tempFile;
          _selectedFileName = file.name;
          _webImageBytes = file.bytes;
          // Limpar URL anterior se estiver criando novo produto
          if (!_isEditing) {
            _uploadedImageUrl = null;
          }
        });

        Logger.info('ProductDialog: Arquivo web selecionado: ${file.name}');
        _showMessage('Arquivo "${file.name}" selecionado com sucesso!', Colors.green);
      }
    } catch (e) {
      Logger.error('ProductDialog: Erro ao selecionar arquivo na web', error: e);
      _showMessage('Erro ao selecionar arquivo: ${e.toString()}', Colors.red);
    }
  }

  // ===== MÉTODO CORRIGIDO PARA CRIAR ARQUIVO TEMPORÁRIO =====
  Future<File> _createTempFileFromBytes(Uint8List bytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_$filename');
      await tempFile.writeAsBytes(bytes);
      
      Logger.info('ProductDialog: Arquivo temporário criado: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      Logger.error('ProductDialog: Erro ao criar arquivo temporário', error: e);
      throw Exception('Erro ao processar arquivo: $e');
    }
  }

  void _clearSelectedFiles() {
    _selectedImageFile = null;
    _selectedFileName = null;
    _webImageBytes = null;
  }

  // =========================================================================
  // ====================== CAMPOS DO FORMULÁRIO ===========================
  // =========================================================================

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Nome do Produto *',
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF9147FF)),
        ),
        prefixIcon: Icon(Icons.shopping_bag, color: Colors.white54),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'O nome do produto é obrigatório';
        }
        if (value.trim().length < 2) {
          return 'O nome deve ter pelo menos 2 caracteres';
        }
        return null;
      },
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      style: const TextStyle(color: Colors.white),
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Descrição *',
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF9147FF)),
        ),
        prefixIcon: Icon(Icons.description, color: Colors.white54),
        alignLabelWithHint: true,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'A descrição é obrigatória';
        }
        if (value.trim().length < 10) {
          return 'A descrição deve ter pelo menos 10 caracteres';
        }
        return null;
      },
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      style: const TextStyle(color: Colors.white),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Preço *',
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF9147FF)),
        ),
        prefixIcon: Icon(Icons.attach_money, color: Colors.white54),
        prefixText: 'R\$ ',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'O preço é obrigatório';
        }
        final price = double.tryParse(value.replaceAll(',', '.'));
        if (price == null) {
          return 'Preço inválido';
        }
        if (price <= 0) {
          return 'O preço deve ser maior que zero';
        }
        return null;
      },
    );
  }

  Widget _buildStockField() {
    return TextFormField(
      controller: _stockController,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Estoque',
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF9147FF)),
        ),
        prefixIcon: Icon(Icons.inventory, color: Colors.white54),
        helperText: 'Deixe vazio para 0',
        helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          final stock = int.tryParse(value);
          if (stock == null) {
            return 'Valor de estoque inválido';
          }
          if (stock < 0) {
            return 'O estoque não pode ser negativo';
          }
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown(ProductProvider productProvider) {
    if (productProvider.isLoading && productProvider.categories.isEmpty) {
      return const Row(
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 12),
          Text('Carregando categorias...', style: TextStyle(color: Colors.white70)),
        ],
      );
    }

    if (productProvider.categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nenhuma categoria encontrada. Crie categorias primeiro.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      dropdownColor: const Color(0xFF2C2F33),
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Categoria *',
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF9147FF)),
        ),
        prefixIcon: Icon(Icons.category, color: Colors.white54),
      ),
      items: productProvider.categories.map<DropdownMenuItem<String>>((category) {
        return DropdownMenuItem<String>(
          value: category.id,
          child: Row(
            children: [
              Text(category.emoji ?? '📦'),
              const SizedBox(width: 8),
              Expanded(child: Text(category.name)),
            ],
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() => _selectedCategoryId = newValue);
      },
      validator: (value) => value == null ? 'Selecione uma categoria' : null,
    );
  }

  // =========================================================================
  // ====================== MÉTODO DE SALVAR PRODUTO =======================
  // =========================================================================

  Future<void> _saveProduct(ProductProvider productProvider, AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final user = authProvider.currentUser;
    if (user == null) {
      widget.onSave(false, 'Usuário não autenticado');
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _uploadedImageUrl;

      // ✅ CORREÇÃO CRÍTICA: Upload de nova imagem (web e mobile)
      if (_selectedImageFile != null) {
        Logger.info('ProductDialog: Nova imagem selecionada, iniciando upload...');
        
        try {
          final uploadResult = await authProvider.apiService!.uploadProductImage(
            imageFile: _selectedImageFile!,
            productName: _nameController.text.trim(),
          );
          
          finalImageUrl = uploadResult['url'];
          Logger.info('ProductDialog: Upload concluído. URL: $finalImageUrl');
          
          // Limpar arquivo temporário após upload bem-sucedido
          _clearSelectedFiles();
          
        } catch (uploadError) {
          Logger.error('ProductDialog: Erro no upload da imagem', error: uploadError);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Produto será salvo sem imagem. Erro: ${uploadError.toString()}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          finalImageUrl = _uploadedImageUrl; // Mantém URL anterior se houver
        }
      }
      
      // Criar objeto Product
      final productData = Product(
        id: _isEditing ? widget.product!.id : '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.replaceAll(',', '.')),
        stockQuantity: int.tryParse(_stockController.text.trim()) ?? 0,
        imageUrl: finalImageUrl,
        categoryId: _selectedCategoryId!,
        userId: user.uid,
        isActive: widget.product?.isActive ?? true,
        isInStock: (int.tryParse(_stockController.text.trim()) ?? 0) > 0,
        isLowStock: (int.tryParse(_stockController.text.trim()) ?? 0) > 0 && 
                    (int.tryParse(_stockController.text.trim()) ?? 0) < 5,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Salvar no provider
      bool success;
      if (_isEditing) {
        Logger.info('ProductDialog: Atualizando produto "${productData.name}"');
        success = await productProvider.updateProduct(productData);
      } else {
        Logger.info('ProductDialog: Criando novo produto "${productData.name}"');
        success = await productProvider.addProduct(productData);
      }

      if (mounted) {
        Navigator.of(context).pop();
        
        final action = _isEditing ? 'atualizado' : 'criado';
        if (success) {
          widget.onSave(true, 'Produto "${productData.name}" $action com sucesso!');
        } else {
          widget.onSave(false, productProvider.errorMessage ?? 'Erro ao salvar produto');
        }
      }

    } catch (e) {
      Logger.error('ProductDialog: Erro ao salvar produto', error: e);
      
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSave(false, 'Erro: ${e.toString()}');
      }
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: color == Colors.red ? 4 : 3),
      ),
    );
  }
}