// lib/screens/admin_screen.dart - ARQUIVO PAI REFATORADO E CORRIGIDO
// $SAGRADO

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/auth_provider.dart';
import '../providers/accounting_provider.dart';

// Services dos submódulos
import 'admin/services/admin_refresh_service.dart';

// Widgets dos submódulos
import 'admin/widgets/admin_snackbar_utils.dart';

// *** INÍCIO DA CORREÇÃO ***
// 1. ADIÇÃO DA IMPORTAÇÃO CORRETA PARA O DASHBOARD DO E-COMMERCE
import 'admin/tabs/dashboard/admin_dashboard_tab.dart';
// *** FIM DA CORREÇÃO ***

// Tabs Principais (E-commerce e Perfil)
import 'admin/tabs/owner_profile_screen.dart';
import 'admin/tabs/accounting_screen.dart';
import 'admin/tabs/products/admin_products_tab.dart';
import 'admin/tabs/orders/admin_orders_tab.dart';
import 'admin/tabs/categories/admin_categories_tab.dart';

// Utils
import '../utils/logger.dart';
import '../screens/admin_settings_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AdminRefreshService _refreshService;

  @override
  void initState() {
    super.initState();
    Logger.info('AdminScreen: Inicializando painel administrativo modular');
    
    _tabController = TabController(length: 6, vsync: this);
    _refreshService = AdminRefreshService();
    
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.info('AdminScreen: Disparando pré-carregamento de dados contábeis...');
      context.read<AccountingProvider>().preloadAccountingData();
    });

    Logger.info('AdminScreen: Inicialização concluída');
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      Logger.info('AdminScreen: Mudança de aba - índice ${_tabController.index}');
    }
  }

  @override
  void dispose() {
    Logger.info('AdminScreen: Finalizando painel administrativo');
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await _refreshService.refreshAllData(context, authProvider);
    
    if (mounted) {
      if (success) {
        AdminSnackBarUtils.showSuccess(context, 'Dados atualizados com sucesso!');
      } else {
        AdminSnackBarUtils.showError(context, 'Erro ao atualizar dados', onRetry: _handleRefresh);
      }
    }
  }

  void _navigateToSettings() {
    Logger.info('AdminScreen: Navegando para configurações');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Painel Administrativo'),
        backgroundColor: const Color(0xFF23272A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar dados',
            onPressed: _handleRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: _navigateToSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Produtos', icon: Icon(Icons.inventory)),
            Tab(text: 'Pedidos', icon: Icon(Icons.shopping_bag)),
            Tab(text: 'Categorias', icon: Icon(Icons.category)),
            Tab(text: 'Perfil', icon: Icon(Icons.person)),
            Tab(text: 'Contabilidade', icon: Icon(Icons.calculate)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // *** INÍCIO DA CORREÇÃO ***
          // 2. INSTANCIAÇÃO CORRETA DO WIDGET
          AdminDashboardTab(onRefresh: _handleRefresh),
          // *** FIM DA CORREÇÃO ***
          AdminProductsTab(onRefresh: _handleRefresh),
          AdminOrdersTab(onRefresh: _handleRefresh),
          AdminCategoriesTab(onRefresh: _handleRefresh),
          const OwnerProfileScreen(),
          const AccountingScreen(),
        ],
      ),
    );
  }
}
