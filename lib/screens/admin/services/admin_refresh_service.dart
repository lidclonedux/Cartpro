// lib/screens/admin/services/admin_refresh_service.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/logger.dart';

class AdminRefreshService {
  
  /// Atualiza todos os dados da aplicação
  Future<bool> refreshAllData(BuildContext context, AuthProvider authProvider) async {
    if (!context.mounted) return false;
    
    Logger.info('AdminRefreshService: Iniciando refresh completo');
    
    try {
      final userId = authProvider.currentUser?.uid;
      if (userId == null) {
        Logger.error('AdminRefreshService: Usuário não autenticado para refresh');
        return false;
      }

      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      // Executa refresh de produtos e pedidos em paralelo
      await Future.wait([
        productProvider.refresh(userId: userId),
        orderProvider.fetchOrders(),
      ]);

      Logger.info('AdminRefreshService: Refresh concluído - ${productProvider.products.length} produtos, ${orderProvider.orders.length} pedidos');
      return true;

    } catch (e) {
      Logger.error('AdminRefreshService: Erro durante refresh', error: e);
      return false;
    }
  }

  /// Atualiza apenas os produtos
  Future<bool> refreshProducts(BuildContext context, String userId) async {
    if (!context.mounted) return false;
    
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      await productProvider.refresh(userId: userId);
      Logger.info('AdminRefreshService: Produtos atualizados com sucesso');
      return true;
    } catch (e) {
      Logger.error('AdminRefreshService: Erro ao atualizar produtos', error: e);
      return false;
    }
  }

  /// Atualiza apenas os pedidos
  Future<bool> refreshOrders(BuildContext context) async {
    if (!context.mounted) return false;
    
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.fetchOrders();
      Logger.info('AdminRefreshService: Pedidos atualizados com sucesso');
      return true;
    } catch (e) {
      Logger.error('AdminRefreshService: Erro ao atualizar pedidos', error: e);
      return false;
    }
  }

  /// Atualiza apenas as categorias
  Future<bool> refreshCategories(BuildContext context, String userId) async {
    if (!context.mounted) return false;
    
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      // As categorias são carregadas junto com os produtos
      await productProvider.refresh(userId: userId);
      Logger.info('AdminRefreshService: Categorias atualizadas com sucesso');
      return true;
    } catch (e) {
      Logger.error('AdminRefreshService: Erro ao atualizar categorias', error: e);
      return false;
    }
  }

  /// Valida se o usuário está autenticado
  bool validateAuthentication(AuthProvider authProvider) {
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      Logger.error('AdminRefreshService: Usuário não autenticado');
      return false;
    }
    return true;
  }

  /// Obtém o ID do usuário atual
  String? getCurrentUserId(AuthProvider authProvider) {
    return authProvider.currentUser?.uid;
  }
}