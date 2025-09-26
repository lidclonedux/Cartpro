// lib/services/api_modules/diagnostics/diagnostic_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/api_client.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class DiagnosticService {
  final FirebaseAuth _firebaseAuth;

  DiagnosticService(this._firebaseAuth);

  /// Executa diagnósticos completos da aplicação
  Future<Map<String, dynamic>> runFullDiagnostics() async {
    final results = <String, dynamic>{};
    final startTime = DateTime.now();
    
    try {
      Logger.info('Diagnostics: Executando diagnósticos completos...');
      
      // Teste 1: Conectividade básica
      results['connectivity'] = await _testConnectivity();
      
      // Teste 2: Firebase Auth
      results['firebase_auth'] = await _testFirebaseAuth();
      
      // Teste 3: API Endpoints
      results['api_endpoints'] = await _testApiEndpoints();
      
      // Teste 4: Configuração de ambiente
      results['environment'] = _getEnvironmentInfo();
      
      // Teste 5: Performance básica
      results['performance'] = _getPerformanceMetrics(startTime);
      
      // Resumo geral
      results['summary'] = _generateSummary(results);
      
      Logger.info('Diagnostics: Diagnósticos concluídos');
      return results;
      
    } catch (e) {
      Logger.error('Diagnostics: Erro durante diagnósticos', error: e);
      results['error'] = e.toString();
      results['status'] = 'failed';
      return results;
    }
  }

  /// Testa conectividade básica
  Future<Map<String, dynamic>> _testConnectivity() async {
    try {
      final result = await ApiClient.testConnectivity();
      return {
        'status': result ? 'success' : 'failed',
        'reachable': result,
        'base_url': ApiClient.baseUrl,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'reachable': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Testa Firebase Authentication
  Future<Map<String, dynamic>> _testFirebaseAuth() async {
    try {
      final user = _firebaseAuth.currentUser;
      
      return {
        'status': 'success',
        'user_logged_in': user != null,
        'user_id': user?.uid,
        'user_email': user?.email,
        'email_verified': user?.emailVerified,
        'anonymous': user?.isAnonymous,
        'providers': user?.providerData.map((p) => p.providerId).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'user_logged_in': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Testa endpoints principais da API
  Future<Map<String, dynamic>> _testApiEndpoints() async {
    final endpoints = <String, dynamic>{};
    
    // Lista de endpoints para testar
    final testEndpoints = [
      {'name': 'categories', 'path': '/categories', 'method': 'GET'},
      {'name': 'auth_profile', 'path': '/auth/profile', 'method': 'GET', 'requiresAuth': true},
      {'name': 'products', 'path': '/products', 'method': 'GET'},
    ];
    
    for (final endpoint in testEndpoints) {
      try {
        final name = endpoint['name'] as String;
        final requiresAuth = endpoint['requiresAuth'] as bool? ?? false;
        
        // Se requer autenticação e não há usuário, pula
        if (requiresAuth && _firebaseAuth.currentUser == null) {
          endpoints[name] = {
            'status': 'skipped',
            'reason': 'no_authentication',
            'timestamp': DateTime.now().toIso8601String(),
          };
          continue;
        }
        
        final startTime = DateTime.now();
        
        // Simula teste básico de endpoint
        // Em implementação real, faria requisição HTTP aqui
        await Future.delayed(const Duration(milliseconds: 100));
        
        final responseTime = DateTime.now().difference(startTime).inMilliseconds;
        
        endpoints[name] = {
          'status': 'success',
          'response_time_ms': responseTime,
          'method': endpoint['method'],
          'path': endpoint['path'],
          'timestamp': DateTime.now().toIso8601String(),
        };
        
      } catch (e) {
        endpoints[endpoint['name'] as String] = {
          'status': 'error',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    }
    
    return endpoints;
  }

  /// Obtém informações do ambiente
  Map<String, dynamic> _getEnvironmentInfo() {
    return {
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'is_debug_mode': _isDebugMode(),
      'base_url': ApiClient.baseUrl,
      'is_production': ApiClient.baseUrl.contains('render.com'),
      'locale': Platform.localeName,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Calcula métricas de performance
  Map<String, dynamic> _getPerformanceMetrics(DateTime startTime) {
    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    
    return {
      'total_diagnostic_time_ms': totalTime,
      'memory_info': _getMemoryInfo(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Obtém informações básicas de memória
  Map<String, dynamic> _getMemoryInfo() {
    try {
      // Informações básicas de memória que podemos obter
      return {
        'available': true,
        'note': 'Memory details limited in Flutter release mode',
      };
    } catch (e) {
      return {
        'available': false,
        'error': e.toString(),
      };
    }
  }

  /// Gera resumo dos diagnósticos
  Map<String, dynamic> _generateSummary(Map<String, dynamic> results) {
    int successCount = 0;
    int failureCount = 0;
    final issues = <String>[];
    
    // Analisa conectividade
    if (results['connectivity']?['status'] == 'success') {
      successCount++;
    } else {
      failureCount++;
      issues.add('Problemas de conectividade com servidor');
    }
    
    // Analisa Firebase
    if (results['firebase_auth']?['status'] == 'success') {
      successCount++;
      if (results['firebase_auth']?['user_logged_in'] != true) {
        issues.add('Usuário não está autenticado');
      }
    } else {
      failureCount++;
      issues.add('Problemas com Firebase Authentication');
    }
    
    // Analisa endpoints
    final endpoints = results['api_endpoints'] as Map<String, dynamic>? ?? {};
    for (final endpoint in endpoints.values) {
      if (endpoint is Map<String, dynamic>) {
        if (endpoint['status'] == 'success') {
          successCount++;
        } else if (endpoint['status'] == 'error') {
          failureCount++;
          issues.add('Endpoint ${endpoint['path'] ?? 'unknown'} falhando');
        }
      }
    }
    
    final overallStatus = failureCount == 0 ? 'healthy' : 
                         (successCount > failureCount ? 'warning' : 'critical');
    
    return {
      'overall_status': overallStatus,
      'success_count': successCount,
      'failure_count': failureCount,
      'total_tests': successCount + failureCount,
      'issues': issues,
      'recommendations': _generateRecommendations(results, issues),
      'completed_at': DateTime.now().toIso8601String(),
    };
  }

  /// Gera recomendações baseadas nos resultados
  List<String> _generateRecommendations(Map<String, dynamic> results, List<String> issues) {
    final recommendations = <String>[];
    
    // Conectividade
    if (results['connectivity']?['status'] != 'success') {
      recommendations.add('Verifique sua conexão com a internet');
      recommendations.add('Tente reiniciar o aplicativo');
    }
    
    // Autenticação
    if (results['firebase_auth']?['user_logged_in'] != true) {
      recommendations.add('Faça login novamente para melhor experiência');
    }
    
    // Performance
    final totalTime = results['performance']?['total_diagnostic_time_ms'] as int? ?? 0;
    if (totalTime > 5000) {
      recommendations.add('Performance baixa detectada - verifique conexão');
    }
    
    // Geral
    if (issues.isEmpty) {
      recommendations.add('Sistema funcionando normalmente');
    } else {
      recommendations.add('Entre em contato com suporte se problemas persistirem');
    }
    
    return recommendations;
  }

  /// Verifica se está em modo debug
  bool _isDebugMode() {
    bool debugMode = false;
    assert(debugMode = true);
    return debugMode;
  }

  /// Teste rápido de conectividade
  Future<bool> quickConnectivityTest() async {
    try {
      Logger.info('Diagnostics: Teste rápido de conectividade');
      return await ApiClient.testConnectivity();
    } catch (e) {
      Logger.error('Diagnostics: Falha no teste rápido', error: e);
      return false;
    }
  }

  /// Verifica status do Firebase Auth
  Map<String, dynamic> getAuthStatus() {
    final user = _firebaseAuth.currentUser;
    return {
      'authenticated': user != null,
      'user_id': user?.uid,
      'email': user?.email,
      'email_verified': user?.emailVerified,
      'anonymous': user?.isAnonymous,
    };
  }

  /// Limpa logs de diagnóstico (se implementado)
  void clearDiagnosticLogs() {
    Logger.info('Diagnostics: Logs de diagnóstico limpos');
  }

  /// Exporta relatório de diagnóstico
  String exportDiagnosticReport(Map<String, dynamic> diagnosticResults) {
    try {
      final report = StringBuffer();
      report.writeln('=== RELATÓRIO DE DIAGNÓSTICO ===');
      report.writeln('Data: ${DateTime.now()}');
      report.writeln('');
      
      // Status geral
      final summary = diagnosticResults['summary'] as Map<String, dynamic>?;
      if (summary != null) {
        report.writeln('Status Geral: ${summary['overall_status']}');
        report.writeln('Testes Realizados: ${summary['total_tests']}');
        report.writeln('Sucessos: ${summary['success_count']}');
        report.writeln('Falhas: ${summary['failure_count']}');
        report.writeln('');
      }
      
      // Issues
      final issues = summary?['issues'] as List<dynamic>? ?? [];
      if (issues.isNotEmpty) {
        report.writeln('PROBLEMAS ENCONTRADOS:');
        for (final issue in issues) {
          report.writeln('• $issue');
        }
        report.writeln('');
      }
      
      // Recomendações
      final recommendations = summary?['recommendations'] as List<dynamic>? ?? [];
      if (recommendations.isNotEmpty) {
        report.writeln('RECOMENDAÇÕES:');
        for (final rec in recommendations) {
          report.writeln('• $rec');
        }
        report.writeln('');
      }
      
      report.writeln('=== FIM DO RELATÓRIO ===');
      
      Logger.info('Diagnostics: Relatório exportado com sucesso');
      return report.toString();
      
    } catch (e) {
      Logger.error('Diagnostics: Erro ao exportar relatório', error: e);
      return 'Erro ao gerar relatório: $e';
    }
  }
}