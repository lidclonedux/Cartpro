import 'dart:convert';
import 'dart:typed_data'; // <<< ADICIONADO para suportar bytes do arquivo
import 'package:flutter/foundation.dart' show kIsWeb; // <<< ADICIONADO para lógica condicional
import 'package:http/http.dart' as http; // <<< ADICIONADO para requisições multipart
import 'package:vitrine_borracharia/utils/logger.dart';
import '../core/api_client.dart';
import '../core/api_headers.dart';

class AccountingApiService {
  final ApiHeaders _headers;

  AccountingApiService(this._headers);

  // Dashboard Summary - endpoint alterado para a nova rota unificada
  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final response = await ApiClient.get(
        '/dashboard/full-summary', // era '/dashboard/summary'
        headers: await _headers.getAuthHeaders(),
      );

      Logger.info('AccountingApiService: Resumo completo do dashboard obtido com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao obter resumo completo do dashboard', error: e);
      rethrow;
    }
  }

  // =======================================================================
  // === PROCESSAMENTO DE DOCUMENTOS (IMPORTAÇÃO) ===
  // =======================================================================

  // <<< CORREÇÃO: Novo método `processDocument` adicionado >>>
  Future<Map<String, dynamic>> processDocument({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String context = 'business',
    bool autoSave = false,
  }) async {
    final logPrefix = '📄 [API_SERVICE]';
    Logger.info('$logPrefix Preparando para enviar o documento: $fileName');

    try {
      // 1. Monta a URL completa da API
      final uri = Uri.parse('${ApiClient.baseUrl}/documents/process');
      
      // 2. Cria uma requisição do tipo multipart
      var request = http.MultipartRequest('POST', uri);

      // 3. Adiciona os cabeçalhos de autenticação
      request.headers.addAll(await _headers.getAuthHeaders());

      // 4. Adiciona os campos de texto (form-data)
      request.fields['context'] = context;
      request.fields['auto_save'] = autoSave.toString();

      // 5. Adiciona o arquivo (lógica condicional para web e mobile)
      if (kIsWeb && fileBytes != null) {
        // Lógica para a Web: usa os bytes do arquivo
        Logger.info('$logPrefix Anexando arquivo da Web (bytes)...');
        request.files.add(http.MultipartFile.fromBytes(
          'file', // O nome do campo que o backend espera
          fileBytes,
          filename: fileName,
        ));
      } else if (!kIsWeb && filePath != null) {
        // Lógica para Mobile/Desktop: usa o caminho do arquivo
        Logger.info('$logPrefix Anexando arquivo do Mobile/Desktop (path)...');
        request.files.add(await http.MultipartFile.fromPath(
          'file', // O nome do campo que o backend espera
          filePath,
          filename: fileName,
        ));
      } else {
        throw Exception('Dados do arquivo inválidos: Nenhum path ou bytes fornecidos.');
      }

      // 6. Envia a requisição e aguarda a resposta
      Logger.info('$logPrefix Enviando requisição multipart para a API...');
      final streamedResponse = await request.send();

      // 7. Lê e decodifica a resposta
      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = json.decode(response.body);

      // 8. Verifica o status da resposta
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Logger.info('$logPrefix ✅ Documento processado com sucesso pela API. Status: ${response.statusCode}');
        return responseBody;
      } else {
        final error = responseBody['error'] ?? 'Erro desconhecido na API';
        Logger.error('$logPrefix ❌ Erro da API ao processar documento. Status: ${response.statusCode}, Erro: $error');
        throw Exception('Erro da API: $error');
      }
    } catch (e) {
      Logger.error('$logPrefix ❌ ERRO CRÍTICO ao enviar documento para processamento.', error: e);
      rethrow;
    }
  }

  // =======================================================================
  // === CATEGORIAS DE CONTABILIDADE ===
  // =======================================================================

  Future<List<dynamic>> getAccountingCategories() async {
    try {
      final response = await ApiClient.get(
        '/accounting/categories',
        headers: await _headers.getAuthHeaders(),
      );
      Logger.info('AccountingApiService: Categorias de contabilidade obtidas com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao obter categorias de contabilidade', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createAccountingCategory(Map<String, dynamic> categoryData) async {
    try {
      final response = await ApiClient.post(
        '/accounting/categories',
        headers: await _headers.getAuthHeaders(),
        body: json.encode(categoryData),
      );
      Logger.info('AccountingApiService: Categoria de contabilidade criada com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao criar categoria de contabilidade', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateAccountingCategory(String categoryId, Map<String, dynamic> categoryData) async {
    try {
      final response = await ApiClient.put(
        '/accounting/categories/$categoryId',
        headers: await _headers.getAuthHeaders(),
        body: json.encode(categoryData),
      );
      Logger.info('AccountingApiService: Categoria de contabilidade atualizada com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao atualizar categoria de contabilidade', error: e);
      rethrow;
    }
  }

  Future<void> deleteAccountingCategory(String categoryId) async {
    try {
      await ApiClient.delete(
        '/accounting/categories/$categoryId',
        headers: await _headers.getAuthHeaders(),
      );
      Logger.info('AccountingApiService: Categoria de contabilidade deletada com sucesso.');
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao deletar categoria de contabilidade', error: e);
      rethrow;
    }
  }

  // =======================================================================
  // === TRANSAÇÕES RECORRENTES ===
  // =======================================================================

  Future<List<dynamic>> getRecurringTransactions() async {
    try {
      final response = await ApiClient.get(
        '/accounting/recurring-transactions',
        headers: await _headers.getAuthHeaders(),
      );
      Logger.info('AccountingApiService: Transações recorrentes obtidas com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao obter transações recorrentes', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRecurringTransaction(Map<String, dynamic> recurringTransactionData) async {
    try {
      final response = await ApiClient.post(
        '/accounting/recurring-transactions',
        headers: await _headers.getAuthHeaders(),
        body: json.encode(recurringTransactionData),
      );
      Logger.info('AccountingApiService: Transação recorrente criada com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao criar transação recorrente', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateRecurringTransaction(String recurringTransactionId, Map<String, dynamic> recurringTransactionData) async {
    try {
      final response = await ApiClient.put(
        '/accounting/recurring-transactions/$recurringTransactionId',
        headers: await _headers.getAuthHeaders(),
        body: json.encode(recurringTransactionData),
      );
      Logger.info('AccountingApiService: Transação recorrente atualizada com sucesso.');
      return json.decode(response.body);
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao atualizar transação recorrente', error: e);
      rethrow;
    }
  }

  Future<void> deleteRecurringTransaction(String recurringTransactionId) async {
    try {
      await ApiClient.delete(
        '/accounting/recurring-transactions/$recurringTransactionId',
        headers: await _headers.getAuthHeaders(),
      );
      Logger.info('AccountingApiService: Transação recorrente deletada com sucesso.');
    } catch (e) {
      Logger.error('AccountingApiService: Erro ao deletar transação recorrente', error: e);
      rethrow;
    }
  }
}
