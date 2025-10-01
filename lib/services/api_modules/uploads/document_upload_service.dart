// lib/services/api_modules/uploads/document_upload_service.dart

import 'dart:convert';
// NOVO: Import 'foundation' para usar a constante kIsWeb.
import 'package:flutter/foundation.dart' show kIsWeb;
// NOVO: Import condicional para evitar erros de compilação.
import 'dart:io' if (dart.library.html) 'dart:html' as html;
// NOVO: Import de Uint8List para dados de arquivo em memória (web).
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

  // ALTERADO: O método agora aceita parâmetros opcionais para suportar File (mobile) e Uint8List (web).
  Future<Map<String, dynamic>> uploadDocument({
    File? file, // Usado no Mobile
    Uint8List? fileBytes, // Usado na Web
    String? filename, // Obrigatório quando fileBytes é usado
    String context = 'business',
    String type = 'document',
    String? description,
  }) async {
    // NOVO: Validação para garantir que os parâmetros corretos foram passados.
    if ((file == null && fileBytes == null) || (fileBytes != null && filename == null)) {
      throw ArgumentError('Forneça "file" (para mobile) ou "fileBytes" e "filename" (para web).');
    }

    try {
      Logger.info('DocumentUpload: Iniciando upload de documento');
      Logger.info('DocumentUpload: Tipo: $type, Contexto: $context');

      // NOVO: Lógica condicional para obter os dados do arquivo.
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
        finalFilename = filename; // Na web, já temos o nome original.
        fileExtension = _getFileExtension(filename);
        Logger.info('DocumentUpload: Arquivo (Web): $finalFilename');
      } else {
        // --- LÓGICA PARA MOBILE (código original) ---
        Logger.info('DocumentUpload: Plataforma Mobile detectada.');
        if (file == null) {
          throw Exception('Erro interno: Arquivo de documento mobile ausente.');
        }
        if (!await file.exists()) {
          throw Exception('Arquivo não encontrado: ${file.path}');
        }
        fileSize = await file.length();
        finalFilename = file.path.split('/').last;
        fileExtension = _getFileExtension(file.path);
        Logger.info('DocumentUpload: Arquivo (Mobile): ${file.path}');
      }

      Logger.info('DocumentUpload: Tamanho do documento: ${fileSize ~/ 1024}KB');

      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Arquivo muito grande. Limite: 50MB');
      }

      final uri = Uri.parse('${ApiClient.baseUrl}/upload/document');
      final request = http.MultipartRequest('POST', uri);
      
      final headers = await _headers.getMultipartHeaders();
      request.headers.addAll(headers);
      
      // NOVO: Criação do MultipartFile de forma condicional.
      late http.MultipartFile multipartFile;
      if (kIsWeb && fileBytes != null) {
        // --- WEB: Usa MultipartFile.fromBytes ---
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: finalFilename,
          // Adiciona o tipo de conteúdo para ajudar o backend.
          contentType: _getMediaType(fileExtension),
        );
        Logger.info('DocumentUpload: Arquivo (Web) adicionado à requisição via fromBytes.');
      } else if (file != null) {
        // --- MOBILE: Usa o stream do arquivo (código original) ---
        final fileStream = http.ByteStream(file.openRead());
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
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      Logger.info('DocumentUpload: Upload documento - Status: ${streamedResponse.statusCode}');
      
      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final data = jsonDecode(response.body);
        Logger.info('DocumentUpload: Documento enviado com sucesso');
        // NOVO: Retorna um objeto mais completo, similar ao ImageUploadService.
        return {
          ...data, // Inclui todos os dados originais da resposta do backend.
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
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception('Erro HTTP ${streamedResponse.statusCode}: $errorMessage');
      }
      
    } on TimeoutException {
      Logger.error('DocumentUpload: Timeout no upload do documento');
      throw Exception('Upload demorou mais que 2 minutos. Tente novamente.');
    } catch (e) {
      Logger.error('DocumentUpload: Erro durante upload de documento', error: e);
      String userFriendlyMessage = e.toString().startsWith('Exception: ') ? e.toString().substring(11) : e.toString();
      throw Exception('Erro no upload: $userFriendlyMessage');
    }
  }

  // NOVO: Função auxiliar para extrair a extensão de forma segura.
  String _getFileExtension(String filePath) {
    return path.extension(filePath).replaceAll('.', '').toLowerCase();
  }

  // NOVO: Função auxiliar para determinar o MediaType com base na extensão.
  MediaType? _getMediaType(String extension) {
    if (extension.isEmpty) return null; // Deixa o http decidir.

    switch (extension) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        // Para outras extensões, é mais seguro não especificar e deixar o backend/servidor decidir.
        return null;
    }
  }
}
