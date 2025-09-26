// lib/services/api_modules/transactions/transaction_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class TransactionApiService {
  final ApiHeaders _headers;

  TransactionApiService(this._headers);

  Future<List<dynamic>> getTransactions() async {
    try {
      Logger.info('TransactionApi: Buscando transações do usuário');
      
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/transactions'),
        headers: await _headers.getJsonHeaders(),
      ).timeout(const Duration(seconds: 20));

      Logger.info('TransactionApi: Status resposta transações: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        Logger.info('TransactionApi: ${data.length} transações carregadas');
        return data;
      } else {
        Logger.error('TransactionApi: Erro ao carregar transações: ${response.statusCode}');
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao carregar transações: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao carregar transações: ${response.body}');
        }
      }
    } catch (e) {
      Logger.error('TransactionApi: Exceção ao buscar transações', error: e);
      if (e is SocketException) {
        throw Exception('Erro de conexão: Verifique sua internet');
      } else if (e is TimeoutException) {
        throw Exception('Timeout: Servidor demorou para responder');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      Logger.info('TransactionApi: Buscando resumo do dashboard');
      
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/dashboard/summary'),
        headers: await _headers.getJsonHeaders(),
      ).timeout(const Duration(seconds: 15));

      Logger.info('TransactionApi: Status dashboard: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info('TransactionApi: Dashboard carregado com dados: ${data.keys.join(', ')}');
        return data;
      } else {
        Logger.error('TransactionApi: Erro dashboard: ${response.statusCode}');
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao carregar resumo do dashboard: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao carregar resumo do dashboard: ${response.body}');
        }
      }
    } catch (e) {
      Logger.error('TransactionApi: Exceção dashboard', error: e);
      rethrow;
    }
  }

  // ================================
  // CREATE TRANSACTION
  // ================================
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> transactionData) async {
    try {
      Logger.info("TransactionApi: Criando nova transação");
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/transactions'),
        headers: await _headers.getAuthHeaders(),
        body: jsonEncode(transactionData),
      ).timeout(const Duration(seconds: 20));

      Logger.info("TransactionApi: Status resposta criação transação: ${response.statusCode}");

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        Logger.info("TransactionApi: Transação criada com sucesso: ${data["id"]}");
        return data;
      } else {
        Logger.error("TransactionApi: Erro ao criar transação: ${response.statusCode}");
        try {
          final error = jsonDecode(response.body);
          throw Exception("Falha ao criar transação: ${error["error"] ?? response.body}");
        } catch (e) {
          throw Exception("Falha ao criar transação: ${response.body}");
        }
      }
    } catch (e) {
      Logger.error("TransactionApi: Exceção ao criar transação", error: e);
      rethrow;
    }
  }

  // ================================
  // UPDATE TRANSACTION
  // ================================
  Future<Map<String, dynamic>> updateTransaction(String id, Map<String, dynamic> transactionData) async {
    try {
      Logger.info("TransactionApi: Atualizando transação $id");
      final response = await http.put(
        Uri.parse("${ApiClient.baseUrl}/transactions/$id"),
        headers: await _headers.getAuthHeaders(),
        body: jsonEncode(transactionData),
      ).timeout(const Duration(seconds: 20));

      Logger.info("TransactionApi: Status resposta atualização transação: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("TransactionApi: Transação $id atualizada com sucesso");
        return data;
      } else {
        Logger.error("TransactionApi: Erro ao atualizar transação $id: ${response.statusCode}");
        try {
          final error = jsonDecode(response.body);
          throw Exception("Falha ao atualizar transação: ${error["error"] ?? response.body}");
        } catch (e) {
          throw Exception("Falha ao atualizar transação: ${response.body}");
        }
      }
    } catch (e) {
      Logger.error("TransactionApi: Exceção ao atualizar transação $id", error: e);
      rethrow;
    }
  }

  // ================================
  // DELETE TRANSACTION
  // ================================
  Future<void> deleteTransaction(String id) async {
    try {
      Logger.info("TransactionApi: Deletando transação $id");
      final response = await http.delete(
        Uri.parse("${ApiClient.baseUrl}/transactions/$id"),
        headers: await _headers.getAuthHeaders(),
      ).timeout(const Duration(seconds: 20));

      Logger.info("TransactionApi: Status resposta deleção transação: ${response.statusCode}");

      if (response.statusCode == 204) {
        Logger.info("TransactionApi: Transação $id deletada com sucesso");
      } else {
        Logger.error("TransactionApi: Erro ao deletar transação $id: ${response.statusCode}");
        try {
          final error = jsonDecode(response.body);
          throw Exception("Falha ao deletar transação: ${error["error"] ?? response.body}");
        } catch (e) {
          throw Exception("Falha ao deletar transação: ${response.body}");
        }
      }
    } catch (e) {
      Logger.error("TransactionApi: Exceção ao deletar transação $id", error: e);
      rethrow;
    }
  }

  // ================================
  // GET ONLY RECURRING TRANSACTIONS
  // ================================
  Future<List<dynamic>> getRecurringTransactions() async {
    try {
      Logger.info('TransactionApi: Buscando transações recorrentes');

      final allTransactions = await getTransactions();

      final recurring = allTransactions
          .where((t) => (t is Map<String, dynamic>) && (t['is_recurring'] == true))
          .toList();

      Logger.info('TransactionApi: ${recurring.length} transações recorrentes carregadas');

      return recurring;
    } catch (e) {
      Logger.error('TransactionApi: Exceção ao buscar transações recorrentes', error: e);
      rethrow;
    }
  }
}
