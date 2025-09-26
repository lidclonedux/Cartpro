// lib/services/api_modules/uploads/image_upload_service.dart

import 'dart:convert';
import 'dart:io';
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

  Future<Map<String, dynamic>> uploadProductImage({
    required File imageFile,
    String? productName,
  }) async {
    try {
      Logger.info('ImageUpload: ======= INICIANDO UPLOAD DE IMAGEM =======');
      Logger.info('ImageUpload: Arquivo: ${imageFile.path}');
      
      if (!await imageFile.exists()) {
        throw Exception('Arquivo não encontrado: ${imageFile.path}');
      }
      
      final fileSize = await imageFile.length();
      Logger.info('ImageUpload: Tamanho: $fileSize bytes');
      
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception("Arquivo muito grande. Tamanho máximo: 10MB");
      }
      
      if (fileSize == 0) {
        throw Exception('Arquivo vazio ou inválido');
      }
      
      final uri = Uri.parse('${ApiClient.baseUrl}/upload/product-image');
      Logger.info('ImageUpload: Endpoint: $uri');
      
      final request = http.MultipartRequest('POST', uri);
      final headers = await _headers.getMultipartHeaders();
      request.headers.addAll(headers);
      
      Logger.info('ImageUpload: Headers aplicados: ${request.headers.keys.join(', ')}');
      
      // CORREÇÃO: Declarar filename fora do try-catch para ter escopo adequado
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(imageFile.path);
      final filename = 'produto_${productName?.replaceAll(' ', '_') ?? 'novo'}_$timestamp.$extension';
      
      Logger.info('ImageUpload: Nome do arquivo: $filename');
      Logger.info('ImageUpload: Extensão detectada: $extension');
      
      late http.MultipartFile multipartFile;
      try {
        final fileStream = http.ByteStream(imageFile.openRead());

        // ==================================================================
        // AQUI ESTÁ A CORREÇÃO PRINCIPAL
        // ==================================================================
        multipartFile = http.MultipartFile(
          'file',
          fileStream,
          fileSize,
          filename: filename,
          // Esta linha informa ao backend o tipo de arquivo correto,
          // resolvendo o erro "application/octet-stream".
          contentType: MediaType('image', extension),
        );
        // ==================================================================
        
        request.files.add(multipartFile);
        Logger.info('ImageUpload: Arquivo adicionado à requisição com Content-Type: image/$extension');
        
      } catch (e) {
        throw Exception('Erro ao preparar arquivo para upload: $e');
      }
      
      if (productName != null && productName.isNotEmpty) {
        request.fields['product_name'] = productName;
      }
      request.fields['context'] = 'ecommerce';
      request.fields['type'] = 'product_image';
      
      Logger.info('ImageUpload: Campos adicionais: ${request.fields}');
      Logger.info('ImageUpload: === ENVIANDO REQUISIÇÃO ===');
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          Logger.error('ImageUpload: Timeout de 90 segundos no upload');
          throw TimeoutException('Upload demorou mais que 90 segundos', const Duration(seconds: 90));
        },
      );
      
      Logger.info('ImageUpload: Resposta recebida, status: ${streamedResponse.statusCode}');
      
      final response = await http.Response.fromStream(streamedResponse);
      
      Logger.info('ImageUpload: Tamanho da resposta: ${response.body.length} caracteres');
      
      if (response.body.isNotEmpty) {
        final preview = response.body.length > 200 ? 
                       '${response.body.substring(0, 200)}...' : 
                       response.body;
        Logger.info('ImageUpload: Preview da resposta: $preview');
      }
      
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        
        Map<String, dynamic> data;
        try {
          data = jsonDecode(response.body);
          Logger.info('ImageUpload: JSON decodificado com sucesso');
        } catch (e) {
          Logger.error('ImageUpload: Erro ao decodificar JSON da resposta');
          throw Exception('Resposta do servidor inválida: não é um JSON válido');
        }
        
        final imageUrl = data['url'] ?? 
                        data['file_url'] ?? 
                        data['cloudinary_url'] ?? 
                        data['secure_url'];
        
        final publicId = data['public_id'] ?? 
                        data['cloudinary_public_id'] ?? 
                        '';
        
        if (imageUrl == null || imageUrl.isEmpty) {
          Logger.error('ImageUpload: Backend não retornou URL da imagem');
          Logger.error('ImageUpload: Dados recebidos: $data');
          throw Exception('Backend retornou sucesso mas sem URL da imagem');
        }
        
        String secureUrl = imageUrl;
        if (secureUrl.startsWith('http://')) {
          secureUrl = secureUrl.replaceFirst('http://', 'https://');
          Logger.info('ImageUpload: URL convertida para HTTPS');
        }
        
        // CORREÇÃO: Agora filename está no escopo correto
        final generatedFilename = filename;
        
        Logger.info('ImageUpload: ✅ UPLOAD REALIZADO COM SUCESSO!');
        Logger.info('ImageUpload: URL final: $secureUrl');
        if (publicId.isNotEmpty) {
          Logger.info('ImageUpload: Public ID: $publicId');
        }
        
        return {
          'success': true,
          'url': secureUrl,
          'public_id': publicId,
          'message': data['message'] ?? 'Upload realizado com sucesso',
          'filename': generatedFilename,
          'size': fileSize,
          'upload_time': DateTime.now().toIso8601String(),
        };
        
      } else {
        Logger.error('ImageUpload: Upload falhou com status ${streamedResponse.statusCode}');
        Logger.error('ImageUpload: Resposta de erro: ${response.body}');
        
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
      
      String userFriendlyMessage = e.toString();
      if (userFriendlyMessage.startsWith('Exception: ')) {
        userFriendlyMessage = userFriendlyMessage.substring(11);
      }
      
      throw Exception('Erro no upload: $userFriendlyMessage');
    }
  }

  /// Extrai a extensão de um caminho de arquivo de forma segura.
  String _getFileExtension(String filePath) {
    // Usa o pacote 'path' para extrair a extensão de forma confiável
    // Ex: path.extension('/caminho/para/imagem.png') retorna '.png'
    String extension = path.extension(filePath).replaceAll('.', '').toLowerCase();
    
    // Se por algum motivo não houver extensão, retorna 'jpg' como padrão seguro.
    if (extension.isEmpty) {
      return 'jpg';
    }
    
    return extension;
  }
}
