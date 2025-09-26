// lib/screens/admin/tabs/categories/admin_categories_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/product_provider.dart';
import '../../../../models/category.dart';
import '../../widgets/admin_base_widget.dart';
import '../../widgets/admin_snackbar_utils.dart';
import 'dialogs/category_dialog.dart';
import '../../../../utils/logger.dart';

class AdminCategoriesTab extends StatelessWidget {
  final VoidCallback onRefresh;

  const AdminCategoriesTab({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading && productProvider.categories.isEmpty) {
          Logger.info('AdminCategoriesTab: Carregando categorias...');
          return AdminBaseWidget.buildLoadingState('Carregando categorias...');
        }

        if (productProvider.categories.isEmpty) {
          Logger.info('AdminCategoriesTab: Nenhuma categoria encontrada - mostrando tela de criação');
          return _buildEmptyState(context, productProvider);
        }

        Logger.info('AdminCategoriesTab: Exibindo ${productProvider.categories.length} categorias');
        return _buildCategoriesList(context, productProvider);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ProductProvider productProvider) {
    return AdminBaseWidget.buildEmptyStateAdvanced(
      icon: Icons.category_outlined,
      title: 'Nenhuma categoria de produto criada.',
      subtitle: 'Crie categorias para organizar melhor seus produtos',
      action: ElevatedButton.icon(
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Criar Categorias Padrão'),
        onPressed: () => _createDefaultCategories(context, productProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9147FF),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(BuildContext context, ProductProvider productProvider) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Logger.info('AdminCategoriesTab: Abrindo diálogo de nova categoria');
          CategoryDialog.show(context);
        },
        backgroundColor: const Color(0xFF9147FF),
        child: const Icon(Icons.add),
      ),
      body: AdminBaseWidget(
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productProvider.categories.length,
          itemBuilder: (context, index) {
            final category = productProvider.categories[index];
            return _buildCategoryCard(context, category);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF23272A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade800,
          child: Text(
            category.emoji, 
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          category.name, 
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'ID: ${category.id.length > 8 ? category.id.substring(0, 8) : category.id}...',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Editar categoria',
              onPressed: () {
                Logger.info('AdminCategoriesTab: Editando categoria "${category.name}"');
                CategoryDialog.show(context, category: category);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Excluir categoria',
              onPressed: () => _showDeleteConfirmation(context, category),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDefaultCategories(BuildContext context, ProductProvider productProvider) async {
    Logger.info('AdminCategoriesTab: Criando categorias padrão');
    
    try {
      await productProvider.seedDefaultCategories();
      
      if (context.mounted) {
        AdminSnackBarUtils.showSuccess(context, 'Categorias padrão criadas com sucesso!');
      }
    } catch (e) {
      Logger.error('AdminCategoriesTab: Erro ao criar categorias padrão', error: e);
      
      if (context.mounted) {
        AdminSnackBarUtils.showError(
          context, 
          'Erro ao criar categorias: ${e.toString()}',
          onRetry: () => _createDefaultCategories(context, productProvider),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Category category) {
    Logger.info('AdminCategoriesTab: Mostrando confirmação de exclusão para categoria "${category.name}"');
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Excluir Categoria',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tem certeza que deseja excluir a categoria:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${category.name}"',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ATENÇÃO: Esta ação não pode ser desfeita. Produtos desta categoria podem ser afetados.',
                style: TextStyle(
                  color: Colors.red, 
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Logger.info('AdminCategoriesTab: Exclusão de categoria cancelada');
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => _deleteCategory(dialogContext, category),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Excluir Categoria'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(BuildContext dialogContext, Category category) async {
    Logger.info('AdminCategoriesTab: Confirmando exclusão da categoria "${category.name}"');
    
    final productProvider = Provider.of<ProductProvider>(dialogContext, listen: false);
    
    try {
      await productProvider.deleteCategory(category.id);
      
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
        AdminSnackBarUtils.showSuccess(dialogContext, 'Categoria removida com sucesso!');
        Logger.info('AdminCategoriesTab: Categoria "${category.name}" excluída com sucesso');
      }
    } catch (e) {
      Logger.error('AdminCategoriesTab: Erro ao excluir categoria "${category.name}"', error: e);
      
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
        AdminSnackBarUtils.showError(
          dialogContext, 
          'Erro ao remover categoria: ${e.toString()}',
        );
      }
    }
  }
}
