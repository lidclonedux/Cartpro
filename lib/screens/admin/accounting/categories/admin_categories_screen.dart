// lib/screens/admin/accounting/categories/admin_categories_screen.dart
// CORREÇÃO PRINCIPAL: Dialog de categoria com seletor de tipo (receita/despesa) + emoji + cor

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

// Enum para o filtro
enum CategoryFilterType { all, income, expense }

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  // Controllers - CORRIGIDO: Restauradas as variáveis que estavam faltando
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController();
  
  // Estados
  AccountingCategory? _editingCategory;
  String _searchTerm = '';
  CategoryFilterType _filterType = CategoryFilterType.all;

  @override
  void initState() {
    super.initState();
    // A busca inicial já é feita pelo preloadAccountingData no AdminScreen
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _categoryNameController.dispose(); // CORRIGIDO: Adicionado ao dispose
    super.dispose();
  }

  // Função para recarregar os dados
  Future<void> _reloadData() async {
    try {
      await Provider.of<AccountingProvider>(context, listen: false).fetchCategories();
    } catch (e) {
      Logger.error('Erro ao recarregar categorias: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao recarregar: ${e.toString()}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      body: RefreshIndicator(
        onRefresh: _reloadData,
        backgroundColor: const Color(0xFF2C2F33),
        color: const Color(0xFF9147FF),
        child: Column(
          children: [
            _buildFilterSection(),
            Expanded(
              child: Consumer<AccountingProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoadingCategories && provider.categories.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.errorMessage != null && provider.categories.isEmpty) {
                    return _buildErrorState(provider.errorMessage!);
                  }

                  final filteredCategories = _getFilteredCategories(provider.categories);

                  if (filteredCategories.isEmpty) {
                    return _buildEmptyState();
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      return _buildCategoryCard(category);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: const Color(0xFF9147FF),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Nova Categoria',
      ),
    );
  }

  List<AccountingCategory> _getFilteredCategories(List<AccountingCategory> categories) {
    List<AccountingCategory> filtered = categories;

    // Filtro por tipo
    if (_filterType != CategoryFilterType.all) {
      final typeString = _filterType == CategoryFilterType.income ? 'income' : 'expense';
      filtered = filtered.where((cat) => cat.type == typeString).toList();
    }

    // Filtro por busca
    if (_searchTerm.isNotEmpty) {
      filtered = filtered.where((cat) => cat.name.toLowerCase().contains(_searchTerm)).toList();
    }

    return filtered;
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2C2F33),
        border: Border(bottom: BorderSide(color: Color(0xFF36393F))),
      ),
      child: Column(
        children: [
          // Barra de busca
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar categorias...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF36393F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF9147FF), width: 2),
              ),
            ),
            onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          // Filtros de tipo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFilterChip('Todas', CategoryFilterType.all),
              _buildFilterChip('Receitas', CategoryFilterType.income),
              _buildFilterChip('Despesas', CategoryFilterType.expense),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CategoryFilterType type) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterType = type);
        }
      },
      selectedColor: const Color(0xFF9147FF).withOpacity(0.3),
      backgroundColor: const Color(0xFF36393F),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF9147FF) : Colors.white70),
      side: BorderSide(color: isSelected ? const Color(0xFF9147FF) : Colors.transparent),
    );
  }
  
  // Função auxiliar para converter cor
  Color _getColorFromHex(String? hexColor) {
    hexColor = (hexColor ?? '#808080').replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    if (hexColor.length == 8) {
      try {
        return Color(int.parse("0x$hexColor"));
      } catch (e) {
        return Colors.grey;
      }
    }
    return Colors.grey;
  }

  Widget _buildCategoryCard(AccountingCategory category) {
    final color = _getColorFromHex(category.color);
    final isIncome = category.type == 'income';

    return Card(
      color: const Color(0xFF2C3136),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _showCategoryDialog(category: category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.emoji ?? '📁',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                        onPressed: () => _showCategoryDialog(category: category),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteCategory(category.id),
                        tooltip: 'Excluir',
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isIncome ? Icons.trending_up : Icons.trending_down,
                    color: isIncome ? Colors.greenAccent : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isIncome ? 'Receita' : 'Despesa',
                    style: TextStyle(
                      color: isIncome ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma categoria encontrada',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crie sua primeira categoria ou use as padrões.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Criar Categoria'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Erro ao Carregar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _reloadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CORREÇÃO PRINCIPAL: Dialog completamente refatorado com seletor de tipo
  void _showCategoryDialog({AccountingCategory? category}) {
    _editingCategory = category;
    _categoryNameController.text = category?.name ?? '';
    
    // Estados do dialog - CORRIGIDO: Agora o usuário pode escolher entre receita/despesa
    String selectedType = category?.type ?? 'expense';
    String selectedEmoji = category?.emoji ?? '📁';
    String selectedColor = category?.color ?? '#F44336';
    
    // Lista de emojis disponíveis
    final List<String> availableEmojis = [
      '💰', '💸', '🏠', '🚗', '🍽️', '⚡', '📱', '👕', '🎮', '📚', 
      '💊', '⛽', '🎬', '🛒', '💳', '🎯', '📁', '💼', '🎵', '🏥'
    ];
    
    // Lista de cores disponíveis
    final List<String> availableColors = [
      '#4CAF50', '#F44336', '#2196F3', '#FF9800', '#9C27B0', '#795548',
      '#607D8B', '#E91E63', '#00BCD4', '#CDDC39', '#FF5722', '#3F51B5'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF23272A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                category == null ? 'Nova Categoria' : 'Editar Categoria',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo Nome
                    TextField(
                      controller: _categoryNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome da Categoria',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Ex: Alimentação, Transporte...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF36393F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF9147FF), width: 2),
                        ),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    
                    // CORREÇÃO PRINCIPAL: Seletor de Tipo (Receita/Despesa)
                    const Text(
                      'Tipo da Categoria',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeSelector(
                            label: 'Receita',
                            value: 'income',
                            isSelected: selectedType == 'income',
                            icon: Icons.trending_up,
                            color: Colors.green,
                            onTap: () => setDialogState(() => selectedType = 'income'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTypeSelector(
                            label: 'Despesa',
                            value: 'expense',
                            isSelected: selectedType == 'expense',
                            icon: Icons.trending_down,
                            color: Colors.red,
                            onTap: () => setDialogState(() => selectedType = 'expense'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Seletor de Emoji
                    const Text(
                      'Emoji',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = availableEmojis[index];
                          final isSelected = selectedEmoji == emoji;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedEmoji = emoji),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF9147FF) : const Color(0xFF36393F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF9147FF) : Colors.transparent,
                                ),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Seletor de Cor
                    const Text(
                      'Cor',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableColors.length,
                        itemBuilder: (context, index) {
                          final colorHex = availableColors[index];
                          final color = _getColorFromHex(colorHex);
                          final isSelected = selectedColor == colorHex;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedColor = colorHex),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_categoryNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nome da categoria é obrigatório'), backgroundColor: Colors.red)
                      );
                      return;
                    }
                    
                    try {
                      final provider = Provider.of<AccountingProvider>(context, listen: false);
                      
                      if (category == null) {
                        // Criar nova categoria
                        final newCategory = AccountingCategory(
                          id: '',
                          name: _categoryNameController.text.trim(),
                          type: selectedType, // CORRIGIDO: Agora usa o tipo selecionado
                          color: selectedColor,
                          emoji: selectedEmoji,
                        );
                        await provider.createAccountingCategory(newCategory);
                      } else {
                        // Editar categoria existente
                        final updatedCategory = category.copyWith(
                          name: _categoryNameController.text.trim(),
                          type: selectedType,
                          color: selectedColor,
                          emoji: selectedEmoji,
                        );
                        await provider.updateAccountingCategory(updatedCategory);
                      }
                      
                      if (mounted) Navigator.of(context).pop();
                      _categoryNameController.clear();
                      
                    } catch (e) {
                      Logger.error('Erro ao salvar categoria: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao salvar: ${e.toString()}'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9147FF),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(category == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypeSelector({
    required String label,
    required String value,
    required bool isSelected,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF36393F),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.white70, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(String categoryId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirmar Exclusão', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Tem certeza que deseja excluir esta categoria?\n\nEsta ação não pode ser desfeita.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Provider.of<AccountingProvider>(context, listen: false).deleteCategory(categoryId);
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  Logger.error('Erro ao excluir categoria: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: ${e.toString()}'), backgroundColor: Colors.red)
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
