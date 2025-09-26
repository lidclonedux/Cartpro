// lib/screens/admin/tabs/dashboard/admin_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/utils/temp_lucide_icons.dart';
// Importe a nova tela que vamos criar
import '../../accounting/accounting_home_screen.dart'; 

// Providers
import '../../../../providers/product_provider.dart';
import '../../../../providers/order_provider.dart';
import '../../../../providers/auth_provider.dart';

// Widgets
import '../../widgets/admin_base_widget.dart';
import '../../widgets/admin_snackbar_utils.dart';
import 'widgets/metric_card.dart';

// Services
import '../../services/admin_data_service.dart';

// Utils
import '../../../../utils/logger.dart';

// Screens
import '../../../admin_settings_screen.dart';

class AdminDashboardTab extends StatelessWidget {
  final VoidCallback? onRefresh;

  const AdminDashboardTab({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final AdminDataService dataService = AdminDataService();
    
    return Consumer3<ProductProvider, OrderProvider, AuthProvider>(
      builder: (context, productProvider, orderProvider, authProvider, child) {
        final isLoadingInitialData = (orderProvider.isLoading && orderProvider.orders.isEmpty) ||
                                     (productProvider.isLoading && productProvider.products.isEmpty);

        if (isLoadingInitialData) {
          Logger.info('AdminDashboard: Carregando dados iniciais');
          return AdminBaseWidget.buildLoadingState('Carregando dashboard...');
        }

        final metrics = dataService.calculateDashboardMetrics(
          products: productProvider.products,
          orders: orderProvider.orders,
        );

        final alerts = dataService.getImportantAlerts(
          products: productProvider.products,
          orders: orderProvider.orders,
        );

        return AdminBaseWidget(
          onRefresh: onRefresh ?? () {},
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                
                // CARD DE ACESSO À CONTABILIDADE
                _buildAccountingAccessCard(context),
                const SizedBox(height: 24),
                _buildMetricsGrid(metrics, dataService),
                const SizedBox(height: 24),
                if (alerts.isNotEmpty) ...[
                  _buildAlertsSection(alerts),
                  const SizedBox(height: 24),
                ],
                _buildQuickActionsSection(context),
                const SizedBox(height: 24),
                _buildRecentActivitySection(orderProvider.orders, dataService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return AdminBaseWidget.buildSectionHeader(
      title: 'Resumo da Sua Loja',
      subtitle: 'Visão geral do seu negócio',
      icon: Icons.dashboard,
    );
  }

  // CARD DE ACESSO À CONTABILIDADE INTELIGENTE
  Widget _buildAccountingAccessCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF23272A), // Cor escura para destaque
      child: InkWell(
        onTap: () => _navigateToAccounting(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF9147FF).withOpacity(0.8),
                const Color(0xFF23272A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.brainCircuit, size: 40, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contabilidade Inteligente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Acesse o painel financeiro completo, relatórios e mais.',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  // NAVEGAÇÃO PARA CONTABILIDADE
  void _navigateToAccounting(BuildContext context) {
    Logger.info('AdminDashboard: Navegando para a Contabilidade Inteligente');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountingHomeScreen()),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> metrics, AdminDataService dataService) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        MetricCard(
          title: 'Meus Produtos',
          value: metrics['totalProducts'].toString(),
          icon: Icons.inventory,
          color: const Color(0xFF9147FF),
          subtitle: _buildStockSubtitle(metrics),
        ),
        MetricCard(
          title: 'Pedidos Recebidos',
          value: metrics['totalOrders'].toString(),
          icon: Icons.shopping_bag,
          color: Colors.blue,
          subtitle: 'Total geral',
        ),
        MetricCard(
          title: 'Pedidos Pendentes',
          value: metrics['pendingOrders'].toString(),
          icon: Icons.pending,
          color: Colors.orange,
          subtitle: 'Precisam atenção',
        ),
        MetricCard(
          title: 'Receita Total',
          value: dataService.formatCurrency(metrics['totalRevenue']),
          icon: Icons.attach_money,
          color: Colors.green,
          subtitle: 'Confirmados/Entregues',
        ),
      ],
    );
  }

  String _buildStockSubtitle(Map<String, dynamic> metrics) {
    final outOfStock = metrics['outOfStockProducts'] ?? 0;
    final lowStock = metrics['lowStockProducts'] ?? 0;
    
    if (outOfStock > 0) {
      return '$outOfStock sem estoque';
    } else if (lowStock > 0) {
      return '$lowStock estoque baixo';
    }
    return 'Em boa condição';
  }

  Widget _buildAlertsSection(List<Map<String, dynamic>> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminBaseWidget.buildSectionHeader(
          title: 'Alertas Importantes',
          subtitle: '${alerts.length} ${alerts.length == 1 ? 'alerta encontrado' : 'alertas encontrados'}',
          icon: Icons.notifications_active,
        ),
        ...alerts.map((alert) => _buildAlertCard(alert)),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    Color color;
    switch (alert['color']) {
      case 'orange':
        color = Colors.orange;
        break;
      case 'red':
        color = Colors.red;
        break;
      case 'yellow':
        color = Colors.yellow;
        break;
      case 'blue':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    IconData iconData;
    switch (alert['icon']) {
      case 'inventory_2':
        iconData = Icons.inventory_2;
        break;
      case 'warning':
        iconData = Icons.warning;
        break;
      case 'pending_actions':
        iconData = Icons.pending_actions;
        break;
      case 'receipt':
        iconData = Icons.receipt;
        break;
      default:
        iconData = Icons.info;
    }

    return AdminBaseWidget.buildCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert['message'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminBaseWidget.buildSectionHeader(
          title: 'Ações Rápidas',
          subtitle: 'Funcionalidades mais utilizadas',
          icon: Icons.flash_on,
        ),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AdminBaseWidget.buildActionButton(
                    label: 'Novo Produto',
                    icon: Icons.add,
                    onPressed: () {
                      Logger.info('AdminDashboard: Novo produto solicitado');
                      AdminSnackBarUtils.showInfo(context, 'Funcionalidade será integrada em breve');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminBaseWidget.buildActionButton(
                    label: 'Atualizar',
                    icon: Icons.refresh,
                    backgroundColor: Colors.blue,
                    onPressed: onRefresh ?? () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminBaseWidget.buildActionButton(
              label: 'Configurações (PIX e Contato)',
              icon: Icons.settings,
              backgroundColor: Colors.orange,
              isFullWidth: true,
              onPressed: () {
                Logger.info('AdminDashboard: Navegando para configurações');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(List<dynamic> orders, AdminDataService dataService) {
    final recentOrders = orders.take(3).toList();
    
    if (recentOrders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminBaseWidget.buildSectionHeader(
            title: 'Atividade Recente',
            subtitle: 'Seus pedidos mais recentes',
            icon: Icons.history,
          ),
          AdminBaseWidget.buildCard(
            child: const Column(
              children: [
                Icon(Icons.history, size: 48, color: Colors.white54),
                SizedBox(height: 12),
                Text(
                  'Nenhuma atividade recente',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminBaseWidget.buildSectionHeader(
          title: 'Atividade Recente',
          subtitle: 'Últimos ${recentOrders.length} pedidos',
          icon: Icons.history,
        ),
        ...recentOrders.map((order) => _buildRecentOrderCard(order, dataService)),
      ],
    );
  }

  Widget _buildRecentOrderCard(dynamic order, AdminDataService dataService) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pendente';
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusText = 'Confirmado';
        break;
      case 'completed':
      case 'delivered':
        statusColor = Colors.green;
        statusText = 'Concluído';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelado';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Desconhecido';
    }

    return AdminBaseWidget.buildCard(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pedido #${order.id.substring(0, 8)}...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      order.customerInfo.name,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      dataService.formatCurrency(order.totalAmount),
                      style: const TextStyle(
                        color: Color(0xFF9147FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
