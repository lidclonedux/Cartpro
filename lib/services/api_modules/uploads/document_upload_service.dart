// lib/services/api_modules/uploads/document_upload_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class DocumentUploadService {
  final ApiHeaders _headers;

  DocumentUploadService(this._headers);

  Future<Map<String, dynamic>> uploadDocument({
    required File file,
    String context = 'business',
    String type = 'document',
    String? description,
  }) async {
    try {
      Logger.info('DocumentUpload: Iniciando upload de documento');
      Logger.info('DocumentUpload: Tipo: $type, Contexto: $context');
      
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado');
      }

      final fileSize = await file.length();
      Logger.info('DocumentUpload: Tamanho do documento: ${fileSize ~/ 1024}KB');

      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Arquivo muito grande. Limite: 50MB');
      }
      
      final uri = Uri.parse('${ApiClient.baseUrl}/upload/document');
      final request = http.MultipartRequest('POST', uri);
      
      final headers = await _headers.getMultipartHeaders();
      request.headers.addAll(headers);
      
      final fileStream = http.ByteStream(file.openRead());
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileSize,
        filename: file.path.split('/').last,
      );
      request.files.add(multipartFile);
      
      request.fields['context'] = context;
      request.fields['type'] = type;
      if (description != null) request.fields['description'] = description;
      
      Logger.info('DocumentUpload: Enviando documento...');
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      Logger.info('DocumentUpload: Upload documento - Status: ${streamedResponse.statusCode}');
      
      if (streamedResponse.statusCode == 201) {
        final data = jsonDecode(response.body);
        Logger.info('DocumentUpload: Documento enviado com sucesso');
        return data;
      } else {
        Logger.error('DocumentUpload: Falha no upload do documento: ${response.body}');
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha no upload: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha no upload: ${response.body}');
        }
      }
      
    } catch (e) {
      Logger.error('DocumentUpload: Erro durante upload de documento', error: e);
      if (e is TimeoutException) {
        throw Exception('Upload demorou mais que 2 minutos');
      }
      throw Exception('Erro no upload: ${e.toString()}');
    }
  }
}