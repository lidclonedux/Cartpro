// lib/services/api_modules/settings/settings_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class SettingsApiService {
  final ApiHeaders _headers;

  SettingsApiService(this._headers);

  Future<Map<String, dynamic>> updateContactInfo(String phoneNumber) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone.length < 10 || cleanPhone.length > 11) {
        throw Exception('Número de telefone inválido. Use formato: (XX) XXXXX-XXXX');
      }

      Logger.info('SettingsApi: Atualizando telefone: ${phoneNumber.replaceAll(RegExp(r'\d'), '*')}');
      
      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/settings/contact-info'),
        headers: await _headers.getJsonHeaders(),
        body: jsonEncode({
          'phone_number': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Logger.info('SettingsApi: Telefone atualizado com sucesso');
        return jsonDecode(response.body);
      } else {
        Logger.error('SettingsApi: Erro ao atualizar telefone: ${response.statusCode}');
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao atualizar informações de contato: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao atualizar informações de contato: ${response.body}');
        }
      }
    } catch (e) {
      Logger.error('SettingsApi: Exceção ao atualizar telefone', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePixInfo(String pixKey, [String? pixQrCodeUrl]) async {
    try {
      if (pixKey.trim().isEmpty) {
        throw Exception('Chave PIX não pode estar vazia');
      }

      Logger.info('SettingsApi: Atualizando chave PIX: ${pixKey.substring(0, 3)}***');
      
      final Map<String, dynamic> body = {
        'pix_key': pixKey.trim(),
      };
      
      if (pixQrCodeUrl != null && pixQrCodeUrl.isNotEmpty) {
        body['pix_qr_code_url'] = pixQrCodeUrl;
        Logger.info('SettingsApi: QR Code URL também será atualizada');
      }

      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/settings/pix-info'),
        headers: await _headers.getJsonHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Logger.info('SettingsApi: Informações PIX atualizadas com sucesso');
        return jsonDecode(response.body);
      } else {
        Logger.error('SettingsApi: Erro ao atualizar PIX: ${response.statusCode}');
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao atualizar informações de PIX: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao atualizar informações de PIX: ${response.body}');
        }
      }
    } catch (e) {
      Logger.error('SettingsApi: Exceção ao atualizar PIX', error: e);
      rethrow;
    }
  }
}