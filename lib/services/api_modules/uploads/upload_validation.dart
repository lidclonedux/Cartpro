// lib/services/api_modules/uploads/upload_validation.dart
import 'dart:io';
import '../core/api_exceptions.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class UploadValidation {
  // Constantes de validação
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSize = 50 * 1024 * 1024; // 50MB
  static const int maxProofSize = 5 * 1024 * 1024; // 5MB
  
  static const List<String> allowedImageExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'gif'
  ];
  
  static const List<String> allowedDocumentExtensions = [
    'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'
  ];
  
  static const List<String> allowedProofExtensions = [
    'jpg', 'jpeg', 'png', 'pdf'
  ];

  /// Valida arquivo de imagem de produto
  static Future<void> validateProductImage(File imageFile, {String? productName}) async {
    try {
      Logger.info('UploadValidation: Validando imagem de produto: ${imageFile.path}');
      
      // Validação básica
      await _validateFileExists(imageFile);
      await _validateFileSize(imageFile, maxImageSize, 'imagem');
      _validateImageExtension(imageFile.path);
      
      // Validações específicas para produtos
      if (productName != null && productName.trim().isEmpty) {
        throw ValidationException('Nome do produto não pode estar vazio');
      }
      
      Logger.info('UploadValidation: Imagem de produto validada com sucesso');
      
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação de imagem', error: e);
      if (e is ApiException) rethrow;
      throw UploadException('Erro na validação da imagem: $e');
    }
  }

  /// Valida arquivo de documento
  static Future<void> validateDocument(
    File documentFile, {
    String? context,
    String? type,
    String? description,
  }) async {
    try {
      Logger.info('UploadValidation: Validando documento: ${documentFile.path}');
      
      // Validação básica
      await _validateFileExists(documentFile);
      await _validateFileSize(documentFile, maxDocumentSize, 'documento');
      _validateDocumentExtension(documentFile.path);
      
      // Validações específicas para documentos
      if (context != null && context.trim().isEmpty) {
        throw ValidationException('Contexto do documento é obrigatório');
      }
      
      if (type != null && type.trim().isEmpty) {
        throw ValidationException('Tipo do documento é obrigatório');
      }
      
      Logger.info('UploadValidation: Documento validado com sucesso');
      
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação de documento', error: e);
      if (e is ApiException) rethrow;
      throw UploadException('Erro na validação do documento: $e');
    }
  }

  /// Valida comprovante de pagamento
  static Future<void> validatePaymentProof(
    File proofFile, {
    String? orderId,
    String? description,
  }) async {
    try {
      Logger.info('UploadValidation: Validando comprovante de pagamento: ${proofFile.path}');
      
      // Validação básica
      await _validateFileExists(proofFile);
      await _validateFileSize(proofFile, maxProofSize, 'comprovante');
      _validateProofExtension(proofFile.path);
      
      // Validações específicas para comprovantes
      if (orderId != null && orderId.trim().isEmpty) {
        throw ValidationException('ID do pedido não pode estar vazio');
      }
      
      Logger.info('UploadValidation: Comprovante validado com sucesso');
      
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação de comprovante', error: e);
      if (e is ApiException) rethrow;
      throw UploadException('Erro na validação do comprovante: $e');
    }
  }

  /// Validação básica: arquivo existe
  static Future<void> _validateFileExists(File file) async {
    if (!await file.exists()) {
      throw UploadException('Arquivo não encontrado: ${file.path}');
    }
  }

  /// Validação básica: tamanho do arquivo
  static Future<void> _validateFileSize(File file, int maxSize, String fileType) async {
    final fileSize = await file.length();
    
    if (fileSize == 0) {
      throw UploadException('Arquivo está vazio ou é inválido');
    }
    
    if (fileSize > maxSize) {
      final maxSizeMB = (maxSize / (1024 * 1024)).toStringAsFixed(1);
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw UploadException(
        'Arquivo muito grande para $fileType. Tamanho: ${fileSizeMB}MB, máximo permitido: ${maxSizeMB}MB',
        fileSize: fileSize,
      );
    }
  }

  /// Validação de extensão para imagens
  static void _validateImageExtension(String filePath) {
    final extension = _getFileExtension(filePath);
    
    if (!allowedImageExtensions.contains(extension)) {
      throw UploadException(
        'Extensão de comprovante não permitida: .$extension. Permitidas: ${allowedProofExtensions.join(', ')}',
        fileName: _getFileName(filePath),
      );
    }
  }

  /// Obtém extensão do arquivo
  static String _getFileExtension(String filePath) {
    final parts = filePath.split('.');
    if (parts.length > 1) {
      final extension = parts.last.toLowerCase();
      return extension;
    }
    throw UploadException('Arquivo sem extensão válida: $filePath');
  }

  /// Obtém nome do arquivo
  static String _getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Gera nome único para arquivo
  static String generateUniqueFileName(String originalPath, {String? prefix, String? context}) {
    final extension = _getFileExtension(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final prefixPart = prefix != null ? '${prefix}_' : '';
    final contextPart = context != null ? '${context}_' : '';
    
    return '${prefixPart}${contextPart}$timestamp.$extension';
  }

  /// Valida múltiplos arquivos
  static Future<void> validateMultipleFiles(
    List<File> files,
    String fileType, {
    int? maxFiles,
    int? maxTotalSize,
  }) async {
    try {
      Logger.info('UploadValidation: Validando ${files.length} arquivos de $fileType');
      
      // Validação de quantidade
      if (maxFiles != null && files.length > maxFiles) {
        throw ValidationException(
          'Máximo de $maxFiles arquivos permitidos. Você selecionou ${files.length} arquivos.'
        );
      }
      
      // Validação de tamanho total
      if (maxTotalSize != null) {
        int totalSize = 0;
        for (final file in files) {
          totalSize += await file.length();
        }
        
        if (totalSize > maxTotalSize) {
          final maxTotalMB = (maxTotalSize / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (totalSize / (1024 * 1024)).toStringAsFixed(1);
          throw ValidationException(
            'Tamanho total dos arquivos muito grande: ${totalMB}MB. Máximo permitido: ${maxTotalMB}MB'
          );
        }
      }
      
      // Validação individual
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        try {
          switch (fileType.toLowerCase()) {
            case 'image':
            case 'imagem':
              await validateProductImage(file);
              break;
            case 'document':
            case 'documento':
              await validateDocument(file);
              break;
            case 'proof':
            case 'comprovante':
              await validatePaymentProof(file);
              break;
            default:
              await _validateFileExists(file);
          }
        } catch (e) {
          throw UploadException(
            'Erro no arquivo ${i + 1} (${_getFileName(file.path)}): ${e.toString()}'
          );
        }
      }
      
      Logger.info('UploadValidation: Todos os arquivos validados com sucesso');
      
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação múltipla', error: e);
      rethrow;
    }
  }

  /// Verifica se arquivo é uma imagem válida
  static bool isValidImageFile(String filePath) {
    try {
      final extension = _getFileExtension(filePath);
      return allowedImageExtensions.contains(extension);
    } catch (e) {
      return false;
    }
  }

  /// Verifica se arquivo é um documento válido
  static bool isValidDocumentFile(String filePath) {
    try {
      final extension = _getFileExtension(filePath);
      return allowedDocumentExtensions.contains(extension);
    } catch (e) {
      return false;
    }
  }

  /// Verifica se arquivo é um comprovante válido
  static bool isValidProofFile(String filePath) {
    try {
      final extension = _getFileExtension(filePath);
      return allowedProofExtensions.contains(extension);
    } catch (e) {
      return false;
    }
  }

  /// Calcula tamanho recomendado para redimensionamento
  static Map<String, int> calculateRecommendedSize(File imageFile, int maxFileSize) {
    // Lógica simplificada para recomendar redimensionamento
    // Em implementação real, seria mais sofisticada
    
    if (maxFileSize <= 1024 * 1024) { // <= 1MB
      return {'width': 800, 'height': 600, 'quality': 85};
    } else if (maxFileSize <= 5 * 1024 * 1024) { // <= 5MB
      return {'width': 1200, 'height': 900, 'quality': 90};
    } else {
      return {'width': 1920, 'height': 1080, 'quality': 95};
    }
  }

  /// Obtém informações detalhadas do arquivo
  static Future<Map<String, dynamic>> getFileInfo(File file) async {
    try {
      final fileName = _getFileName(file.path);
      final extension = _getFileExtension(file.path);
      final fileSize = await file.length();
      final lastModified = await file.lastModified();
      
      return {
        'name': fileName,
        'extension': extension,
        'size': fileSize,
        'size_mb': (fileSize / (1024 * 1024)).toStringAsFixed(2),
        'last_modified': lastModified.toIso8601String(),
        'path': file.path,
        'is_image': isValidImageFile(file.path),
        'is_document': isValidDocumentFile(file.path),
        'is_proof': isValidProofFile(file.path),
      };
    } catch (e) {
      Logger.error('UploadValidation: Erro ao obter info do arquivo', error: e);
      return {'error': e.toString()};
    }
  }

  /// Sanitiza nome do arquivo removendo caracteres inválidos
  static String sanitizeFileName(String fileName) {
    // Remove ou substitui caracteres problemáticos
    return fileName
        .replaceAll(RegExp(r'[^\w\s\-_\.]'), '') // Remove caracteres especiais
        .replaceAll(RegExp(r'\s+'), '_') // Substitui espaços por underscore
        .replaceAll(RegExp(r'_{2,}'), '_') // Remove underscores duplos
        .trim();
  }

  /// Verifica se o nome do arquivo já existe (para evitar duplicatas)
  static bool isDuplicateFileName(String fileName, List<String> existingFileNames) {
    final sanitized = sanitizeFileName(fileName);
    return existingFileNames.any((existing) => 
        sanitizeFileName(existing).toLowerCase() == sanitized.toLowerCase());
  }

  /// Gera mensagem de erro amigável baseada no tipo de validação
  static String getValidationErrorMessage(UploadException exception) {
    final message = exception.message;
    
    if (message.contains('muito grande')) {
      return 'O arquivo selecionado é muito grande. Tente com um arquivo menor ou comprima a imagem.';
    }
    
    if (message.contains('extensão') || message.contains('permitida')) {
      return 'Tipo de arquivo não suportado. Selecione um arquivo com extensão válida.';
    }
    
    if (message.contains('vazio')) {
      return 'O arquivo selecionado está vazio ou corrompido. Tente com outro arquivo.';
    }
    
    if (message.contains('não encontrado')) {
      return 'Arquivo não encontrado. Tente selecionar o arquivo novamente.';
    }
    
    return 'Erro na validação do arquivo. Verifique se o arquivo é válido e tente novamente.';
  }
} de imagem não permitida: .$extension. Permitidas: ${allowedImageExtensions.join(', ')}',
        fileName: _getFileName(filePath),
      );
    }
  }

  /// Validação de extensão para documentos
  static void _validateDocumentExtension(String filePath) {
    final extension = _getFileExtension(filePath);
    
    if (!allowedDocumentExtensions.contains(extension)) {
      throw UploadException(
        'Extensão de documento não permitida: .$extension. Permitidas: ${allowedDocumentExtensions.join(', ')}',
        fileName: _getFileName(filePath),
      );
    }
  }

  /// Validação de extensão para comprovantes
  static void _validateProofExtension(String filePath) {
    final extension = _getFileExtension(filePath);
    
    if (!allowedProofExtensions.contains(extension)) {
      throw UploadException(
        'Extensão