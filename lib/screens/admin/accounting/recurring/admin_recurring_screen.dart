import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/models/recurring_transaction.dart';
import 'package:vitrine_borracharia/providers/transaction_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:intl/intl.dart'; // Import para formatação de data

class AdminRecurringScreen extends StatefulWidget {
  const AdminRecurringScreen({super.key});

  @override
  State<AdminRecurringScreen> createState() => _AdminRecurringScreenState();
}

class _AdminRecurringScreenState extends State<AdminRecurringScreen> {
  List<RecurringTransaction> _recurringTransactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        context.read<AccountingProvider>().fetchCategories(),
        _loadRecurringTransactions(),
      ]);
    } catch (e) {
      final errorMessage = e.toString();
      Logger.error('Erro ao carregar dados iniciais da tela recorrente: $errorMessage');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessage;
        });
      }
    }
  }

  Future<void> _loadRecurringTransactions() async {
    try {
      final transactions = await Provider.of<TransactionProvider>(context, listen: false).fetchRecurringTransactions();
      if (mounted) {
        setState(() {
          _recurringTransactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
      rethrow;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _handleSave(RecurringTransaction transaction) async {
    // final provider = Provider.of<TransactionProvider>(context, listen: false);
    bool success;
    if (transaction.id.isEmpty) {
      // success = await provider.addRecurringTransaction(transaction);
      _showSnackBar('Funcionalidade de adicionar ainda não implementada no provider.', Colors.orange);
      success = false;
    } else {
      // success = await provider.updateRecurringTransaction(transaction);
      _showSnackBar('Funcionalidade de editar ainda não implementada no provider.', Colors.orange);
      success = false;
    }

    if (success) {
      _showSnackBar('Transação salva com sucesso!', Colors.green);
      _loadRecurringTransactions();
    } else {
      _showSnackBar('Erro ao salvar transação.', Colors.red);
    }
  }

  Future<void> _handleDelete(String transactionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir esta transação recorrente? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // final provider = Provider.of<TransactionProvider>(context, listen: false);
      // bool success = await provider.deleteRecurringTransaction(transactionId);
      _showSnackBar('Funcionalidade de deletar ainda não implementada no provider.', Colors.orange);
      final bool success = false;

      if (success) {
        _showSnackBar('Transação recorrente excluída com sucesso!', Colors.green);
        _loadRecurringTransactions();
      } else {
        _showSnackBar('Erro ao excluir transação.', Colors.red);
      }
    }
  }

  void _showRecurringTransactionDialog({RecurringTransaction? transaction}) {
    showDialog(
      context: context,
      builder: (context) => RecurringTransactionFormDialog(
        transaction: transaction,
        onSave: (editedTransaction) {
          _handleSave(editedTransaction);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Transações Recorrentes'),
        backgroundColor: const Color(0xFF23272A),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecurringTransactionDialog(),
        backgroundColor: const Color(0xFF9147FF),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Erro ao Carregar Dados', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
              )
            ],
          ),
        ),
      );
    }

    if (_recurringTransactions.isEmpty) {
      return const Center(child: Text('Nenhuma transação recorrente encontrada.', style: TextStyle(color: Colors.white70)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _recurringTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _recurringTransactions[index];
        final category = context.watch<AccountingProvider>().categories.firstWhere(
              (c) => c.id == transaction.categoryId,
              orElse: () => AccountingCategory(id: '', name: 'Desconhecida', type: 'expense'),
            );

        return Card(
          color: const Color(0xFF2C3136),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(
              transaction.type == 'income' ? Icons.arrow_circle_up : Icons.arrow_circle_down,
              color: transaction.type == 'income' ? Colors.green : Colors.red,
            ),
            title: Text(transaction.description, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              'R\$ ${transaction.amount.toStringAsFixed(2)} / ${transaction.frequency.displayName} - Cat: ${category.name}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () => _showRecurringTransactionDialog(transaction: transaction),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _handleDelete(transaction.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RecurringTransactionFormDialog extends StatefulWidget {
  final RecurringTransaction? transaction;
  final Function(RecurringTransaction) onSave;

  const RecurringTransactionFormDialog({
    super.key,
    this.transaction,
    required this.onSave,
  });

  @override
  State<RecurringTransactionFormDialog> createState() => _RecurringTransactionFormDialogState();
}

class _RecurringTransactionFormDialogState extends State<RecurringTransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late String _type;
  late String? _categoryId;
  late RecurringFrequency _frequency;
  // <<< CORREÇÃO: Adicionado estado para a data de início >>>
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _amountController = TextEditingController(text: t?.amount.toStringAsFixed(2) ?? '');
    _type = t?.type ?? 'expense';
    _categoryId = t?.categoryId;
    _frequency = t?.frequency ?? RecurringFrequency.monthly;
    // <<< CORREÇÃO: Inicializa a data de início >>>
    _startDate = t?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newTransaction = RecurringTransaction(
        id: widget.transaction?.id ?? '',
        description: _descriptionController.text,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        type: _type,
        categoryId: _categoryId!,
        frequency: _frequency,
        // <<< CORREÇÃO: Passando o parâmetro obrigatório 'startDate' >>>
        startDate: _startDate,
      );
      widget.onSave(newTransaction);
      Navigator.of(context).pop();
    }
  }

  // <<< CORREÇÃO: Adicionado método para selecionar a data >>>
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<AccountingProvider>().categories;
    final filteredCategories = categories.where((c) => c.type == _type).toList();

    if (_categoryId != null && !filteredCategories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF23272A),
      title: Text(widget.transaction == null ? 'Nova Recorrência' : 'Editar Recorrência', style: const TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Campo obrigatório';
                  if (double.tryParse(value) == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Despesa')),
                  DropdownMenuItem(value: 'income', child: Text('Receita')),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                hint: const Text('Selecione uma categoria'),
                items: filteredCategories.map((cat) {
                  return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                }).toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurringFrequency>(
                value: _frequency,
                decoration: const InputDecoration(labelText: 'Frequência'),
                items: RecurringFrequency.values.map((freq) {
                  return DropdownMenuItem(value: freq, child: Text(freq.displayName));
                }).toList(),
                onChanged: (value) => setState(() => _frequency = value!),
              ),
              const SizedBox(height: 16),
              // <<< CORREÇÃO: Adicionado campo para selecionar a data de início >>>
              ListTile(
                title: const Text('Data de Início', style: TextStyle(color: Colors.white70)),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate), style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                onTap: () => _selectStartDate(context),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
