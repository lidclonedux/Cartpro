// lib/screens/admin/tabs/products/admin_products_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../../providers/product_provider.dart';
import '../../../../providers/auth_provider.dart';

// Models
import '../../../../models/product.dart';

// Widgets
import '../../widgets/admin_base_widget.dart';
import '../../widgets/admin_snackbar_utils.dart';
import 'widgets/product_card.dart';
import 'dialogs/product_dialog.dart';
import 'dialogs/delete_product_dialog.dart';

// Utils
import '../../../../utils/logger.dart';

class AdminProductsTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminProductsTab({super.key, required this.onRefresh});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  String _searchQuery = '';
  String _selectedCategoryId = 'all';
  String _sortBy = 'name'; // name, price, stock, created
  bool _showInactiveProducts = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductProvider, AuthProvider>(
      builder: (context, productProvider, authProvider, child) {
        if (productProvider.isLoading && productProvider.products.isEmpty) {
          Logger.info('AdminProducts: Carregando produtos...');
          return AdminBaseWidget.buildLoadingState('Carregando produtos...');
        }

        final filteredProducts = _getFilteredProducts(productProvider);

        if (productProvider.products.isEmpty && !productProvider.isLoading) {
          Logger.info('AdminProducts: Nenhum produto encontrado');
          return _buildEmptyState();
        }

        return AdminBaseWidget(
          onRefresh: widget.onRefresh,
          child: Column(
            children: [
              _buildFilterSection(productProvider),
              Expanded(
                child: filteredProducts.isEmpty
                    ? _buildNoResultsState()
                    : _buildProductsList(filteredProducts),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Product> _getFilteredProducts(ProductProvider productProvider) {
    var products = productProvider.products.where((product) {
      // Filtro de atividade
      if (!_showInactiveProducts && !product.isActive) return false;

      // Filtro de categoria
      if (_selectedCategoryId != 'all' && product.categoryId != _selectedCategoryId) return false;

      // Filtro de busca
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!product.name.toLowerCase().contains(query) &&
            !product.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Ordenação
    products.sort((a, b) {
      switch (_sortBy) {
        case 'price':
          return a.price.compareTo(b.price);
        case 'stock':
          return b.stockQuantity.compareTo(a.stockQuantity);
        case 'created':
          return b.createdAt.compareTo(a.createdAt);
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return products;
  }

  Widget _buildEmptyState() {
    return AdminBaseWidget.buildEmptyStateAdvanced(
      icon: Icons.inventory,
      title: 'Nenhum produto cadastrado',
      subtitle: 'Comece adicionando seu primeiro produto para começar a vender.',
      action: AdminBaseWidget.buildActionButton(
        label: 'Adicionar Primeiro Produto',
        icon: Icons.add,
        onPressed: () => _showProductDialog(context),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return AdminBaseWidget.buildEmptyStateAdvanced(
      icon: Icons.search_off,
      title: 'Nenhum produto encontrado',
      subtitle: 'Tente ajustar os filtros ou termo de busca para encontrar produtos.',
      action: AdminBaseWidget.buildActionButton(
        label: 'Limpar Filtros',
        icon: Icons.clear,
        backgroundColor: Colors.orange,
        onPressed: () {
          setState(() {
            _searchQuery = '';
            _selectedCategoryId = 'all';
            _showInactiveProducts = false;
          });
        },
      ),
    );
  }

  Widget _buildFilterSection(ProductProvider productProvider) {
    return AdminBaseWidget.buildCard(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barra de busca
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Buscar produtos...',
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              border: InputBorder.none,
            ),
          ),
          const Divider(color: Colors.white24),
          // Filtros
          Row(
            children: [
              // Categoria
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  dropdownColor: const Color(0xFF2C2F33),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Todas as categorias'),
                    ),
                    ...productProvider.categories.map((category) =>
                        DropdownMenuItem(
                          value: category.id,
                          child: Text('${category.emoji} ${category.name}'),
                        ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedCategoryId = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 12),
              // Ordenação
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  dropdownColor: const Color(0xFF2C2F33),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Ordenar por',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Nome')),
                    DropdownMenuItem(value: 'price', child: Text('Preço')),
                    DropdownMenuItem(value: 'stock', child: Text('Estoque')),
                    DropdownMenuItem(value: 'created', child: Text('Mais recentes')),
                  ],
                  onChanged: (value) => setState(() => _sortBy = value ?? 'name'),
                ),
              ),
            ],
          ),
          // Filtro de produtos inativos
          CheckboxListTile(
            title: const Text(
              'Mostrar produtos desativados',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            value: _showInactiveProducts,
            onChanged: (value) => setState(() => _showInactiveProducts = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(List<Product> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Header com estatísticas
          _buildListHeader(products),
          const SizedBox(height: 8),
          // Lista de produtos
          Expanded(
            child: AdminBaseWidget.buildSeparatedList(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(
                  product: product,
                  onEdit: () => _showProductDialog(context, product: product),
                  onDelete: () => _showDeleteDialog(context, product),
                  onToggleActive: () => _toggleProductActive(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(List<Product> products) {
    final activeCount = products.where((p) => p.isActive).length;
    final inactiveCount = products.length - activeCount;
    final totalValue = products
        .where((p) => p.isActive)
        .fold(0.0, (sum, product) => sum + (product.price * product.stockQuantity));

    return AdminBaseWidget.buildCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${products.length} ${products.length == 1 ? 'produto' : 'produtos'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (inactiveCount > 0)
                  Text(
                    '$activeCount ativos, $inactiveCount inativos',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${totalValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF9147FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Valor total em estoque',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF9147FF)),
            tooltip: 'Adicionar produto',
            onPressed: () => _showProductDialog(context),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProductDialog(
        product: product,
        onSave: (success, message) {
          if (success) {
            AdminSnackBarUtils.showSuccess(context, message);
          } else {
            AdminSnackBarUtils.showError(context, message);
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteProductDialog(
        product: product,
        onConfirm: (success, message) {
          if (success) {
            AdminSnackBarUtils.showSuccess(context, message);
          } else {
            AdminSnackBarUtils.showError(context, message);
          }
        },
      ),
    );
  }

  Future<void> _toggleProductActive(Product product) async {
    Logger.info('AdminProducts: Alternando status do produto "${product.name}"');
    
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    try {
      final updatedProduct = product.copyWith(isActive: !product.isActive);
      final success = await productProvider.updateProduct(updatedProduct);
      
      if (mounted) {
        if (success) {
          final statusText = updatedProduct.isActive ? 'ativado' : 'desativado';
          AdminSnackBarUtils.showSuccess(
            context, 
            'Produto "${product.name}" $statusText com sucesso!',
          );
        } else {
          AdminSnackBarUtils.showError(
            context, 
            productProvider.errorMessage ?? 'Erro ao alterar status do produto',
          );
        }
      }
    } catch (e) {
      Logger.error('AdminProducts: Erro ao alterar status do produto', error: e);
      if (mounted) {
        AdminSnackBarUtils.showError(context, 'Erro: ${e.toString()}');
      }
    }
  }
}
