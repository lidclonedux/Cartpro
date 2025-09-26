// lib/services/api_modules/payments/payment_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';

class PaymentApiService {
  final ApiHeaders _headers;

  PaymentApiService(this._headers);

  Future<Map<String, dynamic>> getStorePaymentInfo(String storeOwnerId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/store/$storeOwnerId/payment-info'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'User-Agent': 'VitrineBorracharia/1.0.0 Flutter',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao buscar informações da loja: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao buscar informações da loja: ${response.body}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadPaymentProof({
    required File imageFile,
    String? orderId,
    String? description,
  }) async {
    try {
      print("Iniciando upload de comprovante PIX");
      
      final uri = Uri.parse('${ApiClient.baseUrl}/upload/proof');
      final request = http.MultipartRequest('POST', uri);
      
      final headers = await _headers.getMultipartHeaders();
      request.headers.addAll(headers);
      
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'comprovante_pix_${DateTime.now().millisecondsSinceEpoch}.${_getFileExtension(imageFile.path)}',
      );
      request.files.add(multipartFile);
      
      request.fields['context'] = 'ecommerce';
      request.fields['type'] = 'pix_proof';
      if (orderId != null) request.fields['order_id'] = orderId;
      if (description != null) request.fields['description'] = description;
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final uploadUrl = data['url'] ?? data['file_url'];
        return uploadUrl;
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha no upload: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha no upload: ${response.body}');
        }
      }
      
    } catch (e) {
      throw Exception('Erro no upload: ${e.toString()}');
    }
  }

  String _getFileExtension(String filePath) {
    final parts = filePath.split('.');
    if (parts.length > 1) {
      final extension = parts.last.toLowerCase();
      const validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      return validExtensions.contains(extension) ? extension : 'jpg';
    }
    return 'jpg';
  }
}