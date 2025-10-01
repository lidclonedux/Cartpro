// lib/services/api_modules/uploads/image_upload_service.dart

import 'dart:convert';
// NOVO: Import 'foundation' para usar a constante kIsWeb, que detecta o ambiente (web ou não).
import 'package:flutter/foundation.dart' show kIsWeb;
// NOVO: Import 'html' de forma condicional. Ele só será importado se o ambiente NÃO for 'dart:io' (ou seja, na web).
// Isso evita erros de compilação no mobile.
import 'dart:io' if (dart.library.html) 'dart:html' as html;
// NOVO: Import de Uint8List para trabalhar com dados de arquivo em memória (essencial para a web).
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class ImageUploadService {
  final ApiHeaders _headers;

  ImageUploadService(this._headers);

  // ALTERADO: O método agora aceita parâmetros opcionais para suportar tanto File quanto Uint8List.
  // Isso permite que a UI passe o tipo de dado correto dependendo da plataforma.
  Future<Map<String, dynamic>> uploadProductImage({
    File? imageFile, // Usado no Mobile
    Uint8List? imageBytes, // Usado na Web
    String? filename, // Obrigatório quando imageBytes é usado
    String? productName,
  }) async {
    // NOVO: Validação de entrada para garantir que os parâmetros corretos foram passados.
    if ((imageFile == null && imageBytes == null) || (imageBytes != null && filename == null)) {
      throw ArgumentError('Forneça "imageFile" (para mobile) ou "imageBytes" e "filename" (para web).');
    }

    try {
      Logger.info('ImageUpload: ======= INICIANDO UPLOAD DE IMAGEM =======');

      // NOVO: Lógica condicional para obter os dados do arquivo dependendo da plataforma.
      late int fileSize;
      late String fileExtension;
      late String finalFilename;

      if (kIsWeb) {
        // --- LÓGICA PARA WEB ---
        Logger.info('ImageUpload: Plataforma Web detectada.');
        if (imageBytes == null || filename == null) {
          throw Exception('Erro interno: Dados de imagem web ausentes.');
        }
        fileSize = imageBytes.length;
        fileExtension = _getFileExtension(filename);
        Logger.info('ImageUpload: Arquivo (Web): $filename');
      } else {
        // --- LÓGICA PARA MOBILE (código original) ---
        Logger.info('ImageUpload: Plataforma Mobile detectada.');
        if (imageFile == null) {
          throw Exception('Erro interno: Arquivo de imagem mobile ausente.');
        }
        if (!await imageFile.exists()) {
          throw Exception('Arquivo não encontrado: ${imageFile.path}');
        }
        fileSize = await imageFile.length();
        fileExtension = _getFileExtension(imageFile.path);
        Logger.info('ImageUpload: Arquivo (Mobile): ${imageFile.path}');
      }

      Logger.info('ImageUpload: Tamanho: $fileSize bytes');
      
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception("Arquivo muito grande. Tamanho máximo: 10MB");
      }
      
      if (fileSize == 0) {
        throw Exception('Arquivo vazio ou inválido');
      }

      // Geração do nome do arquivo final para o backend
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeProductName = productName?.replaceAll(' ', '_') ?? 'novo';
      finalFilename = 'produto_${safeProductName}_$timestamp.$fileExtension';

      Logger.info('ImageUpload: Nome do arquivo final: $finalFilename');
      Logger.info('ImageUpload: Extensão detectada: $fileExtension');

      final uri = Uri.parse('${ApiClient.baseUrl}/upload/product-image');
      Logger.info('ImageUpload: Endpoint: $uri');
      
      final request = http.MultipartRequest('POST', uri);
      final headers = await _headers.getMultipartHeaders();
      request.headers.addAll(headers);
      
      Logger.info('ImageUpload: Headers aplicados: ${request.headers.keys.join(', ')}');
      
      // NOVO: Criação do MultipartFile de forma condicional.
      late http.MultipartFile multipartFile;
      if (kIsWeb && imageBytes != null) {
        // --- WEB: Usa MultipartFile.fromBytes ---
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: finalFilename,
          contentType: MediaType('image', fileExtension),
        );
        Logger.info('ImageUpload: Arquivo (Web) adicionado à requisição via fromBytes.');
      } else if (imageFile != null) {
        // --- MOBILE: Usa o stream do arquivo (código original) ---
        final fileStream = http.ByteStream(imageFile.openRead());
        multipartFile = http.MultipartFile(
          'file',
          fileStream,
          fileSize,
          filename: finalFilename,
          contentType: MediaType('image', fileExtension),
        );
        Logger.info('ImageUpload: Arquivo (Mobile) adicionado à requisição via stream.');
      }

      request.files.add(multipartFile);
      
      if (productName != null && productName.isNotEmpty) {
        request.fields['product_name'] = productName;
      }
      request.fields['context'] = 'ecommerce';
      request.fields['type'] = 'product_image';
      
      Logger.info('ImageUpload: Campos adicionais: ${request.fields}');
      Logger.info('ImageUpload: === ENVIANDO REQUISIÇÃO ===');
      
      // O restante do código para enviar a requisição e tratar a resposta permanece o mesmo.
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          Logger.error('ImageUpload: Timeout de 90 segundos no upload');
          throw TimeoutException('Upload demorou mais que 90 segundos', const Duration(seconds: 90));
        },
      );
      
      Logger.info('ImageUpload: Resposta recebida, status: ${streamedResponse.statusCode}');
      
      final response = await http.Response.fromStream(streamedResponse);
      
      // ... (O restante do tratamento de sucesso e erro continua igual ao seu código original)
      // ... (Isso é bom, pois a lógica de negócio não muda)

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        Map<String, dynamic> data = jsonDecode(response.body);
        final imageUrl = data['url'] ?? data['file_url'] ?? data['cloudinary_url'] ?? data['secure_url'];
        
        if (imageUrl == null || imageUrl.isEmpty) {
          throw Exception('Backend retornou sucesso mas sem URL da imagem');
        }

        String secureUrl = imageUrl.toString().replaceFirst('http://', 'https://');
        
        Logger.info('ImageUpload: ✅ UPLOAD REALIZADO COM SUCESSO!');
        
        return {
          'success': true,
          'url': secureUrl,
          'public_id': data['public_id'] ?? '',
          'message': data['message'] ?? 'Upload realizado com sucesso',
          'filename': finalFilename,
          'size': fileSize,
          'upload_time': DateTime.now().toIso8601String(),
        };
        
      } else {
        String errorMessage = 'Falha no upload da imagem';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception('Erro HTTP ${streamedResponse.statusCode}: $errorMessage');
      }
      
    } on TimeoutException catch (e) {
      Logger.error('ImageUpload: Timeout no upload da imagem: $e');
      throw Exception('Timeout: Upload demorou mais que 90 segundos. Tente com uma imagem menor.');
    } on SocketException catch (e) {
      Logger.error('ImageUpload: Erro de conexão no upload', error: e);
      throw Exception('Erro de conexão: Verifique sua internet e tente novamente');
    } on FormatException catch (e) {
      Logger.error('ImageUpload: Erro de formato na resposta', error: e);
      throw Exception('Servidor retornou resposta inválida');
    } catch (e) {
      Logger.error('ImageUpload: Erro geral no upload da imagem do produto', error: e);
      String userFriendlyMessage = e.toString().startsWith('Exception: ') ? e.toString().substring(11) : e.toString();
      throw Exception('Erro no upload: $userFriendlyMessage');
    }
  }

  String _getFileExtension(String filePath) {
    String extension = path.extension(filePath).replaceAll('.', '').toLowerCase();
    if (extension.isEmpty) {
      return 'jpg';
    }
    return extension;
  }
}
