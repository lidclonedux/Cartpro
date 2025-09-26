// lib/services/api_modules/orders/order_status_service.dart
import '../core/api_exceptions.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

enum OrderStatus {
  pending('pending', 'Pendente', 'Pedido criado, aguardando processamento'),
  confirmed('confirmed', 'Confirmado', 'Pedido confirmado pelo vendedor'),
  preparing('preparing', 'Preparando', 'Pedido sendo preparado'),
  ready('ready', 'Pronto', 'Pedido pronto para entrega/retirada'),
  shipping('shipping', 'Enviando', 'Pedido em transporte'),
  delivered('delivered', 'Entregue', 'Pedido entregue ao cliente'),
  cancelled('cancelled', 'Cancelado', 'Pedido cancelado'),
  returned('returned', 'Devolvido', 'Pedido devolvido pelo cliente');

  const OrderStatus(this.value, this.displayName, this.description);
  
  final String value;
  final String displayName;
  final String description;
}

class OrderStatusService {
  /// Lista de status válidos
  static const List<String> validStatuses = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'shipping',
    'delivered',
    'cancelled',
    'returned',
  ];

  /// Status que permitem cancelamento pelo cliente
  static const List<String> cancellableStatuses = [
    'pending',
    'confirmed',
  ];

  /// Status que indicam que o pedido foi finalizado
  static const List<String> finalStatuses = [
    'delivered',
    'cancelled',
    'returned',
  ];

  /// Status que indicam que o pedido está ativo
  static const List<String> activeStatuses = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'shipping',
  ];

  /// Valida se um status é válido
  static bool isValidStatus(String status) {
    return validStatuses.contains(status.toLowerCase());
  }

  /// Verifica se um pedido pode ser cancelado pelo cliente
  static bool canBeCancelledByCustomer(String currentStatus) {
    return cancellableStatuses.contains(currentStatus.toLowerCase());
  }

  /// Verifica se um pedido está finalizado
  static bool isFinalized(String status) {
    return finalStatuses.contains(status.toLowerCase());
  }

  /// Verifica se um pedido está ativo
  static bool isActive(String status) {
    return activeStatuses.contains(status.toLowerCase());
  }

  /// Obtém o próximo status válido na sequência
  static String? getNextStatus(String currentStatus) {
    final status = currentStatus.toLowerCase();
    
    switch (status) {
      case 'pending':
        return 'confirmed';
      case 'confirmed':
        return 'preparing';
      case 'preparing':
        return 'ready';
      case 'ready':
        return 'shipping';
      case 'shipping':
        return 'delivered';
      default:
        return null; // Status final ou inválido
    }
  }

  /// Obtém todos os status possíveis a partir do atual
  static List<String> getPossibleNextStatuses(String currentStatus, {bool isAdmin = false}) {
    final status = currentStatus.toLowerCase();
    final possibleStatuses = <String>[];
    
    if (isAdmin) {
      // Admin pode mover para qualquer status (exceto alguns casos específicos)
      switch (status) {
        case 'pending':
          possibleStatuses.addAll(['confirmed', 'cancelled']);
          break;
        case 'confirmed':
          possibleStatuses.addAll(['preparing', 'cancelled']);
          break;
        case 'preparing':
          possibleStatuses.addAll(['ready', 'cancelled']);
          break;
        case 'ready':
          possibleStatuses.addAll(['shipping', 'delivered']);
          break;
        case 'shipping':
          possibleStatuses.addAll(['delivered', 'returned']);
          break;
        case 'delivered':
          possibleStatuses.add('returned');
          break;
        // Status finais não podem ser alterados
        case 'cancelled':
        case 'returned':
          break;
      }
    } else {
      // Cliente tem opções limitadas
      if (canBeCancelledByCustomer(status)) {
        possibleStatuses.add('cancelled');
      }
    }
    
    return possibleStatuses;
  }

  /// Valida transição de status
  static void validateStatusTransition(
    String fromStatus,
    String toStatus, {
    bool isAdmin = false,
  }) {
    Logger.info('OrderStatusService: Validando transição $fromStatus -> $toStatus (admin: $isAdmin)');
    
    if (!isValidStatus(fromStatus)) {
      throw ValidationException('Status atual inválido: $fromStatus');
    }
    
    if (!isValidStatus(toStatus)) {
      throw ValidationException('Novo status inválido: $toStatus');
    }
    
    // Não pode alterar status finalizado
    if (isFinalized(fromStatus)) {
      throw ValidationException('Não é possível alterar pedido com status: ${getDisplayName(fromStatus)}');
    }
    
    // Verifica se a transição é permitida
    final possibleStatuses = getPossibleNextStatuses(fromStatus, isAdmin: isAdmin);
    
    if (!possibleStatuses.contains(toStatus)) {
      final allowedText = possibleStatuses.isEmpty 
        ? 'nenhuma alteração permitida'
        : 'alterações permitidas: ${possibleStatuses.join(', ')}';
      throw ValidationException(
        'Transição de ${getDisplayName(fromStatus)} para ${getDisplayName(toStatus)} não é permitida. $allowedText'
      );
    }
    
    Logger.info('OrderStatusService: Transição validada com sucesso');
  }

  /// Obtém o nome de exibição do status
  static String getDisplayName(String status) {
    final statusEnum = OrderStatus.values.where((s) => s.value == status.toLowerCase()).firstOrNull;
    return statusEnum?.displayName ?? status;
  }

  /// Obtém a descrição do status
  static String getDescription(String status) {
    final statusEnum = OrderStatus.values.where((s) => s.value == status.toLowerCase()).firstOrNull;
    return statusEnum?.description ?? 'Status desconhecido';
  }

  /// Obtém a cor associada ao status (para UI)
  static String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '#FFA500'; // Orange
      case 'confirmed':
        return '#007BFF'; // Blue
      case 'preparing':
        return '#17A2B8'; // Info blue
      case 'ready':
        return '#28A745'; // Green
      case 'shipping':
        return '#6F42C1'; // Purple
      case 'delivered':
        return '#20C997'; // Teal
      case 'cancelled':
        return '#DC3545'; // Red
      case 'returned':
        return '#6C757D'; // Gray
      default:
        return '#6C757D'; // Default gray
    }
  }

  /// Obtém o ícone associado ao status
  static String getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'clock';
      case 'confirmed':
        return 'check-circle';
      case 'preparing':
        return 'tool';
      case 'ready':
        return 'package';
      case 'shipping':
        return 'truck';
      case 'delivered':
        return 'check-square';
      case 'cancelled':
        return 'x-circle';
      case 'returned':
        return 'rotate-ccw';
      default:
        return 'help-circle';
    }
  }

  /// Calcula progresso do pedido (0-100)
  static int getProgressPercentage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 10;
      case 'confirmed':
        return 25;
      case 'preparing':
        return 50;
      case 'ready':
        return 75;
      case 'shipping':
        return 90;
      case 'delivered':
        return 100;
      case 'cancelled':
        return 0;
      case 'returned':
        return 0;
      default:
        return 0;
    }
  }

  /// Verifica se é um status de sucesso
  static bool isSuccessStatus(String status) {
    return status.toLowerCase() == 'delivered';
  }

  /// Verifica se é um status de falha
  static bool isFailureStatus(String status) {
    return ['cancelled', 'returned'].contains(status.toLowerCase());
  }

  /// Obtém informações completas do status
  static Map<String, dynamic> getStatusInfo(String status) {
    return {
      'value': status.toLowerCase(),
      'display_name': getDisplayName(status),
      'description': getDescription(status),
      'color': getStatusColor(status),
      'icon': getStatusIcon(status),
      'progress': getProgressPercentage(status),
      'is_active': isActive(status),
      'is_finalized': isFinalized(status),
      'can_be_cancelled_by_customer': canBeCancelledByCustomer(status),
      'is_success': isSuccessStatus(status),
      'is_failure': isFailureStatus(status),
    };
  }

  /// Lista todos os status com informações para UI
  static List<Map<String, dynamic>> getAllStatusInfo() {
    return validStatuses.map((status) => getStatusInfo(status)).toList();
  }

  /// Obtém histórico de mudanças de status formatado
  static List<Map<String, dynamic>> formatStatusHistory(List<dynamic> history) {
    try {
      return history.map((item) {
        final statusValue = item['status']?.toString() ?? 'unknown';
        final timestamp = item['timestamp']?.toString() ?? '';
        final changedBy = item['changed_by']?.toString() ?? 'Sistema';
        final notes = item['notes']?.toString() ?? '';
        
        return {
          ...getStatusInfo(statusValue),
          'timestamp': timestamp,
          'changed_by': changedBy,
          'notes': notes,
          'formatted_date': _formatTimestamp(timestamp),
        };
      }).toList();
    } catch (e) {
      Logger.error('OrderStatusService: Erro ao formatar histórico', error: e);
      return [];
    }
  }

  /// Formata timestamp para exibição
  static String _formatTimestamp(String timestamp) {
    try {
      if (timestamp.isEmpty) return 'Data não disponível';
      
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} dia${difference.inDays > 1 ? 's' : ''} atrás';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hora${difference.inHours > 1 ? 's' : ''} atrás';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''} atrás';
      } else {
        return 'Agora mesmo';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// Obtém sugestão de próxima ação baseada no status
  static String getNextActionSuggestion(String status, {bool isAdmin = false}) {
    final statusLower = status.toLowerCase();
    
    if (!isAdmin) {
      // Sugestões para clientes
      switch (statusLower) {
        case 'pending':
          return 'Aguarde a confirmação do pedido pelo vendedor';
        case 'confirmed':
          return 'Seu pedido foi confirmado e está sendo preparado';
        case 'preparing':
          return 'Seu pedido está sendo preparado com carinho';
        case 'ready':
          return 'Seu pedido está pronto! Aguarde informações sobre entrega';
        case 'shipping':
          return 'Seu pedido está a caminho';
        case 'delivered':
          return 'Pedido entregue com sucesso! Como foi sua experiência?';
        case 'cancelled':
          return 'Pedido cancelado. Entre em contato se tiver dúvidas';
        case 'returned':
          return 'Produto devolvido. O reembolso será processado';
        default:
          return 'Acompanhe as atualizações do seu pedido';
      }
    } else {
      // Sugestões para administradores
      switch (statusLower) {
        case 'pending':
          return 'Revisar e confirmar o pedido';
        case 'confirmed':
          return 'Iniciar preparação do pedido';
        case 'preparing':
          return 'Finalizar preparação e marcar como pronto';
        case 'ready':
          return 'Organizar entrega ou notificar cliente para retirada';
        case 'shipping':
          return 'Confirmar entrega quando concluída';
        case 'delivered':
          return 'Pedido concluído com sucesso';
        case 'cancelled':
          return 'Verificar motivo do cancelamento';
        case 'returned':
          return 'Processar devolução e reembolso';
        default:
          return 'Verificar status do pedido';
      }
    }
  }

  /// Valida dados de atualização de status
  static void validateStatusUpdateData(Map<String, dynamic> data) {
    if (!data.containsKey('status') || data['status'] == null) {
      throw ValidationException('Campo status é obrigatório');
    }
    
    final status = data['status'].toString();
    if (!isValidStatus(status)) {
      throw ValidationException('Status inválido: $status');
    }
    
    // Validações adicionais podem ser adicionadas aqui
    Logger.info('OrderStatusService: Dados de atualização validados');
  }

  /// Cria dados de log para mudança de status
  static Map<String, dynamic> createStatusChangeLog({
    required String orderId,
    required String fromStatus,
    required String toStatus,
    required String changedBy,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'order_id': orderId,
      'from_status': fromStatus,
      'to_status': toStatus,
      'changed_by': changedBy,
      'notes': notes ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata ?? {},
    };
  }
}