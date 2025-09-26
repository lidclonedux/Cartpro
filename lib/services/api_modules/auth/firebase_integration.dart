// lib/services/api_modules/auth/firebase_integration.dart - VERSÃO CORRIGIDA

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/api_exceptions.dart';
import '../../../utils/logger.dart';

/// Serviço especializado para integração com Firebase Auth
/// Encapsula toda a lógica específica do Firebase
class FirebaseIntegration {
  final FirebaseAuth _firebaseAuth;
  
  FirebaseIntegration(this._firebaseAuth);

  /// Retorna o ID Token do usuário atualmente logado no Firebase
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      if (_firebaseAuth.currentUser == null) {
        Logger.info('FirebaseIntegration: Usuário não logado no Firebase');
        return null;
      }
      
      final token = await _firebaseAuth.currentUser!.getIdToken(forceRefresh);
      if (token != null) {
        final preview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
        Logger.info('FirebaseIntegration: Token Firebase obtido: $preview');
      }

      return token;
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro ao obter token Firebase', error: e);
      return null;
    }
  }

  /// Autentica o usuário no Firebase usando custom token do backend
  Future<UserCredential> signInWithCustomToken(String customToken) async {
    try {
      Logger.info('FirebaseIntegration: Autenticando com custom token...');
      
      final credential = await _firebaseAuth.signInWithCustomToken(customToken);
      
      // Aguarda confirmação da autenticação
      int attempts = 0;
      while (_firebaseAuth.currentUser == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
        Logger.info('FirebaseIntegration: Aguardando confirmação Firebase (tentativa $attempts)');
      }
      
      if (_firebaseAuth.currentUser == null) {
        throw AuthenticationException('Falha ao confirmar autenticação no Firebase após login');
      }
      
      Logger.info('FirebaseIntegration: Usuário autenticado: ${_firebaseAuth.currentUser!.uid}');
      return credential;
      
    } on FirebaseAuthException catch (e) {
      Logger.error('FirebaseIntegration: Erro FirebaseAuth: ${e.code} - ${e.message}');
      throw AuthenticationException(_getFirebaseErrorMessage(e));
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro geral na autenticação', error: e);
      throw AuthenticationException('Ocorreu um erro inesperado durante a autenticação: $e');
    }
  }

  /// Realiza logout do Firebase
  Future<void> signOut() async {
    try {
      Logger.info('FirebaseIntegration: Fazendo logout...');
      await _firebaseAuth.signOut();
      Logger.info('FirebaseIntegration: Logout realizado com sucesso');
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro no logout', error: e);
      throw AuthenticationException('Erro durante logout: $e');
    }
  }

  /// Verifica se há usuário autenticado
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  /// Retorna o usuário atual
  User? get currentUser => _firebaseAuth.currentUser;

  /// Retorna o UID do usuário atual
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  /// Retorna informações básicas do usuário atual
  Map<String, String?> get currentUserInfo {
    final user = _firebaseAuth.currentUser;
    if (user == null) return {};
    
    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'isEmailVerified': user.emailVerified.toString(),
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }

  /// Stream de mudanças no estado de autenticação
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Stream de mudanças do usuário (inclui mudanças no perfil)
  Stream<User?> get userChanges => _firebaseAuth.userChanges();

  /// Força refresh do token atual
  Future<String?> refreshToken() async {
    try {
      if (_firebaseAuth.currentUser == null) {
        Logger.warning('FirebaseIntegration: Tentativa de refresh sem usuário logado');
        return null;
      }

      Logger.info('FirebaseIntegration: Forçando refresh do token...');
      final token = await getIdToken(forceRefresh: true);
      
      if (token != null) {
        Logger.info('FirebaseIntegration: Token renovado com sucesso');
      } else {
        Logger.warning('FirebaseIntegration: Falha ao renovar token');
      }

      return token;
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro ao renovar token', error: e);
      return null;
    }
  }

  /// Verifica se o token atual está válido (não expirado)
  Future<bool> isTokenValid() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;

      // Tenta obter o token atual sem forçar refresh
      final token = await user.getIdToken(false);
      return token != null && token.isNotEmpty;
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro ao verificar validade do token', error: e);
      return false;
    }
  }

  /// Obtém claims customizados do token
  Future<Map<String, dynamic>> getCustomClaims() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return {};
      }

      final idTokenResult = await user.getIdTokenResult();
      return idTokenResult.claims ?? {};
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro ao obter custom claims', error: e);
      return {};
    }
  }

  /// Verifica se o usuário tem uma role específica
  Future<bool> hasRole(String role) async {
    try {
      final claims = await getCustomClaims();
      final roles = claims['roles'] as List<dynamic>?;
      return roles?.contains(role) ?? false;
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro ao verificar role', error: e);
      return false;
    }
  }

  /// Verifica se o usuário é administrador
  Future<bool> get isAdmin async => await hasRole('admin');

  /// Obtém informações detalhadas do token
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return {'error': 'Usuário não logado'};
      }

      final idTokenResult = await user.getIdTokenResult();
      
      return {
        'token_length': idTokenResult.token?.length ?? 0,
        'issued_at': idTokenResult.issuedAtTime?.toIso8601String(),
        'expires_at': idTokenResult.expirationTime?.toIso8601String(),
        'auth_time': idTokenResult.authTime?.toIso8601String(),
        'sign_in_provider': idTokenResult.signInProvider,
        'claims': idTokenResult.claims,
      };
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro ao obter info do token', error: e);
      return {'error': e.toString()};
    }
  }

  /// Listener para mudanças de estado de autenticação
  StreamSubscription<User?> listenToAuthChanges(Function(User?) callback) {
    Logger.info('FirebaseIntegration: Configurando listener de mudanças de auth');
    return authStateChanges.listen(
      callback,
      onError: (error) {
        Logger.error('FirebaseIntegration: Erro no listener de auth', error: error);
      },
    );
  }

  /// Executa diagnósticos do Firebase
  Future<Map<String, dynamic>> runFirebaseDiagnostics() async {
    final diagnostics = <String, dynamic>{};
    
    try {
      // Info básica
      diagnostics['is_authenticated'] = isAuthenticated;
      diagnostics['current_user_id'] = currentUserId;
      
      if (isAuthenticated) {
        // Info do usuário
        diagnostics['user_info'] = currentUserInfo;
        
        // Info do token
        diagnostics['token_info'] = await getTokenInfo();
        
        // Validade do token
        diagnostics['is_token_valid'] = await isTokenValid();
        
        // Custom claims
        diagnostics['custom_claims'] = await getCustomClaims();
        
        // Roles
        diagnostics['is_admin'] = await isAdmin;
      }
      
      diagnostics['firebase_app_name'] = _firebaseAuth.app.name;
      diagnostics['firebase_app_options'] = {
        'project_id': _firebaseAuth.app.options.projectId,
        'app_id': _firebaseAuth.app.options.appId,
      };
      
      Logger.info('FirebaseIntegration: Diagnósticos concluídos');
      
    } catch (e) {
      Logger.error('FirebaseIntegration: Erro nos diagnósticos', error: e);
      diagnostics['diagnostics_error'] = e.toString();
    }
    
    return diagnostics;
  }

  /// Converte erros do FirebaseAuth para mensagens amigáveis
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Usuário não encontrado';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'user-disabled':
        return 'Conta de usuário desabilitada';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde';
      case 'operation-not-allowed':
        return 'Operação não permitida';
      case 'weak-password':
        return 'Senha muito fraca';
      case 'email-already-in-use':
        return 'Email já está em uso';
      case 'invalid-email':
        return 'Email inválido';
      case 'invalid-custom-token':
        return 'Token customizado inválido';
      case 'custom-token-mismatch':
        return 'Token customizado não corresponde ao projeto';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet';
      default:
        return e.message ?? 'Erro desconhecido no Firebase Auth';
    }
  }

  /// Limpa recursos e listeners
  void dispose() {
    Logger.info('FirebaseIntegration: Limpando recursos...');
    // Aqui podemos adicionar limpeza de listeners se necessário
  }
}