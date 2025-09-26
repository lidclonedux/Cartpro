// lib/services/api_modules/categories/category_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';

class CategoryApiService {
  final ApiHeaders _headers;

  CategoryApiService(this._headers);

  Future<List<dynamic>> getCategories({String? context}) async {
    final uri = Uri.parse("${ApiClient.baseUrl}/categories");
    final Map<String, String> queryParameters = {};
    if (context != null) {
      queryParameters["context"] = context;
    }

    final finalUri = uri.replace(queryParameters: queryParameters.isNotEmpty ? queryParameters : null);

    final response = await http.get(
      finalUri,
      headers: await _headers.getJsonHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception("Falha ao carregar categorias: ${error["error"] ?? response.body}");
      } catch (e) {
        throw Exception("Falha ao carregar categorias: ${response.body}");
      }
    }
  }

  Future<Map<String, dynamic>> createCategory(
    String name, {
    String? context,
    String? type,
    String? color,
    String? icon,
    String? emoji,
  }) async {
    final Map<String, dynamic> body = {
      'name': name,
    };
    if (context != null) body['context'] = context;
    if (type != null) body['type'] = type;
    if (color != null) body['color'] = color;
    if (icon != null) body['icon'] = icon;
    if (emoji != null) body['emoji'] = emoji;

    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/categories'),
      headers: await _headers.getJsonHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao criar categoria: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao criar categoria: ${response.body}');
      }
    }
  }

  Future<Map<String, dynamic>> updateCategory(
    String categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    final response = await http.put(
      Uri.parse('${ApiClient.baseUrl}/categories/$categoryId'),
      headers: await _headers.getJsonHeaders(),
      body: jsonEncode(categoryData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao atualizar categoria: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao atualizar categoria: ${response.body}');
      }
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.baseUrl}/categories/$categoryId'),
      headers: await _headers.getJsonHeaders(),
    );

    if (response.statusCode != 200) {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao remover categoria: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao remover categoria: ${response.body}');
      }
    }
  }

  Future<Map<String, dynamic>> seedDefaultCategories() async {
    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/categories/seed'),
      headers: await _headers.getJsonHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao criar categorias padrão: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao criar categorias padrão: ${response.body}');
      }
    }
  }
}