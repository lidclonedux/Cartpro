// lib/screens/admin/accounting/import/widgets/import_review_dialog.dart
// NOVO WIDGET: Dialog para revisar e editar transações antes de salvar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/providers/transaction_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class ImportReviewDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialTransactions;
  final Map<String, dynamic>? summary;

  const ImportReviewDialog({
    super.key,
    required this.initialTransactions,
    this.summary,
  });

  @override
  State<ImportReviewDialog> createState() => _ImportReviewDialogState();
}

class _ImportReviewDialogState extends State<ImportReviewDialog> {
  late List<Map<String, dynamic>> _transactionsToSave;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Cria uma cópia local para permitir modificações
    _transactionsToSave = List<Map<String, dynamic>>.from(widget.initialTransactions);
  }

  Future<void> _changeCategory(int index) async {
    final accountingProvider = context.read<AccountingProvider>();
    final currentTransaction = _transactionsToSave[index];
    final transactionType = currentTransaction['type'] as String;

    // Filtra as categorias disponíveis para o tipo da transação
    final availableCategories = accountingProvider.categories
        .where((cat) => cat.type == transactionType)
        .toList();

    final selectedCategory = await showDialog<AccountingCategory>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Trocar Categoria'),
        backgroundColor: const Color(0xFF2C2F33),
        children: availableCategories.map((cat) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, cat),
            child: Text(cat.name, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
      ),
    );

    if (selectedCategory != null) {
      setState(() {
        _transactionsToSave[index]['category_id'] = selectedCategory.id;
        _transactionsToSave[index]['category_name'] = selectedCategory.name;
      });
    }
  }

  void _removeTransaction(int index) {
    setState(() {
      _transactionsToSave.removeAt(index);
    });
  }

  Future<void> _saveTransactions() async {
    if (_transactionsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma transação para salvar.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final transactionProvider = context.read<TransactionProvider>();
      int successCount = 0;

      for (final txData in _transactionsToSave) {
        final success = await transactionProvider.createTransaction(txData);
        if (success) {
          successCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount de ${_transactionsToSave.length} transações salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      // Atualiza o dashboard e fecha o dialog com sucesso
      if (mounted) {
        context.read<AccountingProvider>().fetchDashboardSummary();
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      }

    } catch (e) {
      Logger.error('Erro ao salvar transações importadas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar transações: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary ?? {};
    final income = summary['total_income'] ?? 0.0;
    final expenses = summary['total_expenses'] ?? 0.0;
    final count = _transactionsToSave.length;

    return Dialog(
      backgroundColor: const Color(0xFF2C2F33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Revisar Importação',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Resumo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count transações prontas para serem salvas.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receitas: R\$ ${income.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('Despesas: R\$ ${expenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF36393F), height: 30),
            // Lista de Transações
            Expanded(
              child: _transactionsToSave.isEmpty
                  ? const Center(child: Text('Nenhuma transação para importar.', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _transactionsToSave.length,
                      itemBuilder: (context, index) {
                        final tx = _transactionsToSave[index];
                        final isIncome = tx['type'] == 'income';
                        return Card(
                          color: const Color(0xFF36393F),
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.green : Colors.red),
                            title: Text(tx['description'] ?? 'Sem descrição', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(tx['category_name'] ?? 'Sem categoria', style: const TextStyle(color: Colors.white70)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'R\$ ${(tx['amount'] as num).toStringAsFixed(2)}',
                                  style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'change_category') {
                                      _changeCategory(index);
                                    } else if (value == 'remove') {
                                      _removeTransaction(index);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'change_category', child: Text('Trocar Categoria')),
                                    const PopupMenuItem(value: 'remove', child: Text('Remover da Importação')),
                                  ],
                                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                                  color: const Color(0xFF36393F),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Rodapé com Ações
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveTransactions,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Salvando...' : 'Confirmar e Salvar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
