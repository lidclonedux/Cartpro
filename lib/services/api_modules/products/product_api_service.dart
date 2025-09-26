// lib/services/api_modules/products/product_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class ProductApiService {
  final ApiHeaders _headers;

  ProductApiService(this._headers);

  Future<List<dynamic>> getProducts({String? userId}) async {
    try {
      print("Buscando produtos...");
      
      final uri = Uri.parse('${ApiClient.baseUrl}/products');
      final Map<String, String> queryParameters = {};
      if (userId != null) {
        queryParameters['user_id'] = userId;
        print("Filtrando por usuário: $userId");
      }
      
      final finalUri = uri.replace(queryParameters: queryParameters.isNotEmpty ? queryParameters : null);

      final response = await http.get(
        finalUri,
        headers: await _headers.getJsonHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final rawProducts = jsonDecode(response.body) as List<dynamic>;
        Logger.info('Recebidos ${rawProducts.length} produtos da API');
        return rawProducts;
      } else {
        throw Exception('Falha ao carregar produtos');
      }
    } catch (e) {
      print("Exceção ao buscar produtos: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> productData) async {
    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/products'),
      headers: await _headers.getJsonHeaders(),
      body: jsonEncode(productData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao criar produto: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao criar produto: ${response.body}');
      }
    }
  }

  Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> productData) async {
    final response = await http.put(
      Uri.parse('${ApiClient.baseUrl}/products/$productId'),
      headers: await _headers.getJsonHeaders(),
      body: jsonEncode(productData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao atualizar produto: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao atualizar produto: ${response.body}');
      }
    }
  }

  Future<void> deleteProduct(String productId) async {
    final response = await http.delete(
      Uri.parse('${ApiClient.baseUrl}/products/$productId'),
      headers: await _headers.getJsonHeaders(),
    );

    if (response.statusCode != 200) {
      try {
        final error = jsonDecode(response.body);
        throw Exception('Falha ao remover produto: ${error['error'] ?? response.body}');
      } catch (e) {
        throw Exception('Falha ao remover produto: ${response.body}');
      }
    }
  }

  bool isValidProductData(Map<String, dynamic> productData) {
    try {
      final rawId = productData['id'];
      final rawIdMongo = productData['_id'];
      
      if (!_isValidProductId(rawId) && !_isValidProductId(rawIdMongo)) {
        Logger.warning('Produto com ID inválido rejeitado');
        return false;
      }
      
      final name = productData['name']?.toString().trim();
      if (name == null || name.isEmpty || name == 'null' || name == 'None') {
        Logger.warning('Produto sem nome válido rejeitado');
        return false;
      }
      
      final price = productData['price'];
      if (price == null || (price is! num && double.tryParse(price.toString()) == null)) {
        Logger.warning('Produto com preço inválido rejeitado: $name');
        return false;
      }
      
      final priceValue = price is num ? price.toDouble() : double.parse(price.toString());
      if (priceValue < 0) {
        Logger.warning('Produto com preço negativo rejeitado: $name');
        return false;
      }
      
      return true;
    } catch (e) {
      Logger.error('Erro na validação de produto', error: e);
      return false;
    }
  }

  bool _isValidProductId(dynamic id) {
    if (id == null) return false;
    
    final idString = id.toString().trim();
    const invalidValues = ['', 'None', 'null', 'undefined', 'NULL', 'NONE', '0', 'false', 'true'];
    
    if (invalidValues.contains(idString)) return false;
    
    if (idString.length == 24 && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(idString)) {
      return true;
    }
    
    if (idString.length >= 8 && !RegExp(r'^[0-9]+$').hasMatch(idString)) {
      return true;
    }
    
    return false;
  }
}