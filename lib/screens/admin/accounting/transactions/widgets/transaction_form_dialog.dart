// lib/screens/admin/accounting/transactions/widgets/transaction_form_dialog.dart
// Formulário completo para CRUD de transações com validação e UX otimizada
// VERSÃO ATUALIZADA: Envia um Map<String, dynamic> para o provider, alinhado com o backend.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/models/transaction.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/providers/transaction_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class TransactionFormDialog extends StatefulWidget {
  final Transaction? transaction; // null = criar nova, not null = editar
  final String context; // 'business' ou 'personal'

  const TransactionFormDialog({
    super.key,
    this.transaction,
    this.context = 'business',
  });

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers para os campos
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  
  // Estados do formulário
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  AccountingCategory? _selectedCategory;
  bool _isRecurring = false;
  int? _recurringDay;
  String _status = 'pending';
  
  // Estado da UI
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadCategories();
  }

  void _initializeForm() {
    _isEditMode = widget.transaction != null;
    
    if (_isEditMode) {
      // Modo edição - preencher com dados existentes
      final transaction = widget.transaction!;
      _descriptionController = TextEditingController(text: transaction.description);
      _amountController = TextEditingController(text: transaction.amount.toStringAsFixed(2));
      _notesController = TextEditingController(text: transaction.notes ?? '');
      
      _selectedType = transaction.type;
      _selectedDate = transaction.date;
      _selectedCategory = transaction.category;
      _status = transaction.status; // Carrega o status existente
      _isRecurring = transaction.isRecurring;
      _recurringDay = transaction.recurringDay;
      
      Logger.info('TransactionFormDialog: Modo edição para transação ${transaction.id}');
    } else {
      // Modo criação - campos vazios
      _descriptionController = TextEditingController();
      _amountController = TextEditingController();
      _notesController = TextEditingController();
      
      Logger.info('TransactionFormDialog: Modo criação');
    }
  }

  Future<void> _loadCategories() async {
    try {
      await context.read<AccountingProvider>().fetchCategories();
    } catch (e) {
      Logger.error('TransactionFormDialog: Erro ao carregar categorias', error: e);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2C2F33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 700,
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF23272A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isEditMode ? Icons.edit : Icons.add,
            color: const Color(0xFF9147FF),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Editar Lançamento' : 'Novo Lançamento',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isEditMode ? 'Modificar transação existente' : 'Adicionar nova transação',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildTypeSelector(),
          const SizedBox(height: 20),
          _buildDescriptionField(),
          const SizedBox(height: 20),
          _buildAmountField(),
          const SizedBox(height: 20),
          _buildCategoryDropdown(),
          const SizedBox(height: 20),
          _buildDatePicker(),
          const SizedBox(height: 20),
          _buildNotesField(),
          const SizedBox(height: 20),
          _buildRecurringSection(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Transação',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                type: TransactionType.income,
                label: 'Receita',
                icon: Icons.arrow_upward,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeOption(
                type: TransactionType.expense,
                label: 'Despesa',
                icon: Icons.arrow_downward,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required TransactionType type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategory = null; // Reset categoria quando mudar tipo
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF36393F),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.white70),
            const SizedBox(width: 8),
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

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descrição',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ex: Pagamento de aluguel, Venda de produto...',
            hintStyle: const TextStyle(color: Colors.white54),
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
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Descrição é obrigatória';
            }
            if (value.trim().length < 3) {
              return 'Descrição deve ter pelo menos 3 caracteres';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Valor (R\$)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          style: const TextStyle(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: const TextStyle(color: Colors.white54),
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
            prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Valor é obrigatório';
            }
            final amount = double.tryParse(value.trim());
            if (amount == null || amount <= 0) {
              return 'Valor deve ser maior que zero';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Consumer<AccountingProvider>(
      builder: (context, accountingProvider, child) {
        // Filtrar categorias pelo tipo selecionado
        final availableCategories = accountingProvider.categories
            .where((cat) => cat.type == (_selectedType == TransactionType.income ? 'income' : 'expense'))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Categoria',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showCreateCategoryDialog(),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF9147FF)),
                  label: const Text(
                    'Nova',
                    style: TextStyle(color: Color(0xFF9147FF), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (accountingProvider.isLoadingCategories)
              const Center(child: CircularProgressIndicator())
            else if (availableCategories.isEmpty)
              _buildEmptyCategoriesWidget()
            else
              DropdownButtonFormField<AccountingCategory>(
                value: _selectedCategory,
                style: const TextStyle(color: Colors.white),
                dropdownColor: const Color(0xFF36393F),
                decoration: InputDecoration(
                  hintText: 'Selecione uma categoria',
                  hintStyle: const TextStyle(color: Colors.white54),
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
                items: availableCategories.map((category) {
                  return DropdownMenuItem<AccountingCategory>(
                    value: category,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: (category.color is Color) ? category.color as Color : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (AccountingCategory? value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Categoria é obrigatória';
                  }
                  return null;
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyCategoriesWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF36393F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.category_outlined, color: Colors.white54, size: 32),
          const SizedBox(height: 8),
          Text(
            'Nenhuma categoria ${_selectedType == TransactionType.income ? 'de receita' : 'de despesa'}',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showCreateCategoryDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Criar Primeira Categoria'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF36393F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70),
                const SizedBox(width: 12),
                Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/'
                  '${_selectedDate.month.toString().padLeft(2, '0')}/'
                  '${_selectedDate.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observações (Opcional)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Informações adicionais sobre a transação...',
            hintStyle: const TextStyle(color: Colors.white54),
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
        ),
      ],
    );
  }

  Widget _buildRecurringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Transação Recorrente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Switch(
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                  if (!value) _recurringDay = null;
                });
              },
              activeColor: const Color(0xFF9147FF),
            ),
          ],
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Repetir todo dia',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _recurringDay,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF36393F),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF36393F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: List.generate(31, (index) {
                    final day = index + 1;
                    return DropdownMenuItem<int>(
                      value: day,
                      child: Text('$day'),
                    );
                  }),
                  onChanged: (int? value) {
                    setState(() {
                      _recurringDay = value;
                    });
                  },
                  validator: _isRecurring ? (value) {
                    if (value == null) {
                      return 'Selecione o dia';
                    }
                    return null;
                  } : null,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'do mês',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isEditMode ? 'Salvar Alterações' : 'Criar Lançamento',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9147FF),
              surface: Color(0xFF2C2F33),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    final TextEditingController categoryController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        title: const Text(
          'Nova Categoria',
          style: TextStyle(color: Colors.white),
        ),
        content: TextFormField(
          controller: categoryController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nome da categoria',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF36393F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (categoryController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(categoryController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9147FF)),
            child: const Text('Criar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await context.read<AccountingProvider>().addCategory(result);
        
        // Recarregar categorias e selecionar a nova
        await context.read<AccountingProvider>().fetchCategories();
        final newCategory = context.read<AccountingProvider>().categories
            .where((cat) => cat.name == result && 
                   cat.type == (_selectedType == TransactionType.income ? 'income' : 'expense'))
            .firstOrNull;
        
        if (newCategory != null) {
          setState(() {
            _selectedCategory = newCategory;
          });
        }
      } catch (e) {
        Logger.error('TransactionFormDialog: Erro ao criar categoria', error: e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar categoria: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // <<< CORREÇÃO PRINCIPAL APLICADA AQUI >>>
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text.trim());
      
      // Monta um Map<String, dynamic> em vez de um objeto Transaction
      final Map<String, dynamic> transactionData = {
        'description': _descriptionController.text.trim(),
        'amount': amount,
        'type': _selectedType == TransactionType.income ? 'income' : 'expense',
        'date': _selectedDate.toIso8601String(),
        'category_id': _selectedCategory!.id,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'context': widget.context,
        'source': 'manual',
        'is_recurring': _isRecurring,
        'recurring_day': _isRecurring ? _recurringDay : null,
      };

      // Lógica de status replicada do backend para consistência imediata na UI
      final DateTime today = DateTime.now();
      final DateTime transactionDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final DateTime todayOnly = DateTime(today.year, today.month, today.day);

      if (transactionDateOnly.isBefore(todayOnly) || transactionDateOnly.isAtSameMomentAs(todayOnly)) {
        transactionData['status'] = 'paid';
      } else {
        transactionData['status'] = 'pending';
      }

      final transactionProvider = context.read<TransactionProvider>();
      
      if (_isEditMode) {
        // Para edição, ainda precisamos do ID. Criamos um objeto Transaction temporário.
        final updatedTransaction = Transaction.fromJson({
          ...transactionData,
          'id': widget.transaction!.id, // Mantém o ID original
        });
        await transactionProvider.updateTransaction(updatedTransaction);
        Logger.info('TransactionFormDialog: Transação atualizada com sucesso');
      } else {
        // Para criação, passamos o Map diretamente.
        await transactionProvider.createTransaction(transactionData);
        Logger.info('TransactionFormDialog: Transação criada com sucesso');
      }

      Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      
    } catch (e) {
      Logger.error('TransactionFormDialog: Erro ao salvar transação', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao ${_isEditMode ? 'atualizar' : 'criar'} transação: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
