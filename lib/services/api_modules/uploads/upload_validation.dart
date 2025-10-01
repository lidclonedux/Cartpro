// lib/services/api_modules/uploads/upload_validation.dart

import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:path/path.dart' as path;
import '../core/api_exceptions.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class UploadValidation {
  // Constantes de validação
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSize = 50 * 1024 * 1024; // 50MB
  static const int maxProofSize = 5 * 1024 * 1024; // 5MB
  
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  static const List<String> allowedDocumentExtensions = ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'];
  static const List<String> allowedProofExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

  // --- MÉTODOS DE VALIDAÇÃO PRINCIPAIS ---

  /// Valida arquivo de imagem de produto (híbrido)
  static Future<void> validateProductImage({
    dynamic file,
    Uint8List? bytes,
    String? filename,
    String? productName,
  }) async {
    try {
      final fileInfo = await _getFileInfo(file: file, bytes: bytes, filename: filename);
      Logger.info('UploadValidation: Validando imagem de produto: ${fileInfo['filename']}');
      
      _validateFileSize(fileInfo['size'] as int, maxImageSize, 'imagem');
      _validateImageExtension(fileInfo['filename'] as String);
      
      if (productName != null && productName.trim().isEmpty) {
        throw ValidationException('Nome do produto não pode estar vazio');
      }
      
      Logger.info('UploadValidation: Imagem de produto validada com sucesso');
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação de imagem', error: e);
      if (e is ApiException) rethrow;
      throw UploadException('Erro na validação da imagem: ${e.toString()}');
    }
  }

  /// Valida arquivo de documento (híbrido)
  static Future<void> validateDocument({
    dynamic file,
    Uint8List? bytes,
    String? filename,
    String? context,
    String? type,
  }) async {
    try {
      final fileInfo = await _getFileInfo(file: file, bytes: bytes, filename: filename);
      Logger.info('UploadValidation: Validando documento: ${fileInfo['filename']}');
      
      _validateFileSize(fileInfo['size'] as int, maxDocumentSize, 'documento');
      _validateDocumentExtension(fileInfo['filename'] as String);
      
      if (context != null && context.trim().isEmpty) throw ValidationException('Contexto do documento é obrigatório');
      if (type != null && type.trim().isEmpty) throw ValidationException('Tipo do documento é obrigatório');
      
      Logger.info('UploadValidation: Documento validado com sucesso');
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação de documento', error: e);
      if (e is ApiException) rethrow;
      throw UploadException('Erro na validação do documento: ${e.toString()}');
    }
  }

  /// Valida comprovante de pagamento (híbrido)
  static Future<void> validatePaymentProof({
    dynamic file,
    Uint8List? bytes,
    String? filename,
    String? orderId,
  }) async {
    try {
      final fileInfo = await _getFileInfo(file: file, bytes: bytes, filename: filename);
      Logger.info('UploadValidation: Validando comprovante: ${fileInfo['filename']}');
      
      _validateFileSize(fileInfo['size'] as int, maxProofSize, 'comprovante');
      _validateProofExtension(fileInfo['filename'] as String);
      
      if (orderId != null && orderId.trim().isEmpty) {
        throw ValidationException('ID do pedido não pode estar vazio');
      }
      
      Logger.info('UploadValidation: Comprovante validado com sucesso');
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação de comprovante', error: e);
      if (e is ApiException) rethrow;
      throw UploadException('Erro na validação do comprovante: ${e.toString()}');
    }
  }

  // --- MÉTODOS DE VALIDAÇÃO INTERNOS ---

  /// Validação de tamanho do arquivo
  static void _validateFileSize(int fileSize, int maxSize, String fileType) {
    if (fileSize == 0) throw UploadException('Arquivo está vazio ou é inválido');
    if (fileSize > maxSize) {
      final maxSizeMB = (maxSize / (1024 * 1024)).toStringAsFixed(1);
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      throw UploadException('Arquivo muito grande para $fileType. Tamanho: ${fileSizeMB}MB, máximo: ${maxSizeMB}MB', fileSize: fileSize);
    }
  }

  /// Validação de extensão para imagens
  static void _validateImageExtension(String filename) {
    final extension = _getFileExtension(filename);
    if (!allowedImageExtensions.contains(extension)) throw UploadException('Extensão de imagem não permitida: .$extension. Permitidas: ${allowedImageExtensions.join(', ')}', fileName: filename);
  }

  /// Validação de extensão para documentos
  static void _validateDocumentExtension(String filename) {
    final extension = _getFileExtension(filename);
    if (!allowedDocumentExtensions.contains(extension)) throw UploadException('Extensão de documento não permitida: .$extension. Permitidas: ${allowedDocumentExtensions.join(', ')}', fileName: filename);
  }

  /// Validação de extensão para comprovantes
  static void _validateProofExtension(String filename) {
    final extension = _getFileExtension(filename);
    if (!allowedProofExtensions.contains(extension)) throw UploadException('Extensão de comprovante não permitida: .$extension. Permitidas: ${allowedProofExtensions.join(', ')}', fileName: filename);
  }

  // --- MÉTODOS AUXILIARES ---

  static String _getFileExtension(String filename) {
    final extension = path.extension(filename).replaceAll('.', '').toLowerCase();
    if (extension.isEmpty) throw UploadException('Arquivo sem extensão válida: $filename');
    return extension;
  }

  static String _getFileName(String filePath) => path.basename(filePath);

  static String generateUniqueFileName(String originalFileName, {String? prefix, String? context}) {
    final extension = _getFileExtension(originalFileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefixPart = prefix != null ? '${prefix}_' : '';
    final contextPart = context != null ? '${context}_' : '';
    return '${prefixPart}${contextPart}$timestamp.$extension';
  }

  /// Valida múltiplos arquivos (híbrido)
  static Future<void> validateMultipleFiles({
    List<dynamic>? files,
    List<Map<String, dynamic>>? webFiles,
    required String fileType,
    int? maxFiles,
    int? maxTotalSize,
  }) async {
    try {
      final int fileCount = (files?.length ?? 0) + (webFiles?.length ?? 0);
      Logger.info('UploadValidation: Validando $fileCount arquivos de $fileType');

      if (maxFiles != null && fileCount > maxFiles) {
        throw ValidationException('Máximo de $maxFiles arquivos permitidos. Você selecionou $fileCount.');
      }

      if (maxTotalSize != null) {
        int totalSize = 0;
        if (files != null) {
          for (final file in files) {
            if (!kIsWeb) {
              final mobileFile = file as File;
              totalSize += await mobileFile.length();
            }
          }
        }
        if (webFiles != null) {
          for (final webFile in webFiles) {
            totalSize += (webFile['bytes'] as Uint8List).length;
          }
        }
        if (totalSize > maxTotalSize) {
          final maxTotalMB = (maxTotalSize / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (totalSize / (1024 * 1024)).toStringAsFixed(1);
          throw ValidationException('Tamanho total dos arquivos (${totalMB}MB) excede o limite de ${maxTotalMB}MB.');
        }
      }

      // Validação individual
      if (files != null) {
        for (int i = 0; i < files.length; i++) {
          await _validateSingleFile(fileType: fileType, file: files[i], index: i);
        }
      }
      if (webFiles != null) {
        for (int i = 0; i < webFiles.length; i++) {
          await _validateSingleFile(fileType: fileType, bytes: webFiles[i]['bytes'], filename: webFiles[i]['name'], index: i);
        }
      }
      
      Logger.info('UploadValidation: Todos os $fileCount arquivos validados com sucesso.');
    } catch (e) {
      Logger.error('UploadValidation: Erro na validação múltipla', error: e);
      rethrow;
    }
  }

  // Método auxiliar para a validação múltipla
  static Future<void> _validateSingleFile({required String fileType, dynamic file, Uint8List? bytes, String? filename, required int index}) async {
    try {
      switch (fileType.toLowerCase()) {
        case 'image':
        case 'imagem':
          await validateProductImage(file: file, bytes: bytes, filename: filename);
          break;
        case 'document':
        case 'documento':
          await validateDocument(file: file, bytes: bytes, filename: filename);
          break;
        case 'proof':
        case 'comprovante':
          await validatePaymentProof(file: file, bytes: bytes, filename: filename);
          break;
      }
    } catch (e) {
      String name = 'desconhecido';
      if (filename != null) {
        name = filename;
      } else if (file != null && !kIsWeb) {
        final mobileFile = file as File;
        name = _getFileName(mobileFile.path);
      }
      throw UploadException('Erro no arquivo ${index + 1} ($name): ${e.toString()}');
    }
  }

  static bool isValidImageFile(String filename) {
    try { return allowedImageExtensions.contains(_getFileExtension(filename)); } catch (e) { return false; }
  }

  static bool isValidDocumentFile(String filename) {
    try { return allowedDocumentExtensions.contains(_getFileExtension(filename)); } catch (e) { return false; }
  }

  static bool isValidProofFile(String filename) {
    try { return allowedProofExtensions.contains(_getFileExtension(filename)); } catch (e) { return false; }
  }

  /// Calcula tamanho recomendado para redimensionamento
  static Map<String, int> calculateRecommendedSize({int? fileSize, int? maxFileSize}) {
    final size = fileSize ?? maxImageSize;
    final maxSize = maxFileSize ?? maxImageSize;
    if (size <= maxSize * 0.1) return {'width': 800, 'height': 600, 'quality': 85};
    if (size <= maxSize * 0.5) return {'width': 1200, 'height': 900, 'quality': 90};
    return {'width': 1920, 'height': 1080, 'quality': 95};
  }

  /// Obtém informações detalhadas do arquivo (híbrido)
  static Future<Map<String, dynamic>> _getFileInfo({dynamic file, Uint8List? bytes, String? filename}) async {
    try {
      if (kIsWeb) {
        if (bytes == null || filename == null) throw ArgumentError('Para web, "bytes" e "filename" são necessários.');
        return {
          'filename': filename,
          'name': filename,
          'extension': _getFileExtension(filename),
          'size': bytes.length,
          'size_mb': (bytes.length / (1024 * 1024)).toStringAsFixed(2),
          'is_image': isValidImageFile(filename),
          'is_document': isValidDocumentFile(filename),
          'is_proof': isValidProofFile(filename),
        };
      } else {
        if (file == null) throw ArgumentError('Para mobile, "file" é necessário.');
        final mobileFile = file as File;
        if (!await mobileFile.exists()) throw UploadException('Arquivo não encontrado: ${mobileFile.path}');
        final fileSize = await mobileFile.length();
        final fileName = _getFileName(mobileFile.path);
        return {
          'filename': fileName,
          'name': fileName,
          'extension': _getFileExtension(mobileFile.path),
          'size': fileSize,
          'size_mb': (fileSize / (1024 * 1024)).toStringAsFixed(2),
          'last_modified': (await mobileFile.lastModified()).toIso8601String(),
          'path': mobileFile.path,
          'is_image': isValidImageFile(mobileFile.path),
          'is_document': isValidDocumentFile(mobileFile.path),
          'is_proof': isValidProofFile(mobileFile.path),
        };
      }
    } catch (e) {
      Logger.error('UploadValidation: Erro ao obter info do arquivo', error: e);
      return {'error': e.toString()};
    }
  }

  /// Obtém informações detalhadas do arquivo (público - híbrido)
  static Future<Map<String, dynamic>> getFileInfo({dynamic file, Uint8List? bytes, String? filename}) async {
    return _getFileInfo(file: file, bytes: bytes, filename: filename);
  }

  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^\w\s\-_\.]'), '').replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'_{2,}'), '_').trim();
  }

  static bool isDuplicateFileName(String fileName, List<String> existingFileNames) {
    final sanitized = sanitizeFileName(fileName);
    return existingFileNames.any((existing) => sanitizeFileName(existing).toLowerCase() == sanitized.toLowerCase());
  }

  static String getValidationErrorMessage(UploadException exception) {
    final message = exception.message;
    if (message.contains('muito grande')) return 'O arquivo selecionado é muito grande. Tente com um arquivo menor ou comprima a imagem.';
    if (message.contains('extensão') || message.contains('permitida')) return 'Tipo de arquivo não suportado. Selecione um arquivo com extensão válida.';
    if (message.contains('vazio')) return 'O arquivo selecionado está vazio ou corrompido. Tente com outro arquivo.';
    if (message.contains('não encontrado')) return 'Arquivo não encontrado. Tente selecionar o arquivo novamente.';
    return 'Erro na validação do arquivo. Verifique se o arquivo é válido e tente novamente.';
  }
}
