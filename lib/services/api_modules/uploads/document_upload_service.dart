// lib/services/api_modules/uploads/document_upload_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class DocumentUploadService {
  final ApiHeaders _headers;

  DocumentUploadService(this._headers);

  Future<Map<String, dynamic>> uploadDocument({
    dynamic file,
    Uint8List? fileBytes,
    String? filename,
    String context = 'business',
    String type = 'document',
    String? description,
  }) async {
    if ((file == null && fileBytes == null) || (fileBytes != null && filename == null)) {
      throw ArgumentError('Forneça "file" (para mobile) ou "fileBytes" e "filename" (para web).');
    }

    try {
      Logger.info('DocumentUpload: Iniciando upload de documento');
      Logger.info('DocumentUpload: Tipo: $type, Contexto: $context');

      late int fileSize;
      late String finalFilename;
      late String fileExtension;

      if (kIsWeb) {
        // --- LÓGICA PARA WEB ---
        Logger.info('DocumentUpload: Plataforma Web detectada.');
        if (fileBytes == null || filename == null) {
          throw Exception('Erro interno: Dados de documento web ausentes.');
        }
        fileSize = fileBytes.length;
        finalFilename = filename;
        fileExtension = _getFileExtension(filename);
        Logger.info('DocumentUpload: Arquivo (Web): $finalFilename');
      } else {
        // --- LÓGICA PARA MOBILE ---
        Logger.info('DocumentUpload: Plataforma Mobile detectada.');
        if (file == null) {
          throw Exception('Erro interno: Arquivo de documento mobile ausente.');
        }
        final mobileFile = file as File;
        if (!await mobileFile.exists()) {
          throw Exception('Arquivo não encontrado: ${mobileFile.path}');
        }
        fileSize = await mobileFile.length();
        finalFilename = path.basename(mobileFile.path);
        fileExtension = _getFileExtension(mobileFile.path);
        Logger.info('DocumentUpload: Arquivo (Mobile): ${mobileFile.path}');
      }

      Logger.info('DocumentUpload: Tamanho do documento: ${fileSize ~/ 1024}KB');

      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Arquivo muito grande. Limite: 50MB');
      }

      final uri = Uri.parse('${ApiClient.baseUrl}/upload/document');
      final request = http.MultipartRequest('POST', uri);
      
      final headers = await _headers.getMultipartHeaders();
      request.headers.addAll(headers);
      
      late http.MultipartFile multipartFile;
      if (kIsWeb && fileBytes != null) {
        // --- WEB: Usa MultipartFile.fromBytes ---
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: finalFilename,
          contentType: _getMediaType(fileExtension),
        );
        Logger.info('DocumentUpload: Arquivo (Web) adicionado à requisição via fromBytes.');
      } else if (file != null) {
        // --- MOBILE: Usa o stream do arquivo ---
        final mobileFile = file as File;
        final fileStream = http.ByteStream(mobileFile.openRead());
        multipartFile = http.MultipartFile(
          'file',
          fileStream,
          fileSize,
          filename: finalFilename,
          contentType: _getMediaType(fileExtension),
        );
        Logger.info('DocumentUpload: Arquivo (Mobile) adicionado à requisição via stream.');
      }

      request.files.add(multipartFile);
      
      request.fields['context'] = context;
      request.fields['type'] = type;
      if (description != null) request.fields['description'] = description;
      
      Logger.info('DocumentUpload: Enviando documento...');
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);
      
      Logger.info('DocumentUpload: Upload documento - Status: ${response.statusCode}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        Logger.info('DocumentUpload: Documento enviado com sucesso');
        return {
          ...data,
          'success': true,
          'filename': finalFilename,
          'size': fileSize,
        };
      } else {
        Logger.error('DocumentUpload: Falha no upload do documento: ${response.body}');
        String errorMessage = 'Falha no upload do documento';
        try {
          final error = jsonDecode(response.body);
          errorMessage = error['error'] ?? error['message'] ?? response.body;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception('Erro HTTP ${response.statusCode}: $errorMessage');
      }
      
    } on TimeoutException {
      Logger.error('DocumentUpload: Timeout no upload do documento');
      throw Exception('Upload demorou mais que 2 minutos. Tente novamente.');
    } catch (e) {
      if (!kIsWeb && e.runtimeType.toString() == 'SocketException') {
        Logger.error('DocumentUpload: Erro de conexão (SocketException)', error: e);
        throw Exception('Erro de conexão: Verifique sua internet e tente novamente.');
      }
      Logger.error('DocumentUpload: Erro durante upload de documento', error: e);
      String userFriendlyMessage = e.toString().startsWith('Exception: ') ? e.toString().substring(11) : e.toString();
      throw Exception('Erro no upload: $userFriendlyMessage');
    }
  }

  String _getFileExtension(String filePath) {
    return path.extension(filePath).replaceAll('.', '').toLowerCase();
  }

  MediaType? _getMediaType(String extension) {
    if (extension.isEmpty) return null;

    switch (extension) {
      case 'pdf': return MediaType('application', 'pdf');
      case 'doc': return MediaType('application', 'msword');
      case 'docx': return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls': return MediaType('application', 'vnd.ms-excel');
      case 'xlsx': return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'jpg': case 'jpeg': return MediaType('image', 'jpeg');
      case 'png': return MediaType('image', 'png');
      default: return null;
    }
  }
}
