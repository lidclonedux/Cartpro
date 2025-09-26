// lib/screens/admin/accounting/transactions/admin_transactions_screen.dart
// Tela completa com CRUD funcional, filtros e integração com comando de voz

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/models/transaction.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/providers/transaction_provider.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/providers/voice_provider.dart';
import 'package:vitrine_borracharia/screens/admin/accounting/transactions/widgets/transaction_form_dialog.dart';
import 'package:vitrine_borracharia/widgets/voice_command_widget.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

enum TransactionFilter {
  all,
  income,
  expense,
  pending,
  paid,
}

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  TransactionFilter _currentFilter = TransactionFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Garante que os dados sejam carregados assim que a tela for construída.
    // O pré-carregamento no AdminScreen já pode ter feito isso, mas esta chamada
    // garante os dados mais recentes caso o usuário navegue diretamente para cá.
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    Logger.info('AdminTransactionsScreen: Carregando dados iniciais (transações e categorias)...');
    try {
      // Usamos Future.wait para carregar ambos em paralelo, otimizando o tempo.
      await Future.wait([
        context.read<TransactionProvider>().fetchTransactions(),
        context.read<AccountingProvider>().fetchCategories(),
      ]);
      
      // Atualiza as categorias no VoiceProvider para comandos de voz contextuais
      if (mounted) {
        final categories = context.read<AccountingProvider>().categories;
        context.read<VoiceProvider>().updateCategories(categories);
        Logger.info('AdminTransactionsScreen: Dados iniciais carregados com sucesso.');
      }
      
    } catch (e) {
      Logger.error('AdminTransactionsScreen: Erro ao carregar dados iniciais', error: e);
      if (mounted) {
        _showSnackBar('Erro ao carregar dados: ${e.toString()}', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      // O AppBar é gerenciado pelo Scaffold pai em `AccountingHomeScreen`
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        backgroundColor: const Color(0xFF2C2F33),
        color: const Color(0xFF9147FF),
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(child: _buildTransactionsList()),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2C2F33),
        border: Border(
          bottom: BorderSide(color: Color(0xFF36393F), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Barra de pesquisa
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por descrição, categoria, valor...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear, color: Colors.white54),
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
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          // Filtros rápidos
          _buildQuickFilters(),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TransactionFilter.values.map((filter) {
          final isSelected = _currentFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_getFilterLabel(filter)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _currentFilter = selected ? filter : TransactionFilter.all;
                });
              },
              backgroundColor: const Color(0xFF36393F),
              selectedColor: const Color(0xFF9147FF).withOpacity(0.3),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF9147FF) : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF9147FF) : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterLabel(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.all:
        return 'Todas';
      case TransactionFilter.income:
        return 'Receitas';
      case TransactionFilter.expense:
        return 'Despesas';
      case TransactionFilter.pending:
        return 'Pendentes';
      case TransactionFilter.paid:
        return 'Pagas';
    }
  }

  Widget _buildTransactionsList() {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        if (transactionProvider.isLoading && transactionProvider.transactions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF9147FF)),
                SizedBox(height: 16),
                Text(
                  'Carregando transações...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        if (transactionProvider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Erro ao Carregar Transações',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transactionProvider.errorMessage!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadInitialData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar Novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9147FF),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final filteredTransactions = _filterTransactions(transactionProvider.transactions);

        if (filteredTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _currentFilter != TransactionFilter.all
                      ? 'Nenhuma transação encontrada'
                      : 'Nenhum lançamento encontrado',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty || _currentFilter != TransactionFilter.all
                      ? 'Tente alterar os termos de busca ou filtros'
                      : 'Adicione seu primeiro lançamento financeiro',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddTransactionDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Lançamento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9147FF),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding inferior para não cobrir com o FAB
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction = filteredTransactions[index];
            return _buildTransactionCard(transaction);
          },
        );
      },
    );
  }

  // ==================================================================
  // === FUNÇÃO AUXILIAR PARA CONVERTER COR ===
  // ==================================================================
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

  Widget _buildTransactionCard(Transaction transaction) {
    final isIncome = transaction.type == TransactionType.income;
    final statusColor = isIncome ? Colors.green : Colors.red;
    final category = context.read<AccountingProvider>().categories.firstWhere(
          (cat) => cat.id == transaction.categoryId,
          // ==================================================================
          // === CORREÇÃO APLICADA AQUI ===
          // ==================================================================
          orElse: () => AccountingCategory(id: '', name: 'Desconhecida', type: 'expense', color: '#808080'),
        );

    return Card(
      color: const Color(0xFF2C2F33),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone e indicador de tipo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Informações principais
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            // ==================================================================
                            // === CORREÇÃO APLICADA AQUI ===
                            // ==================================================================
                            color: _getColorFromHex(category.color), // <<< CORRIGIDO
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.white54)),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(transaction.date),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        transaction.notes!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Valor e ações
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ${_formatCurrency(transaction.amount)}',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showEditTransactionDialog(transaction),
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: () => _showDeleteConfirmation(transaction),
                        icon: const Icon(Icons.delete, size: 18),
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Botão de comando de voz
        FloatingActionButton(
          heroTag: 'voice_fab',
          onPressed: () => _showVoiceCommandWidget(),
          backgroundColor: const Color(0xFF9147FF),
          foregroundColor: Colors.white,
          child: const Icon(Icons.mic),
        ),
        const SizedBox(height: 12),
        // Botão principal de adicionar
        FloatingActionButton.extended(
          heroTag: 'add_fab',
          onPressed: () => _showAddTransactionDialog(),
          backgroundColor: const Color(0xFF9147FF),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Novo Lançamento'),
        ),
      ],
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    var filtered = transactions;

    // Aplicar filtro de tipo
    switch (_currentFilter) {
      case TransactionFilter.income:
        filtered = filtered.where((t) => t.type == TransactionType.income).toList();
        break;
      case TransactionFilter.expense:
        filtered = filtered.where((t) => t.type == TransactionType.expense).toList();
        break;
      case TransactionFilter.pending:
        filtered = filtered.where((t) => t.status == 'pending').toList();
        break;
      case TransactionFilter.paid:
        filtered = filtered.where((t) => t.status == 'paid').toList();
        break;
      case TransactionFilter.all:
        break;
    }

    // Aplicar filtro de busca
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((transaction) {
        final category = context.read<AccountingProvider>().categories.firstWhere(
              (cat) => cat.id == transaction.categoryId,
              orElse: () => AccountingCategory(id: '', name: '', type: 'expense', color: '#808080'),
            );
        return transaction.description.toLowerCase().contains(_searchQuery) ||
               category.name.toLowerCase().contains(_searchQuery) ||
               transaction.amount.toString().contains(_searchQuery) ||
               (transaction.notes?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Ordenar por data (mais recente primeiro)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Hoje';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Ontem';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/'
             '${date.month.toString().padLeft(2, '0')}/'
             '${date.year}';
    }
  }

  String _formatCurrency(double amount) {
    return 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // === AÇÕES DA UI ===

  Future<void> _showAddTransactionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const TransactionFormDialog(),
    );

    if (result == true && mounted) {
      _showSnackBar('Lançamento criado com sucesso!', Colors.green);
    }
  }

  Future<void> _showEditTransactionDialog(Transaction transaction) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TransactionFormDialog(transaction: transaction),
    );

    if (result == true && mounted) {
      _showSnackBar('Lançamento atualizado com sucesso!', Colors.blue);
    }
  }

  Future<void> _showDeleteConfirmation(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        title: const Text(
          'Confirmar Exclusão',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tem certeza que deseja excluir este lançamento?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF36393F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(transaction.amount),
                    style: TextStyle(
                      color: transaction.type == TransactionType.income 
                          ? Colors.green 
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta ação não pode ser desfeita.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context.read<TransactionProvider>().deleteTransaction(transaction.id);
      if (mounted) {
        if (success) {
          _showSnackBar('Lançamento excluído com sucesso!', Colors.red);
        } else {
          final error = context.read<TransactionProvider>().errorMessage ?? 'Erro desconhecido.';
          _showSnackBar('Erro ao excluir lançamento: $error', Colors.red);
        }
      }
    }
  }

  Future<void> _showTransactionDetails(Transaction transaction) async {
    final category = context.read<AccountingProvider>().categories.firstWhere(
          (cat) => cat.id == transaction.categoryId,
          orElse: () => AccountingCategory(id: '', name: 'Desconhecida', type: 'expense', color: '#808080'),
        );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        title: Text(
          transaction.description,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tipo', 
                transaction.type == TransactionType.income ? 'Receita' : 'Despesa'),
            _buildDetailRow('Valor', _formatCurrency(transaction.amount)),
            _buildDetailRow('Data', _formatDate(transaction.date)),
            _buildDetailRow('Categoria', category.name),
            if (transaction.notes != null && transaction.notes!.isNotEmpty)
              _buildDetailRow('Observações', transaction.notes!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditTransactionDialog(transaction);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9147FF)),
            child: const Text('Editar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoiceCommandWidget() async {
    await showDialog(
      context: context,
      builder: (context) => const VoiceCommandWidget(),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        title: const Text('Filtrar Transações', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TransactionFilter.values.map((filter) {
            return RadioListTile<TransactionFilter>(
              title: Text(_getFilterLabel(filter), style: const TextStyle(color: Colors.white)),
              value: filter,
              groupValue: _currentFilter,
              onChanged: (value) {
                setState(() {
                  _currentFilter = value!;
                });
                Navigator.of(context).pop();
              },
              activeColor: const Color(0xFF9147FF),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    // Lógica de ordenação pode ser implementada aqui
    // Por enquanto, a ordenação padrão é por data mais recente
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de ordenação em desenvolvimento.'))
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
