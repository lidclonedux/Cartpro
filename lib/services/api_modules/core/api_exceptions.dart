// lib/services/api_modules/core/api_exceptions.dart

/// Classe base para todas as exceções da API
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic originalError;

  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'ApiException: $message';
}

/// Exceção para erros de conectividade
class NetworkException extends ApiException {
  const NetworkException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          originalError: originalError,
        );

  @override
  String toString() => 'NetworkException: $message';
}

/// Exceção para timeout de requisições
class TimeoutException extends ApiException {
  final Duration timeout;

  const TimeoutException(
    String message,
    this.timeout, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          originalError: originalError,
        );

  @override
  String toString() => 'TimeoutException: $message (${timeout.inSeconds}s)';
}

/// Exceção para erros de autenticação (401)
class AuthenticationException extends ApiException {
  const AuthenticationException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          statusCode: 401,
          originalError: originalError,
        );

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Exceção para erros de autorização (403)
class AuthorizationException extends ApiException {
  const AuthorizationException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          statusCode: 403,
          originalError: originalError,
        );

  @override
  String toString() => 'AuthorizationException: $message';
}

/// Exceção para recursos não encontrados (404)
class NotFoundException extends ApiException {
  const NotFoundException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          statusCode: 404,
          originalError: originalError,
        );

  @override
  String toString() => 'NotFoundException: $message';
}

/// Exceção para erros de validação (400)
class ValidationException extends ApiException {
  final Map<String, dynamic>? validationErrors;

  const ValidationException(
    String message, {
    this.validationErrors,
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          statusCode: 400,
          originalError: originalError,
        );

  @override
  String toString() {
    if (validationErrors?.isNotEmpty == true) {
      return 'ValidationException: $message\nErrors: $validationErrors';
    }
    return 'ValidationException: $message';
  }
}

/// Exceção para erros do servidor (500+)
class ServerException extends ApiException {
  const ServerException(
    String message, {
    String? code,
    int? statusCode,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          statusCode: statusCode,
          originalError: originalError,
        );

  @override
  String toString() => 'ServerException: $message (${statusCode ?? 'unknown'})';
}

/// Exceção para erros de upload
class UploadException extends ApiException {
  final String? fileName;
  final int? fileSize;

  const UploadException(
    String message, {
    this.fileName,
    this.fileSize,
    String? code,
    int? statusCode,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          statusCode: statusCode,
          originalError: originalError,
        );

  @override
  String toString() {
    final details = <String>[];
    if (fileName != null) details.add('file: $fileName');
    if (fileSize != null) details.add('size: ${fileSize! ~/ 1024}KB');
    
    final detailsStr = details.isNotEmpty ? ' (${details.join(', ')})' : '';
    return 'UploadException: $message$detailsStr';
  }
}

/// Exceção para erros de Firebase
class FirebaseException extends ApiException {
  const FirebaseException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          originalError: originalError,
        );

  @override
  String toString() => 'FirebaseException: $message';
}

/// Exceção para dados inválidos ou corrompidos
class DataException extends ApiException {
  final String? field;

  const DataException(
    String message, {
    this.field,
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code,
          originalError: originalError,
        );

  @override
  String toString() {
    final fieldStr = field != null ? ' (field: $field)' : '';
    return 'DataException: $message$fieldStr';
  }
}

/// Utilitário para converter erros HTTP em exceções específicas
class ExceptionFactory {
  /// Cria exceção baseada no status code HTTP
  static ApiException fromHttpStatus(
    int statusCode,
    String message, {
    String? code,
    dynamic originalError,
  }) {
    switch (statusCode) {
      case 400:
        return ValidationException(message, code: code, originalError: originalError);
      case 401:
        return AuthenticationException(message, code: code, originalError: originalError);
      case 403:
        return AuthorizationException(message, code: code, originalError: originalError);
      case 404:
        return NotFoundException(message, code: code, originalError: originalError);
      case 408:
        return TimeoutException(message, const Duration(seconds: 30), code: code, originalError: originalError);
      case >= 500:
        return ServerException(message, code: code, statusCode: statusCode, originalError: originalError);
      default:
        return ApiException(message, code: code, statusCode: statusCode, originalError: originalError);
    }
  }

  /// Cria exceção de upload baseada no contexto
  static UploadException uploadError(
    String message, {
    String? fileName,
    int? fileSize,
    int? statusCode,
    String? code,
    dynamic originalError,
  }) {
    return UploadException(
      message,
      fileName: fileName,
      fileSize: fileSize,
      statusCode: statusCode,
      code: code,
      originalError: originalError,
    );
  }

  /// Cria exceção de rede baseada no tipo de erro
  static NetworkException networkError(
    String message, {
    String? code,
    dynamic originalError,
  }) {
    return NetworkException(
      message,
      code: code,
      originalError: originalError,
    );
  }

  /// Cria exceção de validação com detalhes
  static ValidationException validationError(
    String message, {
    Map<String, dynamic>? errors,
    String? code,
    dynamic originalError,
  }) {
    return ValidationException(
      message,
      validationErrors: errors,
      code: code,
      originalError: originalError,
    );
  }
}

/// Utilitário para tratamento de exceções
class ExceptionHandler {
  /// Converte exceção em mensagem amigável para o usuário
  static String getUserFriendlyMessage(Exception exception) {
    if (exception is NetworkException) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }
    
    if (exception is TimeoutException) {
      return 'Operação demorou mais que o esperado. Tente novamente.';
    }
    
    if (exception is AuthenticationException) {
      return 'Sua sessão expirou. Faça login novamente.';
    }
    
    if (exception is AuthorizationException) {
      return 'Você não tem permissão para realizar esta operação.';
    }
    
    if (exception is NotFoundException) {
      return 'Recurso não encontrado ou foi removido.';
    }
    
    if (exception is ValidationException) {
      return 'Dados inválidos. Verifique as informações e tente novamente.';
    }
    
    if (exception is UploadException) {
      return 'Erro no upload do arquivo. Tente com um arquivo menor.';
    }
    
    if (exception is ServerException) {
      return 'Erro no servidor. Tente novamente em alguns minutos.';
    }
    
    if (exception is FirebaseException) {
      return 'Erro de autenticação. Tente fazer login novamente.';
    }
    
    if (exception is ApiException) {
      return exception.message;
    }
    
    return 'Ocorreu um erro inesperado. Tente novamente.';
  }

  /// Verifica se é um erro que deve tentar novamente
  static bool shouldRetry(Exception exception) {
    if (exception is TimeoutException) return true;
    if (exception is NetworkException) return true;
    if (exception is ServerException) {
      // Retry apenas para erros 5xx temporários
      return exception.statusCode == null || exception.statusCode! >= 500;
    }
    return false;
  }

  /// Verifica se é um erro relacionado à autenticação
  static bool isAuthError(Exception exception) {
    return exception is AuthenticationException || 
           exception is AuthorizationException ||
           exception is FirebaseException;
  }
}