// lib/screens/admin/services/admin_data_service.dart

import '../../../providers/auth_provider.dart';
import '../../../utils/logger.dart';

class AdminDataService {
  
  /// Obtém o ID do usuário atual
  String? getCurrentUserId(AuthProvider authProvider) {
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      Logger.error('AdminDataService: Usuário não autenticado');
    }
    return userId;
  }

  /// Valida se o usuário está autenticado
  bool validateAuthentication(AuthProvider authProvider) {
    return getCurrentUserId(authProvider) != null;
  }

  /// Calcula as métricas do dashboard
  Map<String, dynamic> calculateDashboardMetrics({
    required List<dynamic> products,
    required List<dynamic> orders,
  }) {
    final totalProducts = products.length;
    final totalOrders = orders.length;
    final pendingOrders = orders.where((o) => o.status == 'pending').length;
    final confirmedOrders = orders.where((o) => o.status == 'confirmed').length;
    final deliveredOrders = orders.where((o) => ['completed', 'delivered'].contains(o.status)).length;
    
    final totalRevenue = orders
        .where((o) => ['confirmed', 'completed', 'delivered'].contains(o.status))
        .fold(0.0, (sum, order) => sum + order.totalAmount);

    final pendingRevenue = orders
        .where((o) => o.status == 'pending')
        .fold(0.0, (sum, order) => sum + order.totalAmount);

    // Produtos com estoque baixo (menos de 5 unidades)
    final lowStockProducts = products.where((p) => p.stockQuantity > 0 && p.stockQuantity < 5).length;
    
    // Produtos sem estoque
    final outOfStockProducts = products.where((p) => p.stockQuantity == 0).length;

    Logger.info('AdminDataService: Métricas calculadas - $totalProducts produtos, $totalOrders pedidos, R\$ ${totalRevenue.toStringAsFixed(2)} receita');

    return {
      'totalProducts': totalProducts,
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'confirmedOrders': confirmedOrders,
      'deliveredOrders': deliveredOrders,
      'totalRevenue': totalRevenue,
      'pendingRevenue': pendingRevenue,
      'lowStockProducts': lowStockProducts,
      'outOfStockProducts': outOfStockProducts,
    };
  }

  /// Calcula estatísticas detalhadas dos pedidos
  Map<String, dynamic> calculateOrderStats(List<dynamic> orders) {
    final Map<String, int> statusCounts = {
      'pending': 0,
      'confirmed': 0,
      'delivered': 0,
      'cancelled': 0,
    };

    final Map<String, double> statusRevenue = {
      'pending': 0.0,
      'confirmed': 0.0,
      'delivered': 0.0,
      'cancelled': 0.0,
    };

    for (final order in orders) {
      final status = order.status ?? 'unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      statusRevenue[status] = (statusRevenue[status] ?? 0.0) + order.totalAmount;
    }

    // Pedidos com comprovante PIX
    final pixWithProofCount = orders.where((o) => 
      o.payment_method == 'pix' && 
      o.payment_proof_url != null && 
      o.payment_proof_url!.isNotEmpty
    ).length;

    // Pedidos PIX sem comprovante
    final pixWithoutProofCount = orders.where((o) => 
      o.payment_method == 'pix' && 
      (o.payment_proof_url == null || o.payment_proof_url!.isEmpty)
    ).length;

    Logger.info('AdminDataService: Estatísticas de pedidos calculadas');

    return {
      'statusCounts': statusCounts,
      'statusRevenue': statusRevenue,
      'pixWithProofCount': pixWithProofCount,
      'pixWithoutProofCount': pixWithoutProofCount,
      'totalOrders': orders.length,
    };
  }

  /// Calcula estatísticas dos produtos
  Map<String, dynamic> calculateProductStats(List<dynamic> products) {
    final totalProducts = products.length;
    final activeProducts = products.where((p) => p.isActive == true).length;
    final inactiveProducts = totalProducts - activeProducts;
    
    final inStockProducts = products.where((p) => p.stockQuantity > 0).length;
    final outOfStockProducts = products.where((p) => p.stockQuantity == 0).length;
    final lowStockProducts = products.where((p) => p.stockQuantity > 0 && p.stockQuantity < 5).length;

    final totalStockValue = products
        .where((p) => p.stockQuantity > 0)
        .fold(0.0, (sum, product) => sum + (product.price * product.stockQuantity));

    // Agrupar produtos por categoria
    final Map<String, int> categoryDistribution = {};
    for (final product in products) {
      final categoryId = product.categoryId ?? 'sem_categoria';
      categoryDistribution[categoryId] = (categoryDistribution[categoryId] ?? 0) + 1;
    }

    Logger.info('AdminDataService: Estatísticas de produtos calculadas');

    return {
      'totalProducts': totalProducts,
      'activeProducts': activeProducts,
      'inactiveProducts': inactiveProducts,
      'inStockProducts': inStockProducts,
      'outOfStockProducts': outOfStockProducts,
      'lowStockProducts': lowStockProducts,
      'totalStockValue': totalStockValue,
      'categoryDistribution': categoryDistribution,
    };
  }

  /// Verifica se há alertas importantes para mostrar no dashboard
  List<Map<String, dynamic>> getImportantAlerts({
    required List<dynamic> products,
    required List<dynamic> orders,
  }) {
    final alerts = <Map<String, dynamic>>[];

    // Alerta de produtos sem estoque
    final outOfStockCount = products.where((p) => p.stockQuantity == 0).length;
    if (outOfStockCount > 0) {
      alerts.add({
        'type': 'warning',
        'icon': 'inventory_2',
        'title': 'Produtos sem estoque',
        'message': '$outOfStockCount ${outOfStockCount == 1 ? 'produto está' : 'produtos estão'} sem estoque',
        'color': 'orange',
      });
    }

    // Alerta de produtos com estoque baixo
    final lowStockCount = products.where((p) => p.stockQuantity > 0 && p.stockQuantity < 5).length;
    if (lowStockCount > 0) {
      alerts.add({
        'type': 'info',
        'icon': 'warning',
        'title': 'Estoque baixo',
        'message': '$lowStockCount ${lowStockCount == 1 ? 'produto tem' : 'produtos têm'} estoque baixo',
        'color': 'yellow',
      });
    }

    // Alerta de pedidos pendentes
    final pendingOrdersCount = orders.where((o) => o.status == 'pending').length;
    if (pendingOrdersCount > 0) {
      alerts.add({
        'type': 'info',
        'icon': 'pending_actions',
        'title': 'Pedidos pendentes',
        'message': '$pendingOrdersCount ${pendingOrdersCount == 1 ? 'pedido precisa' : 'pedidos precisam'} de atenção',
        'color': 'blue',
      });
    }

    // Alerta de pedidos PIX sem comprovante
    final pixWithoutProofCount = orders.where((o) => 
      o.payment_method == 'pix' && 
      (o.payment_proof_url == null || o.payment_proof_url!.isEmpty)
    ).length;
    if (pixWithoutProofCount > 0) {
      alerts.add({
        'type': 'warning',
        'icon': 'receipt',
        'title': 'PIX sem comprovante',
        'message': '$pixWithoutProofCount ${pixWithoutProofCount == 1 ? 'pedido PIX aguarda' : 'pedidos PIX aguardam'} comprovante',
        'color': 'orange',
      });
    }

    Logger.info('AdminDataService: ${alerts.length} alertas identificados');
    return alerts;
  }

  /// Formata valores monetários
  String formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Formata porcentagens
  String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }
}