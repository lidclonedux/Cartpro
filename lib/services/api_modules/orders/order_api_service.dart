// lib/services/api_modules/orders/order_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';

class OrderApiService {
  final ApiHeaders _headers;

  OrderApiService(this._headers);

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      if (!orderData.containsKey('payment_method')) {
        orderData['payment_method'] = 'pix';
      }
      
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/orders'),
        headers: await _headers.getJsonHeaders(),
        body: jsonEncode(orderData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao criar pedido: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao criar pedido: ${response.body}');
        }
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Erro de conexão: Verifique sua internet');
      } else if (e is TimeoutException) {
        throw Exception('Timeout: Servidor demorou para responder');
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getUserOrders() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiClient.baseUrl}/orders/user"),
        headers: await _headers.getJsonHeaders(),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else {
          return [];
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception("Falha ao carregar seus pedidos: ${error["error"] ?? response.body}");
        } catch (e) {
          throw Exception("Falha ao carregar seus pedidos: ${response.body}");
        }
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Erro de conexão: Verifique sua internet e tente novamente');
      } else if (e is TimeoutException) {
        throw Exception('Timeout: Servidor demorou para responder');
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getOrders() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/orders'),
        headers: await _headers.getJsonHeaders(),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else {
          return [];
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao carregar pedidos: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao carregar pedidos: ${response.body}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/orders/$orderId/status'),
        headers: await _headers.getJsonHeaders(),
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao atualizar status do pedido: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception("Falha ao atualizar status do pedido: ${response.body}");
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}