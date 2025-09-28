// lib/services/api_modules/auth/auth_api_service.dart - JWT API Service

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_headers.dart';
import '../../../utils/logger.dart';

/// Serviço de API para autenticação JWT
/// Substitui completamente o Firebase Auth
class AuthApiService {
  final ApiHeaders _headers;

  AuthApiService() : _headers = ApiHeaders() {
    Logger.info('AuthApiService: Inicializado com JWT (sem Firebase)');
  }

  /// Faz login com username e senha
  /// Substitui o antigo Firebase signInWithEmailAndPassword
  Future<Map<String, dynamic>> login(String username, String password) async {
    Logger.info("AuthApiService: Iniciando login JWT para usuário: $username");

    try {
      // Validar entrada
      if (username.trim().isEmpty || password.isEmpty) {
        throw Exception('Username e senha são obrigatórios');
      }

      final requestBody = {
        'username': username.trim(),
        'password': password,
      };

      Logger.debug("AuthApiService: Enviando requisição para ${ApiClient.baseUrl}/auth/login");

      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: await _headers.getJsonHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      Logger.debug("AuthApiService: Status da resposta: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("AuthApiService: Login bem-sucedido");

        // Salvar tokens JWT se retornados
        if (data['access_token'] != null) {
          await _headers.saveToken(data['access_token']);
          Logger.info("AuthApiService: Access token salvo");
        } else if (data['token'] != null) {
          // Compatibilidade com possível formato diferente
          await _headers.saveToken(data['token']);
          Logger.info("AuthApiService: Token salvo (compatibilidade)");
        }

        // Salvar refresh token se disponível
        if (data['refresh_token'] != null) {
          // TODO: Implementar armazenamento de refresh token
          Logger.debug("AuthApiService: Refresh token recebido (armazenamento futuro)");
        }

        return data;
      } else {
        Logger.warning("AuthApiService: Falha no login - Status: ${response.statusCode}");
        
        try {
          final error = jsonDecode(response.body);
          final errorMessage = error['error'] ?? 'Falha no login';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Falha no login: ${response.body}');
        }
      }
    } on SocketException {
      Logger.error("AuthApiService: Erro de conexão no login");
      throw Exception('Erro de conexão: Verifique sua internet e tente novamente');
    } on TimeoutException {
      Logger.error("AuthApiService: Timeout no login");
      throw Exception('Timeout: Servidor demorou para responder');
    } catch (e) {
      Logger.error("AuthApiService: Exceção no login", error: e);
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Erro inesperado no login: ${e.toString()}');
      }
    }
  }

  /// Registra novo usuário
  /// Substitui o antigo Firebase createUserWithEmailAndPassword
  Future<Map<String, dynamic>> register(String username, String password, String displayName) async {
    Logger.info("AuthApiService: Iniciando registro para usuário: $username");

    try {
      // Validar entrada
      if (username.trim().isEmpty || password.isEmpty) {
        throw Exception('Username e senha são obrigatórios');
      }

      if (displayName.trim().isEmpty) {
        displayName = username; // Usar username como display_name se vazio
      }

      final requestBody = {
        'username': username.trim(),
        'password': password,
        'display_name': displayName.trim(),
      };

      Logger.debug("AuthApiService: Enviando requisição para ${ApiClient.baseUrl}/auth/register");

      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: await _headers.getJsonHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      Logger.debug("AuthApiService: Status da resposta registro: ${response.statusCode}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("AuthApiService: Registro bem-sucedido");

        // Auto-salvar token após registro se fornecido
        if (data['access_token'] != null) {
          await _headers.saveToken(data['access_token']);
          Logger.info("AuthApiService: Token salvo após registro");
        } else if (data['token'] != null) {
          await _headers.saveToken(data['token']);
          Logger.info("AuthApiService: Token salvo após registro (compatibilidade)");
        }

        return data;
      } else {
        Logger.warning("AuthApiService: Falha no registro - Status: ${response.statusCode}");
        
        try {
          final error = jsonDecode(response.body);
          final errorMessage = error['error'] ?? 'Falha no registro';
          
          // Tratamento específico de erros comuns
          if (errorMessage.toLowerCase().contains('já existe') || 
              errorMessage.toLowerCase().contains('already exists')) {
            throw Exception('Nome de usuário já está em uso');
          } else if (errorMessage.toLowerCase().contains('senha') || 
                     errorMessage.toLowerCase().contains('password')) {
            throw Exception('Senha não atende aos requisitos mínimos');
          }
          
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Falha no registro: ${response.body}');
        }
      }
    } on SocketException {
      Logger.error("AuthApiService: Erro de conexão no registro");
      throw Exception('Erro de conexão: Verifique sua internet e tente novamente');
    } on TimeoutException {
      Logger.error("AuthApiService: Timeout no registro");
      throw Exception('Timeout: Servidor demorou para responder');
    } catch (e) {
      Logger.error("AuthApiService: Exceção no registro", error: e);
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Erro inesperado no registro: ${e.toString()}');
      }
    }
  }

  /// Obtem perfil do usuário logado
  /// Substitui verificação de Firebase Auth currentUser
  Future<Map<String, dynamic>> getProfile() async {
    Logger.debug("AuthApiService: Buscando perfil do usuário");

    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/auth/profile'),
        headers: await _headers.getJsonHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 15));

      Logger.debug("AuthApiService: Status resposta perfil: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("AuthApiService: Perfil carregado com sucesso");
        return data;
      } else if (response.statusCode == 401) {
        Logger.warning("AuthApiService: Token expirado ou inválido");
        
        // Limpar token inválido
        await _headers.clearToken();
        throw Exception('Sessão expirada. Faça login novamente.');
      } else {
        Logger.warning("AuthApiService: Falha ao buscar perfil - Status: ${response.statusCode}");
        
        try {
          final error = jsonDecode(response.body);
          throw Exception('Falha ao buscar perfil: ${error['error'] ?? response.body}');
        } catch (e) {
          throw Exception('Falha ao buscar perfil');
        }
      }
    } on SocketException {
      Logger.error("AuthApiService: Erro de conexão ao buscar perfil");
      throw Exception('Erro de conexão: Verifique sua internet');
    } on TimeoutException {
      Logger.error("AuthApiService: Timeout ao buscar perfil");
      throw Exception('Timeout: Servidor demorou para responder');
    } catch (e) {
      Logger.error("AuthApiService: Exceção ao buscar perfil", error: e);
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Erro inesperado ao buscar perfil: ${e.toString()}');
      }
    }
  }

  /// Renova token JWT
  /// Funcionalidade nova que não existia no Firebase
  Future<Map<String, dynamic>> refreshToken() async {
    Logger.debug("AuthApiService: Renovando token JWT");

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/refresh'),
        headers: await _headers.getJsonHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 15));

      Logger.debug("AuthApiService: Status renovação token: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("AuthApiService: Token renovado com sucesso");

        // Salvar novo token
        if (data['access_token'] != null) {
          await _headers.saveToken(data['access_token']);
        } else if (data['token'] != null) {
          await _headers.saveToken(data['token']);
        }

        return data;
      } else if (response.statusCode == 401) {
        Logger.warning("AuthApiService: Falha na renovação - token inválido");
        
        // Limpar token inválido
        await _headers.clearToken();
        throw Exception('Token inválido. Faça login novamente.');
      } else {
        Logger.warning("AuthApiService: Falha na renovação - Status: ${response.statusCode}");
        throw Exception('Falha ao renovar token');
      }
    } catch (e) {
      Logger.error("AuthApiService: Erro na renovação de token", error: e);
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Erro inesperado na renovação: ${e.toString()}');
      }
    }
  }

  /// Faz logout do usuário
  /// Substitui Firebase Auth signOut
  Future<void> logout() async {
    Logger.info("AuthApiService: Iniciando logout JWT");

    try {
      // Tentar informar o backend sobre logout (opcional)
      try {
        final response = await http.post(
          Uri.parse('${ApiClient.baseUrl}/auth/logout'),
          headers: await _headers.getJsonHeaders(includeAuth: true),
        ).timeout(const Duration(seconds: 10));
        
        Logger.debug("AuthApiService: Logout no backend - Status: ${response.statusCode}");
      } catch (e) {
        Logger.warning("AuthApiService: Falha ao notificar backend sobre logout (não crítico)", error: e);
      }

      // Sempre limpar token local
      await _headers.clearToken();
      Logger.info("AuthApiService: Token JWT removido - logout realizado");

    } catch (e) {
      Logger.error("AuthApiService: Erro no logout", error: e);
      // Mesmo com erro, limpar token local
      await _headers.clearToken();
      rethrow;
    }
  }

  /// Verifica se usuário está autenticado
  /// Substitui verificação Firebase Auth currentUser != null
  Future<bool> isAuthenticated() async {
    try {
      final hasToken = await _headers.hasValidToken();
      Logger.debug("AuthApiService: Token presente: $hasToken");
      
      if (!hasToken) {
        return false;
      }

      // Verificar validade fazendo uma requisição leve
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/auth/profile'),
        headers: await _headers.getJsonHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 10));

      final isValid = response.statusCode == 200;
      Logger.debug("AuthApiService: Token válido: $isValid");

      if (!isValid) {
        await _headers.clearToken();
      }

      return isValid;
    } catch (e) {
      Logger.warning("AuthApiService: Erro na verificação de autenticação", error: e);
      return false;
    }
  }

  /// Atualiza senha do usuário
  /// Funcionalidade que pode ser adicionada futuramente
  Future<Map<String, dynamic>> updatePassword(String currentPassword, String newPassword) async {
    Logger.info("AuthApiService: Atualizando senha do usuário");

    try {
      if (currentPassword.isEmpty || newPassword.isEmpty) {
        throw Exception('Senha atual e nova senha são obrigatórias');
      }

      if (newPassword.length < 6) {
        throw Exception('Nova senha deve ter pelo menos 6 caracteres');
      }

      final requestBody = {
        'current_password': currentPassword,
        'new_password': newPassword,
      };

      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/auth/password'),
        headers: await _headers.getJsonHeaders(includeAuth: true),
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("AuthApiService: Senha atualizada com sucesso");
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Senha atual incorreta');
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['error'] ?? 'Falha ao atualizar senha');
        } catch (e) {
          throw Exception('Falha ao atualizar senha');
        }
      }
    } catch (e) {
      Logger.error("AuthApiService: Erro ao atualizar senha", error: e);
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Erro inesperado ao atualizar senha: ${e.toString()}');
      }
    }
  }

  /// Solicita redefinição de senha por email
  /// Funcionalidade que pode ser adicionada futuramente
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    Logger.info("AuthApiService: Solicitando redefinição de senha para: $email");

    try {
      if (email.trim().isEmpty) {
        throw Exception('Email é obrigatório');
      }

      final requestBody = {
        'email': email.trim(),
      };

      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/password-reset'),
        headers: await _headers.getJsonHeaders(includeAuth: false),
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info("AuthApiService: Solicitação de reset enviada com sucesso");
        return data;
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['error'] ?? 'Falha ao solicitar redefinição');
        } catch (e) {
          throw Exception('Falha ao solicitar redefinição de senha');
        }
      }
    } catch (e) {
      Logger.error("AuthApiService: Erro ao solicitar reset de senha", error: e);
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Erro inesperado: ${e.toString()}');
      }
    }
  }

  /// Executa diagnósticos de autenticação JWT
  /// Útil para debug e monitoramento
  Future<Map<String, dynamic>> runAuthDiagnostics() async {
    final diagnostics = <String, dynamic>{};
    
    try {
      Logger.info('AuthApiService: Executando diagnósticos JWT...');
      
      // Verificar token local
      final hasToken = await _headers.hasValidToken();
      diagnostics['has_local_token'] = hasToken;
      
      if (hasToken) {
        // Verificar conectividade com backend
        final connectivityResult = await ApiClient.testConnectivity();
        diagnostics['backend_connectivity'] = connectivityResult;
        
        if (connectivityResult) {
          // Verificar validade do token
          try {
            final profileResponse = await getProfile();
            diagnostics['token_valid'] = true;
            diagnostics['user_data'] = profileResponse['user'] != null;
          } catch (e) {
            diagnostics['token_valid'] = false;
            diagnostics['token_error'] = e.toString();
          }
        }
      }
      
      diagnostics['api_base_url'] = ApiClient.baseUrl;
      diagnostics['timestamp'] = DateTime.now().toIso8601String();
      
      Logger.info('AuthApiService: Diagnósticos JWT concluídos');
      
    } catch (e) {
      Logger.error('AuthApiService: Erro nos diagnósticos JWT', error: e);
      diagnostics['diagnostics_error'] = e.toString();
    }
    
    return diagnostics;
  }

  /// Limpa todos os dados de autenticação
  /// Útil para casos de logout forçado ou reset
  Future<void> clearAuthData() async {
    Logger.info("AuthApiService: Limpando todos os dados de autenticação");
    
    try {
      await _headers.clearToken();
      // Aqui podem ser adicionadas outras limpezas futuras (refresh tokens, etc)
      
      Logger.info("AuthApiService: Dados de autenticação limpos com sucesso");
    } catch (e) {
      Logger.error("AuthApiService: Erro ao limpar dados de auth", error: e);
      rethrow;
    }
  }

  /// Getters de conveniência
  bool get hasHeaders => _headers != null;
  
  /// Retorna informações do token atual (se disponível)
  /// Não decodifica o JWT por segurança, apenas verifica presença
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final hasToken = await _headers.hasValidToken();
      return {
        'has_token': hasToken,
        'checked_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'has_token': false,
        'error': e.toString(),
        'checked_at': DateTime.now().toIso8601String(),
      };
    }
  }
}
