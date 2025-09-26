// lib/services/api_modules/products/product_validation.dart
import '../core/api_exceptions.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class ProductValidation {
  // Constantes de validação
  static const int minNameLength = 3;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 1000;
  static const double minPrice = 0.01;
  static const double maxPrice = 999999.99;
  static const int minStock = 0;
  static const int maxStock = 999999;

  /// Valida dados completos de produto para criação/atualização
  static void validateProductData(Map<String, dynamic> productData, {bool isUpdate = false}) {
    try {
      Logger.info('ProductValidation: Validando dados do produto ${isUpdate ? '(atualização)' : '(criação)'}');
      
      // Validações obrigatórias para criação
      if (!isUpdate) {
        _validateRequiredFields(productData);
      }
      
      // Validações individuais (aplicadas se o campo estiver presente)
      if (productData.containsKey('name')) {
        validateProductName(productData['name']);
      }
      
      if (productData.containsKey('description')) {
        validateProductDescription(productData['description']);
      }
      
      if (productData.containsKey('price')) {
        validateProductPrice(productData['price']);
      }
      
      if (productData.containsKey('stock')) {
        validateProductStock(productData['stock']);
      }
      
      if (productData.containsKey('category_id')) {
        validateCategoryId(productData['category_id']);
      }
      
      if (productData.containsKey('images') && productData['images'] != null) {
        validateProductImages(productData['images']);
      }
      
      // Validações específicas de negócio
      _validateBusinessRules(productData);
      
      Logger.info('ProductValidation: Dados do produto validados com sucesso');
      
    } catch (e) {
      Logger.error('ProductValidation: Erro na validação de produto', error: e);
      if (e is ApiException) rethrow;
      throw ValidationException('Erro na validação do produto: $e');
    }
  }

  /// Valida nome do produto
  static void validateProductName(dynamic name) {
    if (name == null) {
      throw ValidationException('Nome do produto é obrigatório', field: 'name');
    }
    
    final nameStr = name.toString().trim();
    
    if (nameStr.isEmpty) {
      throw ValidationException('Nome do produto não pode estar vazio', field: 'name');
    }
    
    if (nameStr.length < minNameLength) {
      throw ValidationException(
        'Nome do produto deve ter pelo menos $minNameLength caracteres', 
        field: 'name'
      );
    }
    
    if (nameStr.length > maxNameLength) {
      throw ValidationException(
        'Nome do produto não pode ter mais que $maxNameLength caracteres', 
        field: 'name'
      );
    }
    
    // Verifica caracteres inválidos
    if (nameStr.contains(RegExp(r'[<>{}[\]\\\/]'))) {
      throw ValidationException(
        'Nome do produto contém caracteres inválidos', 
        field: 'name'
      );
    }
  }

  /// Valida descrição do produto
  static void validateProductDescription(dynamic description) {
    if (description == null) return; // Descrição é opcional
    
    final descStr = description.toString().trim();
    
    if (descStr.length > maxDescriptionLength) {
      throw ValidationException(
        'Descrição não pode ter mais que $maxDescriptionLength caracteres',
        field: 'description'
      );
    }
  }

  /// Valida preço do produto
  static void validateProductPrice(dynamic price) {
    if (price == null) {
      throw ValidationException('Preço do produto é obrigatório', field: 'price');
    }
    
    double priceValue;
    
    try {
      if (price is String) {
        priceValue = double.parse(price);
      } else if (price is num) {
        priceValue = price.toDouble();
      } else {
        throw ValidationException(
          'Preço deve ser um número válido',
          field: 'price'
        );
      }
    } catch (e) {
      throw ValidationException(
        'Preço deve ser um número válido',
        field: 'price'
      );
    }
    
    if (priceValue < minPrice) {
      throw ValidationException(
        'Preço deve ser maior que R\$ ${minPrice.toStringAsFixed(2)}',
        field: 'price'
      );
    }
    
    if (priceValue > maxPrice) {
      throw ValidationException(
        'Preço não pode ser maior que R\$ ${maxPrice.toStringAsFixed(2)}',
        field: 'price'
      );
    }
    
    // Verifica se tem mais de 2 casas decimais
    if ((priceValue * 100) % 1 != 0) {
      throw ValidationException(
        'Preço não pode ter mais que 2 casas decimais',
        field: 'price'
      );
    }
  }

  /// Valida estoque do produto
  static void validateProductStock(dynamic stock) {
    if (stock == null) return; // Estoque pode ser opcional, padrão 0
    
    int stockValue;
    
    try {
      if (stock is String) {
        stockValue = int.parse(stock);
      } else if (stock is num) {
        stockValue = stock.toInt();
      } else {
        throw ValidationException(
          'Estoque deve ser um número inteiro',
          field: 'stock'
        );
      }
    } catch (e) {
      throw ValidationException(
        'Estoque deve ser um número inteiro válido',
        field: 'stock'
      );
    }
    
    if (stockValue < minStock) {
      throw ValidationException(
        'Estoque não pode ser negativo',
        field: 'stock'
      );
    }
    
    if (stockValue > maxStock) {
      throw ValidationException(
        'Estoque não pode ser maior que $maxStock',
        field: 'stock'
      );
    }
  }

  /// Valida ID da categoria
  static void validateCategoryId(dynamic categoryId) {
    if (categoryId == null) return; // Categoria pode ser opcional
    
    final categoryIdStr = categoryId.toString().trim();
    
    if (categoryIdStr.isEmpty || categoryIdStr == 'null' || categoryIdStr == 'None') {
      throw ValidationException(
        'ID da categoria inválido',
        field: 'category_id'
      );
    }
    
    // Validação para ObjectId do MongoDB (24 caracteres hex)
    if (categoryIdStr.length == 24) {
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(categoryIdStr)) {
        throw ValidationException(
          'Formato de ID da categoria inválido',
          field: 'category_id'
        );
      }
    } else if (categoryIdStr.length < 8) {
      // Para outros formatos de ID, mínimo 8 caracteres
      throw ValidationException(
        'ID da categoria muito curto',
        field: 'category_id'
      );
    }
  }

  /// Valida lista de imagens do produto
  static void validateProductImages(dynamic images) {
    if (images == null) return; // Imagens são opcionais
    
    if (images is! List) {
      throw ValidationException(
        'Imagens devem ser uma lista',
        field: 'images'
      );
    }
    
    final imagesList = images as List;
    
    if (imagesList.length > 10) {
      throw ValidationException(
        'Máximo de 10 imagens por produto',
        field: 'images'
      );
    }
    
    for (int i = 0; i < imagesList.length; i++) {
      final image = imagesList[i];
      
      if (image == null) {
        throw ValidationException(
          'Imagem ${i + 1} é nula',
          field: 'images'
        );
      }
      
      // Se é string, deve ser URL válida
      if (image is String) {
        _validateImageUrl(image, i + 1);
      } else if (image is Map) {
        _validateImageObject(image, i + 1);
      } else {
        throw ValidationException(
          'Formato de imagem ${i + 1} inválido',
          field: 'images'
        );
      }
    }
  }

  /// Valida URL de imagem
  static void _validateImageUrl(String imageUrl, int index) {
    final trimmedUrl = imageUrl.trim();
    
    if (trimmedUrl.isEmpty) {
      throw ValidationException(
        'URL da imagem $index está vazia',
        field: 'images'
      );
    }
    
    if (!Uri.tryParse(trimmedUrl)?.hasAbsolutePath == true) {
      throw ValidationException(
        'URL da imagem $index é inválida',
        field: 'images'
      );
    }
    
    // Verifica se é HTTPS (recomendado para produção)
    if (!trimmedUrl.startsWith('https://')) {
      Logger.warning('ProductValidation: Imagem $index não usa HTTPS: $trimmedUrl');
    }
  }

  /// Valida objeto de imagem
  static void _validateImageObject(Map image, int index) {
    if (!image.containsKey('url') || image['url'] == null) {
      throw ValidationException(
        'Imagem $index deve conter URL',
        field: 'images'
      );
    }
    
    _validateImageUrl(image['url'].toString(), index);
    
    // Validações opcionais para outros campos do objeto imagem
    if (image.containsKey('alt_text') && image['alt_text'] != null) {
      final altText = image['alt_text'].toString();
      if (altText.length > 200) {
        throw ValidationException(
          'Texto alternativo da imagem $index muito longo (máximo 200 caracteres)',
          field: 'images'
        );
      }
    }
  }

  /// Valida campos obrigatórios para criação
  static void _validateRequiredFields(Map<String, dynamic> productData) {
    final requiredFields = ['name', 'price'];
    final missingFields = <String>[];
    
    for (final field in requiredFields) {
      if (!productData.containsKey(field) || productData[field] == null) {
        missingFields.add(field);
      }
    }
    
    if (missingFields.isNotEmpty) {
      throw ValidationException(
        'Campos obrigatórios não preenchidos: ${missingFields.join(', ')}',
        validationErrors: {
          'missing_fields': missingFields,
        }
      );
    }
  }

  /// Valida regras de negócio específicas
  static void _validateBusinessRules(Map<String, dynamic> productData) {
    // Regra: Produto com preço alto deve ter descrição
    if (productData.containsKey('price')) {
      final price = _parseDouble(productData['price']);
      if (price != null && price > 1000.0) {
        final description = productData['description']?.toString()?.trim();
        if (description == null || description.isEmpty || description.length < 50) {
          Logger.warning('ProductValidation: Produto caro sem descrição adequada');
        }
      }
    }
    
    // Regra: Verificar consistência de estoque
    if (productData.containsKey('stock')) {
      final stock = _parseInt(productData['stock']);
      if (stock != null && stock == 0) {
        Logger.info('ProductValidation: Produto sem estoque sendo criado/atualizado');
      }
    }
  }

  /// Valida ID de produto para operações
  static void validateProductId(dynamic productId) {
    if (productId == null) {
      throw ValidationException('ID do produto é obrigatório');
    }
    
    final idStr = productId.toString().trim();
    
    if (idStr.isEmpty || idStr == 'null' || idStr == 'None') {
      throw ValidationException('ID do produto inválido');
    }
    
    // Para ObjectId do MongoDB
    if (idStr.length == 24) {
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(idStr)) {
        throw ValidationException('Formato de ID do produto inválido');
      }
    } else if (idStr.length < 8) {
      throw ValidationException('ID do produto muito curto');
    }
  }

  /// Valida dados vindos da API (para limpeza)
  static Map<String, dynamic> validateAndCleanApiProduct(Map<String, dynamic> rawProduct) {
    try {
      final cleanProduct = Map<String, dynamic>.from(rawProduct);
      
      // Limpa e valida ID
      final rawId = cleanProduct['id'] ?? cleanProduct['_id'];
      if (!_isValidProductId(rawId)) {
        throw DataException('Produto com ID inválido rejeitado', field: 'id');
      }
      cleanProduct['id'] = rawId.toString();
      
      // Limpa e valida nome
      final name = cleanProduct['name']?.toString()?.trim();
      if (name == null || name.isEmpty || name == 'null') {
        throw DataException('Produto sem nome válido rejeitado', field: 'name');
      }
      cleanProduct['name'] = name;
      
      // Limpa e valida preço
      final price = _parseDouble(cleanProduct['price']);
      if (price == null || price < 0) {
        throw DataException('Produto com preço inválido rejeitado: $name', field: 'price');
      }
      cleanProduct['price'] = price;
      
      // Limpa campos opcionais
      cleanProduct['description'] = cleanProduct['description']?.toString()?.trim() ?? '';
      cleanProduct['stock'] = _parseInt(cleanProduct['stock']) ?? 0;
      
      // Limpa categoria
      if (cleanProduct['category_id'] != null) {
        final categoryId = cleanProduct['category_id'].toString().trim();
        if (categoryId.isNotEmpty && categoryId != 'null') {
          cleanProduct['category_id'] = categoryId;
        } else {
          cleanProduct.remove('category_id');
        }
      }
      
      return cleanProduct;
      
    } catch (e) {
      Logger.error('ProductValidation: Erro ao limpar produto da API', error: e);
      rethrow;
    }
  }

  /// Utilitários privados
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  static bool _isValidProductId(dynamic id) {
    if (id == null) return false;
    
    final idString = id.toString().trim();
    
    // Lista de valores inválidos
    const invalidValues = ['', 'None', 'null', 'undefined', 'NULL', '0'];
    if (invalidValues.contains(idString)) return false;
    
    // ObjectId MongoDB (24 chars hex)
    if (idString.length == 24 && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(idString)) {
      return true;
    }
    
    // Outros IDs válidos (mínimo 8 chars, não só números)
    if (idString.length >= 8 && !RegExp(r'^[0-9]+$').hasMatch(idString)) {
      return true;
    }
    
    return false;
  }
}