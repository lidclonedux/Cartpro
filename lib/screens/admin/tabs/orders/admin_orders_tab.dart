import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../../providers/order_provider.dart';

// Models
import '../../../../models/order.dart';

// Widgets
import '../../widgets/admin_base_widget.dart';
import '../../widgets/admin_snackbar_utils.dart';
import 'widgets/order_card.dart';
import 'widgets/order_status_badge.dart';
import 'dialogs/payment_proof_dialog.dart';

// Utils
import '../../../../utils/logger.dart';

class AdminOrdersTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminOrdersTab({super.key, required this.onRefresh});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> with AutomaticKeepAliveClientMixin {
  String _selectedStatusFilter = 'all';
  String _selectedPaymentFilter = 'all';
  String _sortBy = 'date_desc';
  bool _isInitialLoad = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Logger.info('AdminOrdersTab.initState: Inicializando tab de pedidos admin');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    try {
      Logger.info('AdminOrdersTab._loadOrders: Carregando pedidos');
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchOrders();
      
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
      
      Logger.info('AdminOrdersTab._loadOrders: Carregamento concluído');
    } catch (e) {
      Logger.error('AdminOrdersTab._loadOrders: Erro', error: e);
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Para manter o estado da tab
    
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        // CORREÇÃO: Verifica loading apenas no carregamento inicial
        if (orderProvider.isLoading && _isInitialLoad) {
          Logger.debug('AdminOrdersTab: Exibindo loading inicial');
          return AdminBaseWidget.buildLoadingState('Carregando pedidos...');
        }

        // CORREÇÃO: Verifica erro antes de processar dados
        if (orderProvider.errorMessage != null) {
          Logger.error('AdminOrdersTab: Erro: ${orderProvider.errorMessage}');
          return _buildErrorState(orderProvider);
        }

        // CORREÇÃO: Filtra pedidos válidos antes de processar
        final validOrders = orderProvider.orders.where((order) => order.isValid).toList();
        final filteredOrders = _getFilteredOrders(validOrders);

        if (validOrders.isEmpty && !orderProvider.isLoading) {
          Logger.info('AdminOrdersTab: Nenhum pedido encontrado');
          return _buildEmptyState();
        }

        return Column(
          children: [
            _buildFilterSection(),
            _buildOrdersHeader(filteredOrders, validOrders),
            Expanded(
              child: filteredOrders.isEmpty
                  ? _buildNoResultsState()
                  : _buildOrdersList(filteredOrders, orderProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(OrderProvider orderProvider) {
    return AdminBaseWidget.buildEmptyStateAdvanced(
      icon: Icons.error_outline,
      title: 'Erro ao carregar pedidos',
      subtitle: orderProvider.errorMessage ?? 'Erro desconhecido',
      action: AdminBaseWidget.buildActionButton(
        label: 'Tentar Novamente',
        icon: Icons.refresh,
        backgroundColor: const Color(0xFF9147FF),
        onPressed: () {
          Logger.info('AdminOrdersTab: Tentativa de recarregamento após erro');
          orderProvider.clearError();
          _loadOrders();
        },
      ),
    );
  }

  List<Order> _getFilteredOrders(List<Order> orders) {
    var filteredOrders = orders.where((order) {
      // Filtro por status
      if (_selectedStatusFilter != 'all' && order.status != _selectedStatusFilter) {
        return false;
      }

      // Filtro por método de pagamento
      if (_selectedPaymentFilter != 'all') {
        switch (_selectedPaymentFilter) {
          case 'pix':
            if (order.payment_method != 'pix') return false;
            break;
          case 'pix_with_proof':
            if (order.payment_method != 'pix' || !order.hasPaymentProof) return false;
            break;
          case 'pix_without_proof':
            if (order.payment_method != 'pix' || order.hasPaymentProof) return false;
            break;
          case 'negotiable':
            if (order.payment_method == 'pix') return false;
            break;
        }
      }

      return true;
    }).toList();

    // Ordenação
    filteredOrders.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return a.createdAt.compareTo(b.createdAt);
        case 'value_desc':
          return b.totalAmount.compareTo(a.totalAmount);
        case 'value_asc':
          return a.totalAmount.compareTo(b.totalAmount);
        case 'date_desc':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filteredOrders;
  }

  Widget _buildEmptyState() {
    return AdminBaseWidget.buildEmptyStateAdvanced(
      icon: Icons.shopping_bag_outlined,
      title: 'Nenhum pedido encontrado',
      subtitle: 'Os pedidos dos clientes aparecerão aqui quando realizados.\nPuxe para baixo para atualizar.',
      action: AdminBaseWidget.buildActionButton(
        label: 'Atualizar Agora',
        icon: Icons.refresh,
        backgroundColor: const Color(0xFF9147FF),
        onPressed: () {
          Logger.info('AdminOrdersTab: Atualização manual solicitada');
          _loadOrders();
        },
      ),
    );
  }

  Widget _buildNoResultsState() {
    return AdminBaseWidget.buildEmptyStateAdvanced(
      icon: Icons.search_off,
      title: 'Nenhum pedido corresponde aos filtros',
      subtitle: 'Tente ajustar os filtros para encontrar pedidos.',
      action: AdminBaseWidget.buildActionButton(
        label: 'Limpar Filtros',
        icon: Icons.clear,
        backgroundColor: Colors.orange,
        onPressed: () {
          setState(() {
            _selectedStatusFilter = 'all';
            _selectedPaymentFilter = 'all';
            _sortBy = 'date_desc';
          });
          Logger.info('AdminOrdersTab: Filtros limpos');
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return AdminBaseWidget.buildCard(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Primeira linha de filtros
          Row(
            children: [
              // Filtro por status
              Expanded(
                child: _buildDropdown(
                  label: 'Status',
                  value: _selectedStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos os status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pendente')),
                    DropdownMenuItem(value: 'confirmed', child: Text('Confirmado')),
                    DropdownMenuItem(value: 'delivered', child: Text('Entregue')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelado')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedStatusFilter = value ?? 'all');
                    Logger.debug('AdminOrdersTab: Filtro de status alterado para: $value');
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Filtro por pagamento
              Expanded(
                child: _buildDropdown(
                  label: 'Pagamento',
                  value: _selectedPaymentFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                    DropdownMenuItem(value: 'pix', child: Text('PIX')),
                    DropdownMenuItem(value: 'pix_with_proof', child: Text('PIX c/ comprovante')),
                    DropdownMenuItem(value: 'pix_without_proof', child: Text('PIX s/ comprovante')),
                    DropdownMenuItem(value: 'negotiable', child: Text('A combinar')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPaymentFilter = value ?? 'all');
                    Logger.debug('AdminOrdersTab: Filtro de pagamento alterado para: $value');
                  },
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24, height: 1),
          ),
          // Segunda linha - Ordenação
          Row(
            children: [
              const Icon(Icons.sort, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Ordenar por:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: null,
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'date_desc', child: Text('Mais recentes')),
                    DropdownMenuItem(value: 'date_asc', child: Text('Mais antigos')),
                    DropdownMenuItem(value: 'value_desc', child: Text('Maior valor')),
                    DropdownMenuItem(value: 'value_asc', child: Text('Menor valor')),
                  ],
                  onChanged: (value) {
                    setState(() => _sortBy = value ?? 'date_desc');
                    Logger.debug('AdminOrdersTab: Ordenação alterada para: $value');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF2C2F33),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildOrdersHeader(List<Order> filteredOrders, List<Order> allOrders) {
    final pendingCount = filteredOrders.where((o) => o.status == 'pending').length;
    final totalValue = filteredOrders.fold(0.0, (sum, order) => sum + order.totalAmount);

    return AdminBaseWidget.buildCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Informações dos pedidos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${filteredOrders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      filteredOrders.length == 1 ? 'pedido' : 'pedidos',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (filteredOrders.length != allOrders.length) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withOpacity(0.5)),
                        ),
                        child: Text(
                          'de ${allOrders.length}',
                          style: const TextStyle(color: Colors.blue, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$pendingCount pendente${pendingCount != 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Valor total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${totalValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF9147FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Text(
                'Valor total',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders, OrderProvider orderProvider) {
    return RefreshIndicator(
      onRefresh: () {
        Logger.info('AdminOrdersTab: Pull-to-refresh ativado');
        return _loadOrders();
      },
      color: const Color(0xFF9147FF),
      backgroundColor: const Color(0xFF23272A),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCard(
            order: order,
            onStatusUpdate: (newStatus) => _updateOrderStatus(order.id, newStatus, orderProvider),
            onViewProof: order.hasPaymentProof
                ? () => _showPaymentProofDialog(order.payment_proof_url!)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, OrderProvider orderProvider) async {
    Logger.info('AdminOrdersTab: Atualizando status do pedido $orderId para "$newStatus"');
    
    // Mostrar indicador de carregamento
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text('Atualizando pedido para "$newStatus"...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    try {
      final success = await orderProvider.updateOrderStatus(orderId, newStatus);
      
      if (mounted) {
        // Remover snackbar anterior
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        
        if (success) {
          Logger.info('AdminOrdersTab: Status atualizado com sucesso para "$newStatus"');
          AdminSnackBarUtils.showSuccess(
            context, 
            'Status do pedido atualizado para "$newStatus" com sucesso!'
          );
        } else {
          Logger.error('AdminOrdersTab: Falha ao atualizar status');
          AdminSnackBarUtils.showError(
            context, 
            orderProvider.errorMessage ?? 'Erro ao atualizar status do pedido',
            onRetry: () => _updateOrderStatus(orderId, newStatus, orderProvider),
          );
        }
      }
    } catch (e) {
      Logger.error('AdminOrdersTab: Exceção ao atualizar status', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        AdminSnackBarUtils.showError(
          context, 
          'Erro inesperado: ${e.toString()}',
          onRetry: () => _updateOrderStatus(orderId, newStatus, orderProvider),
        );
      }
    }
  }

  void _showPaymentProofDialog(String imageUrl) {
    Logger.info('AdminOrdersTab: Exibindo comprovante de pagamento');
    PaymentProofDialog.show(context, imageUrl);
  }

  @override
  void dispose() {
    Logger.info('AdminOrdersTab.dispose: Finalizando tab de pedidos admin');
    super.dispose();
  }
}
