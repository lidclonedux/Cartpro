// lib/services/api_modules/core/api_headers.dart - VERSÃO JWT COMPLETA

import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/logger.dart';

class ApiHeaders {
  // REMOVIDO: final FirebaseAuth _firebaseAuth;

  // Constantes para chaves do SharedPreferences
  static const String _tokenKey = 'jwt_token';
  static const String _tokenTimestampKey = 'jwt_token_timestamp';
  static const String _refreshTokenKey = 'jwt_refresh_token';

  ApiHeaders() {
    Logger.debug('ApiHeaders: Inicializado com JWT (sem Firebase)');
  }

  /// Retorna o JWT Token do armazenamento local
  Future<String?> _getJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      
      if (token != null) {
        // Verificar se não expirou localmente (opcional)
        final timestamp = prefs.getInt(_tokenTimestampKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final hoursElapsed = (now - timestamp) / (1000 * 60 * 60);
        
        // Se passou mais de 23 horas, considerar expirado
        if (hoursElapsed > 23) {
          Logger.warning('ApiHeaders: Token JWT pode estar expirado (${hoursElapsed.toStringAsFixed(1)}h)');
          // Não remover aqui, deixar o backend decidir
        }
        
        final tokenPreview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
        Logger.debug('ApiHeaders: Token JWT obtido: $tokenPreview');
      } else {
        Logger.debug('ApiHeaders: Nenhum token JWT encontrado no storage');
      }

      return token;
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao obter token JWT", error: e);
      return null;
    }
  }

  /// Salva o JWT Token no armazenamento local
  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Salvar token
      await prefs.setString(_tokenKey, token);
      
      // Salvar timestamp para controle de expiração
      await prefs.setInt(_tokenTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      final tokenPreview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
      Logger.info('ApiHeaders: Token JWT salvo com sucesso: $tokenPreview');
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao salvar token JWT", error: e);
      rethrow;
    }
  }

  /// Salva o Refresh Token (para futuras implementações)
  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_refreshTokenKey, refreshToken);
      Logger.debug('ApiHeaders: Refresh token salvo');
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao salvar refresh token", error: e);
    }
  }

  /// Remove o JWT Token do armazenamento local
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remover token principal
      await prefs.remove(_tokenKey);
      
      // Remover timestamp
      await prefs.remove(_tokenTimestampKey);
      
      // Remover refresh token se existir
      await prefs.remove(_refreshTokenKey);
      
      Logger.info('ApiHeaders: Todos os tokens JWT removidos do storage');
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao limpar tokens JWT", error: e);
      // Não rethrow aqui, pois limpeza deve sempre "funcionar"
    }
  }

  /// Verifica se há um token válido armazenado
  Future<bool> hasValidToken() async {
    try {
      final token = await _getJwtToken();
      
      if (token == null || token.isEmpty) {
        Logger.debug('ApiHeaders: Nenhum token encontrado');
        return false;
      }
      
      // Verificação básica de formato JWT (3 partes separadas por ponto)
      final parts = token.split('.');
      if (parts.length != 3) {
        Logger.warning('ApiHeaders: Token com formato inválido');
        return false;
      }
      
      Logger.debug('ApiHeaders: Token presente e formato válido');
      return true;
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao verificar token", error: e);
      return false;
    }
  }

  /// Obtém informações básicas do token (sem decodificar por segurança)
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final timestamp = prefs.getInt(_tokenTimestampKey);
      
      if (token == null) {
        return {
          'has_token': false,
          'token_length': 0,
          'saved_at': null,
          'hours_since_save': null,
        };
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceSave = timestamp != null ? (now - timestamp) / (1000 * 60 * 60) : null;
      
      return {
        'has_token': true,
        'token_length': token.length,
        'saved_at': timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String() : null,
        'hours_since_save': hoursSinceSave?.toStringAsFixed(2),
        'estimated_expired': hoursSinceSave != null && hoursSinceSave > 24,
      };
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao obter info do token", error: e);
      return {'error': e.toString()};
    }
  }

  /// Gera headers para requisições JSON com autenticação JWT
  Future<Map<String, String>> getAuthHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': 'VitrineBorracharia/1.0.0 Flutter JWT',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getJwtToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        Logger.debug('ApiHeaders: Header Authorization adicionado');
      } else {
        Logger.warning('ApiHeaders: Token ausente - header sem Authorization');
      }
    }
    
    Logger.debug("ApiHeaders: Headers JSON preparados: ${headers.keys.join(', ')}");
    return headers;
  }

  /// CORREÇÃO: Alias para getAuthHeaders (compatibilidade com outros arquivos)
  Future<Map<String, String>> getJsonHeaders({bool includeAuth = true}) async {
    return getAuthHeaders(includeAuth: includeAuth);
  }

  /// Gera headers para requisições multipart com autenticação JWT
  Future<Map<String, String>> getMultipartHeaders({bool includeAuth = true}) async {
    final headers = {
      'User-Agent': 'VitrineBorracharia/1.0.0 Flutter JWT',
      'Accept': 'application/json',
      // IMPORTANTE: Não definir Content-Type para multipart - deixar automático
    };

    if (includeAuth) {
      final token = await _getJwtToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        Logger.debug('ApiHeaders: Header Authorization adicionado (multipart)');
      } else {
        Logger.warning('ApiHeaders: Token ausente - multipart sem Authorization');
      }
    }
    
    Logger.debug("ApiHeaders: Headers multipart preparados: ${headers.keys.join(', ')}");
    Logger.debug("ApiHeaders: IMPORTANTE: Content-Type omitido para multipart automático");
    return headers;
  }

  /// Headers para requisições que NÃO precisam de autenticação
  Future<Map<String, String>> getPublicHeaders() async {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': 'VitrineBorracharia/1.0.0 Flutter JWT',
      'Accept': 'application/json',
    };
    
    Logger.debug("ApiHeaders: Headers públicos preparados");
    return headers;
  }

  /// Atualiza token existente (para renovação)
  Future<void> updateToken(String newToken) async {
    Logger.info('ApiHeaders: Atualizando token JWT');
    await saveToken(newToken); // Reusa a lógica de salvamento
  }

  /// Verifica se o token precisa ser renovado (baseado no tempo local)
  Future<bool> needsRefresh({int hoursBeforeExpiry = 2}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_tokenTimestampKey);
      
      if (timestamp == null) {
        Logger.debug('ApiHeaders: Sem timestamp - assumir que precisa refresh');
        return true;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursElapsed = (now - timestamp) / (1000 * 60 * 60);
      
      // Se passou mais de (24 - hoursBeforeExpiry) horas, renovar
      final shouldRefresh = hoursElapsed > (24 - hoursBeforeExpiry);
      
      if (shouldRefresh) {
        Logger.info('ApiHeaders: Token precisa ser renovado (${hoursElapsed.toStringAsFixed(1)}h desde criação)');
      }
      
      return shouldRefresh;
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao verificar necessidade de refresh", error: e);
      return true; // Em caso de erro, assumir que precisa refresh
    }
  }

  /// Obtém o refresh token (para futuras implementações)
  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);
      
      if (refreshToken != null) {
        Logger.debug('ApiHeaders: Refresh token encontrado');
      } else {
        Logger.debug('ApiHeaders: Nenhum refresh token encontrado');
      }
      
      return refreshToken;
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao obter refresh token", error: e);
      return null;
    }
  }

  /// Método para debug - mostra status completo dos tokens
  Future<void> debugTokenStatus() async {
    try {
      Logger.debug('=== STATUS DOS TOKENS JWT ===');
      
      final tokenInfo = await getTokenInfo();
      tokenInfo.forEach((key, value) {
        Logger.debug('$key: $value');
      });
      
      final hasValid = await hasValidToken();
      Logger.debug('Token válido: $hasValid');
      
      final needsRef = await needsRefresh();
      Logger.debug('Precisa refresh: $needsRef');
      
      final hasRefresh = await getRefreshToken() != null;
      Logger.debug('Tem refresh token: $hasRefresh');
      
      Logger.debug('=== FIM STATUS TOKENS ===');
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro no debug de tokens", error: e);
    }
  }

  /// Limpa todos os dados de autenticação (logout completo)
  Future<void> clearAllAuthData() async {
    try {
      Logger.info('ApiHeaders: Limpando todos os dados de autenticação');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Lista de chaves relacionadas à autenticação para limpar
      final authKeys = [
        _tokenKey,
        _tokenTimestampKey,
        _refreshTokenKey,
        'user_data', // Se o app salvar dados do usuário
        'user_profile', // Se houver cache de perfil
        'last_sync', // Se houver sincronização
      ];
      
      for (final key in authKeys) {
        await prefs.remove(key);
      }
      
      Logger.info('ApiHeaders: Limpeza completa de autenticação concluída');
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro na limpeza completa", error: e);
      // Não rethrow - limpeza deve sempre "funcionar"
    }
  }

  /// Método público para acesso externo ao token (para diagnósticos)
  Future<String?> getIdToken() => _getJwtToken();

  /// Verifica conectividade básica com headers
  Future<bool> canMakeAuthenticatedRequest() async {
    try {
      final hasToken = await hasValidToken();
      if (!hasToken) {
        Logger.debug('ApiHeaders: Não pode fazer requisição autenticada - sem token');
        return false;
      }
      
      // Aqui poderia adicionar outras verificações se necessário
      Logger.debug('ApiHeaders: Pode fazer requisição autenticada');
      return true;
      
    } catch (e) {
      Logger.error("ApiHeaders: Erro ao verificar capacidade de autenticação", error: e);
      return false;
    }
  }

  /// Getter de conveniência para verificar se está "logado"
  Future<bool> get isAuthenticated => hasValidToken();

  /// Getter para informações básicas do estado atual
  Future<Map<String, dynamic>> get authStatus async {
    return {
      'has_token': await hasValidToken(),
      'needs_refresh': await needsRefresh(),
      'can_authenticate': await canMakeAuthenticatedRequest(),
      'token_info': await getTokenInfo(),
    };
  }
}
