import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import necessário para formatação de datas
import '../providers/order_provider.dart';
import '../models/order.dart';
import '../utils/logger.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    Logger.info('MyOrdersScreen.initState: Tela inicializada');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserOrders();
    });
  }

  Future<void> _loadUserOrders() async {
    if (!mounted) return;

    try {
      Logger.info('MyOrdersScreen._loadUserOrders: Carregando pedidos');
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchUserOrders();

      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }

      Logger.info('MyOrdersScreen._loadUserOrders: Carregamento concluído');
    } catch (e) {
      Logger.error('MyOrdersScreen._loadUserOrders: Erro', error: e);
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meus Pedidos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF23272A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Logger.info('MyOrdersScreen: Refresh manual solicitado');
              _loadUserOrders();
            },
            tooltip: 'Atualizar pedidos',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF2C2F33),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading && _isInitialLoad) {
            Logger.debug('MyOrdersScreen: Exibindo loading inicial');
            return _buildLoadingState();
          }

          if (orderProvider.errorMessage != null) {
            Logger.error('MyOrdersScreen: Erro: ${orderProvider.errorMessage}');
            return _buildErrorState(orderProvider);
          }

          if (orderProvider.userOrders.isEmpty) {
            Logger.info('MyOrdersScreen: Lista vazia');
            return _buildEmptyState();
          }

          Logger.info('MyOrdersScreen: Exibindo ${orderProvider.userOrders.length} pedidos');
          return _buildOrdersList(orderProvider);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF9147FF),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Carregando seus pedidos...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(OrderProvider orderProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erro ao carregar pedidos',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              orderProvider.errorMessage!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Logger.info('MyOrdersScreen: Limpando erro');
                    orderProvider.clearError();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpar Erro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Logger.info('MyOrdersScreen: Tentativa de recarregamento');
                    orderProvider.clearError();
                    _loadUserOrders();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9147FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 80,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum pedido encontrado',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Você ainda não fez nenhum pedido.\nQuando fizer, eles aparecerão aqui.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Logger.info('MyOrdersScreen: Recarregamento solicitado (lista vazia)');
                _loadUserOrders();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderProvider orderProvider) {
    return RefreshIndicator(
      onRefresh: () {
        Logger.info('MyOrdersScreen: Pull-to-refresh ativado');
        return _loadUserOrders();
      },
      color: const Color(0xFF9147FF),
      backgroundColor: const Color(0xFF23272A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orderProvider.userOrders.length,
        itemBuilder: (context, index) {
          final order = orderProvider.userOrders[index];
          return _buildOrderCard(order, index);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF23272A),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do pedido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person, 'Cliente', order.customerInfo.name),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Data', _formatDate(order.createdAt)),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.attach_money, 'Total', 'R\$ ${order.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.payment,
              'Pagamento',
              order.payment_method == 'pix' ? 'PIX' : 'A Combinar',
            ),
            const SizedBox(height: 16),
            if (order.deliveryAddress != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2F33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Endereço de Entrega:',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.deliveryAddress.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2F33),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart,
                        size: 16,
                        color: Color(0xFF9147FF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Itens (${order.items.length}):',
                        style: const TextStyle(
                          color: Color(0xFF9147FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (order.items.isEmpty)
                    const Text(
                      'Nenhum item encontrado',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: Color(0xFF9147FF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${item.quantity}x R\$ ${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                ],
              ),
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2F33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: 16,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Observações:',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.notes!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white54,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange[700]!;
        textColor = Colors.white;
        displayText = 'Pendente';
        icon = Icons.pending;
        break;
      case 'confirmed':
        backgroundColor = Colors.blue[700]!;
        textColor = Colors.white;
        displayText = 'Confirmado';
        icon = Icons.check_circle;
        break;
      case 'shipped':
        backgroundColor = Colors.purple[700]!;
        textColor = Colors.white;
        displayText = 'Enviado';
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        backgroundColor = Colors.green[700]!;
        textColor = Colors.white;
        displayText = 'Entregue';
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        backgroundColor = Colors.red[700]!;
        textColor = Colors.white;
        displayText = 'Cancelado';
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = Colors.grey[700]!;
        textColor = Colors.white;
        displayText = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
