// lib/utils/logger.dart - VERSÃO CORRIGIDA PARA ACEITAR PARÂMETRO ERROR

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  static const String _appPrefix = 'VitrineBorracharia';
  
  // Mantém sua estrutura original, mas com melhorias
  static void log(String message, {
    LogLevel level = LogLevel.info, 
    Object? error, 
    StackTrace? stackTrace,
    String? tag
  }) {
    if (kDebugMode) {
      String prefix;
      String emoji;
      
      switch (level) {
        case LogLevel.debug:
          prefix = '[DEBUG]';
          emoji = '🔧';
          break;
        case LogLevel.info:
          prefix = '[INFO]';
          emoji = 'ℹ️';
          break;
        case LogLevel.warning:
          prefix = '[WARNING]';
          emoji = '⚠️';
          break;
        case LogLevel.error:
          prefix = '[ERROR]';
          emoji = '❌';
          break;
      }
      
      final tagStr = tag != null ? '[$tag] ' : '';
      print('$emoji $_appPrefix $prefix $tagStr$message');
      
      if (error != null) {
        print('  Error: $error');
      }
      if (stackTrace != null && level == LogLevel.error) {
        print('  StackTrace: $stackTrace');
      }
    }
  }

  // CORREÇÃO: Métodos agora aceitam parâmetro error
  static void debug(String message, {Object? error, StackTrace? stackTrace, String? tag}) => 
      log(message, level: LogLevel.debug, error: error, stackTrace: stackTrace, tag: tag);
      
  static void info(String message, {Object? error, StackTrace? stackTrace, String? tag}) => 
      log(message, level: LogLevel.info, error: error, stackTrace: stackTrace, tag: tag);
      
  // CORREÇÃO PRINCIPAL: warning agora aceita parâmetro error
  static void warning(String message, {Object? error, StackTrace? stackTrace, String? tag}) => 
      log(message, level: LogLevel.warning, error: error, stackTrace: stackTrace, tag: tag);
      
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) => 
      log(message, level: LogLevel.error, error: error, stackTrace: stackTrace, tag: tag);

  // Métodos específicos para o problema atual (API/Pedidos)
  
  static void apiRequest(String method, String url) {
    debug('[$method] $url', tag: 'API');
  }
  
  static void apiResponse(int statusCode, String url, {int? bodyLength}) {
    final lengthStr = bodyLength != null ? ' (${bodyLength} chars)' : '';
    if (statusCode >= 200 && statusCode < 300) {
      info('✅ [$statusCode] $url$lengthStr', tag: 'API');
    } else {
      warning('❌ [$statusCode] $url$lengthStr', tag: 'API');
    }
  }
  
  static void orderOperation(String operation, {String? orderId, Object? details}) {
    final orderStr = orderId != null ? ' - $orderId' : '';
    final detailsStr = details != null ? ' - $details' : '';
    info('$operation$orderStr$detailsStr', tag: 'ORDERS');
  }
  
  static void networkError(String url, Object error) {
    Logger.error('Network error for $url: $error', tag: 'NETWORK');
  }
  
  static void connectivityTest(String url, bool success, {Duration? duration}) {
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    if (success) {
      info('Connectivity OK: $url$durationStr', tag: 'NETWORK');
    } else {
      warning('Connectivity FAILED: $url$durationStr', tag: 'NETWORK');
    }
  }
  
  // Separador visual para organizar logs
  static void separator({String? title}) {
    if (kDebugMode) {
      final titleStr = title != null ? ' $title ' : '';
      print('🔷 $_appPrefix ═══════════════$titleStr═══════════════');
    }
  }
  
  // Log específico para início de operações importantes
  static void startOperation(String operation) {
    separator(title: operation.toUpperCase());
  }
  
  // Log de configuração de API
  static void logApiConfig(String baseUrl, String fullUrl) {
    separator(title: 'API CONFIG');
    info('Base URL: $baseUrl', tag: 'CONFIG');
    info('Full API URL: $fullUrl', tag: 'CONFIG');
    info('Debug Mode: ${kDebugMode}', tag: 'CONFIG');
    separator();
  }
}
