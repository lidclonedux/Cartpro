// lib/services/api_modules/core/api_client.dart - VERSÃO MODIFICADA PARA AMBIENTE DINÂMICO

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // <-- ADIÇÃO: Importado para usar kDebugMode
import 'package:http/http.dart' as http;
import 'package:vitrine_borracharia/utils/logger.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        Logger.info("SSL Certificate bypass para $host:$port");
        return true;
      };
  }
}

class ApiClient {
  // --- MODIFICAÇÃO CRÍTICA: URL Dinâmica ---
  static final String baseUrl = kDebugMode
      ? "http://192.168.15.5:8000/api" // URL de Desenvolvimento (seu IP local)
      : "https://maykonrodass.onrender.com/api"; // URL de Produção

  static const Duration _timeout = Duration(seconds: 20);

  static Future<http.Response> _sendRequest(
      Future<http.Response> Function() request,
      String endpoint,
      ) async {
    try {
      final response = await request().timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody["error"] ?? "Erro desconhecido";
        Logger.error("API Error ($endpoint): ${response.statusCode} - $errorMessage");
        throw Exception(errorMessage);
      }
    } on TimeoutException {
      Logger.error("API Timeout ($endpoint): A requisição excedeu o tempo limite.");
      throw Exception("A requisição excedeu o tempo limite. Tente novamente.");
    } on SocketException {
      Logger.error("API Network Error ($endpoint): Sem conexão com a internet.");
      throw Exception("Sem conexão com a internet. Verifique sua conexão.");
    } catch (e) {
      Logger.error("API Exception ($endpoint): $e");
      rethrow;
    }
  }

  static Future<http.Response> get(String endpoint, {Map<String, String>? headers}) {
    Logger.info("API GET: $baseUrl$endpoint");
    return _sendRequest(
          () => http.get(Uri.parse("$baseUrl$endpoint"), headers: headers),
      endpoint,
    );
  }

  static Future<http.Response> post(String endpoint, {Map<String, String>? headers, Object? body}) {
    Logger.info("API POST: $baseUrl$endpoint");
    return _sendRequest(
          () => http.post(Uri.parse("$baseUrl$endpoint"), headers: headers, body: body),
      endpoint,
    );
  }

  static Future<http.Response> put(String endpoint, {Map<String, String>? headers, Object? body}) {
    Logger.info("API PUT: $baseUrl$endpoint");
    return _sendRequest(
          () => http.put(Uri.parse("$baseUrl$endpoint"), headers: headers, body: body),
      endpoint,
    );
  }

  static Future<http.Response> delete(String endpoint, {Map<String, String>? headers}) {
    Logger.info("API DELETE: $baseUrl$endpoint");
    return _sendRequest(
          () => http.delete(Uri.parse("$baseUrl$endpoint"), headers: headers),
      endpoint,
    );
  }

  static Future<bool> testConnectivity() async {
    try {
      // MODIFICAÇÃO: Testar sempre contra um endpoint público conhecido para verificar a internet.
      final testUrl = "https://maykonrodass.onrender.com/";
      Logger.info("Testando conectividade com $testUrl");
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'VitrineBorracharia/1.0.0 Flutter',
        },
      ).timeout(const Duration(seconds: 10));

      Logger.info("Teste de conectividade: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      Logger.error("Falha no teste de conectividade: $e");
      return false;
    }
  }
}
