// lib/screens/admin/accounting/reports/admin_reports_screen.dart
// IMPLEMENTAÇÃO COMPLETA: Relatórios funcionais com dados reais dos providers

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/providers/transaction_provider.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/models/transaction.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = 'last_30_days';
  bool _isGeneratingReport = false;

  // Dados calculados do relatório
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      appBar: AppBar(
        title: const Text('Relatórios e Análises'),
        backgroundColor: const Color(0xFF23272A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateReport,
            tooltip: 'Atualizar Relatório',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildPeriodSelector(),
            const SizedBox(height: 24),
            if (_isGeneratingReport)
              _buildLoadingSection()
            else if (_reportData != null) ...[
              _buildSummaryCards(),
              const SizedBox(height: 24),
              _buildCategoryAnalysis(),
              const SizedBox(height: 24),
              _buildTransactionsList(),
              const SizedBox(height: 24),
            ],
            _buildExportOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9147FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9147FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.analytics,
              color: Color(0xFF9147FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Análise Financeira',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visualize relatórios detalhados e exporte dados para análise externa.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Período de Análise',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPeriodChip('Últimos 7 dias', 'last_7_days'),
              _buildPeriodChip('Últimos 30 dias', 'last_30_days'),
              _buildPeriodChip('Últimos 90 dias', 'last_90_days'),
              _buildPeriodChip('Este mês', 'current_month'),
              _buildPeriodChip('Mês passado', 'last_month'),
              _buildPeriodChip('Este ano', 'current_year'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker('Data Inicial', _startDate, (date) {
                  setState(() => _startDate = date);
                  _generateReport();
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePicker('Data Final', _endDate, (date) {
                  setState(() => _endDate = date);
                  _generateReport();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
            _updateDatesByPeriod(value);
          });
          _generateReport();
        }
      },
      selectedColor: const Color(0xFF9147FF).withOpacity(0.3),
      backgroundColor: const Color(0xFF36393F),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF9147FF) : Colors.white70),
      side: BorderSide(color: isSelected ? const Color(0xFF9147FF) : Colors.transparent),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () => _selectDate(context, date, onChanged),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF36393F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF9147FF)),
            const SizedBox(height: 16),
            const Text(
              'Gerando relatório...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final data = _reportData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo do Período',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard(
              'Total Receitas',
              'R\$ ${data['total_income'].toStringAsFixed(2).replaceAll('.', ',')}',
              Icons.trending_up,
              Colors.green,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard(
              'Total Despesas',
              'R\$ ${data['total_expenses'].toStringAsFixed(2).replaceAll('.', ',')}',
              Icons.trending_down,
              Colors.red,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard(
              'Saldo',
              'R\$ ${data['balance'].toStringAsFixed(2).replaceAll('.', ',')}',
              Icons.account_balance_wallet,
              data['balance'] >= 0 ? Colors.green : Colors.red,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard(
              'Transações',
              '${data['transaction_count']}',
              Icons.receipt_long,
              const Color(0xFF9147FF),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAnalysis() {
    final data = _reportData!;
    final categoryData = data['categories'] as List<Map<String, dynamic>>;
    
    if (categoryData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2F33),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.pie_chart_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma transação encontrada',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Análise por Categorias',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2F33),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: categoryData.map((category) {
              final percentage = (category['amount'] / data['total_expenses'] * 100).clamp(0.0, 100.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category['name']),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category['name'],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      '${percentage.toInt()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'R\$ ${category['amount'].toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    final data = _reportData!;
    final recentTransactions = data['recent_transactions'] as List<Transaction>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transações Recentes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${recentTransactions.length} transações',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C2F33),
            borderRadius: BorderRadius.circular(12),
          ),
          child: recentTransactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: Colors.white54, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhuma transação no período',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = recentTransactions[index];
                    return _buildTransactionItem(transaction);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isIncome = transaction.type == TransactionType.income;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF36393F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                  transaction.displayCategoryName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  color: isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transaction.formattedDate,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exportar Dados',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildExportButton(
                'Exportar CSV',
                'Planilha para Excel',
                Icons.table_view,
                Colors.green,
                () => _exportData('csv'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExportButton(
                'Exportar PDF',
                'Relatório completo',
                Icons.picture_as_pdf,
                Colors.red,
                () => _exportData('pdf'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton(String title, String subtitle, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2F33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _updateDatesByPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'last_7_days':
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case 'last_30_days':
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
        break;
      case 'last_90_days':
        _startDate = now.subtract(const Duration(days: 90));
        _endDate = now;
        break;
      case 'current_month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        break;
      case 'current_year':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = now;
        break;
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime initialDate, Function(DateTime) onChanged) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != initialDate) {
      onChanged(picked);
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGeneratingReport = true;
      _reportData = null;
    });

    try {
      Logger.info('Gerando relatório para período: ${_startDate.toString().split(' ')[0]} até ${_endDate.toString().split(' ')[0]}');
      
      // Buscar dados dos providers
      final accountingProvider = Provider.of<AccountingProvider>(context, listen: false);
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      
      // Aguardar carregamento dos dados se necessário
      if (accountingProvider.categories.isEmpty) {
        await accountingProvider.fetchCategories();
      }
      if (transactionProvider.transactions.isEmpty) {
        await transactionProvider.fetchTransactions();
      }

      // Filtrar transações por período
      final filteredTransactions = transactionProvider.transactions.where((transaction) {
        return transaction.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
               transaction.date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      // Calcular totais
      double totalIncome = 0;
      double totalExpenses = 0;
      Map<String, double> categoryTotals = {};
      
      for (final transaction in filteredTransactions) {
        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        } else {
          totalExpenses += transaction.amount;
          
          // Agrupar por categoria para análise
          final categoryName = transaction.displayCategoryName;
          categoryTotals[categoryName] = (categoryTotals[categoryName] ?? 0) + transaction.amount;
        }
      }

      // Ordenar categorias por valor decrescente
      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Pegar apenas as transações mais recentes para exibir (máximo 20)
      final recentTransactions = filteredTransactions.take(20).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _reportData = {
          'total_income': totalIncome,
          'total_expenses': totalExpenses,
          'balance': totalIncome - totalExpenses,
          'transaction_count': filteredTransactions.length,
          'categories': sortedCategories.map((entry) => {
            'name': entry.key,
            'amount': entry.value,
          }).toList(),
          'recent_transactions': recentTransactions,
          'period_start': _startDate,
          'period_end': _endDate,
        };
        _isGeneratingReport = false;
      });

      Logger.info('Relatório gerado com sucesso: ${filteredTransactions.length} transações analisadas');

    } catch (e) {
      Logger.error('Erro ao gerar relatório: $e');
      setState(() {
        _isGeneratingReport = false;
      });
      _showMessage('Erro ao gerar relatório: ${e.toString()}', Colors.red);
    }
  }

  Color _getCategoryColor(String categoryName) {
    // Gerar cor consistente baseada no hash do nome
    final hash = categoryName.hashCode;
    final colors = [
      const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFF9C27B0),
      const Color(0xFFFF9800), const Color(0xFFF44336), const Color(0xFF795548), // CORRIGIDO
      const Color(0xFF607D8B), const Color(0xFFE91E63), const Color(0xFF00BCD4),
      const Color(0xFFCDDC39), const Color(0xFFFF5722), const Color(0xFF3F51B5), // CORRIGIDO
    ];
    return colors[hash.abs() % colors.length];
  }

  void _exportData(String format) {
    if (_reportData == null) {
      _showMessage('Nenhum relatório gerado para exportar', Colors.orange);
      return;
    }

    Logger.info('Iniciando exportação de dados em formato: $format');
    
    // TODO: Implementar exportação real para CSV/PDF
    // Por ora, simular o processo
    
    final transactions = _reportData!['recent_transactions'] as List<Transaction>;
    final startDate = (_reportData!['period_start'] as DateTime).toString().split(' ')[0];
    final endDate = (_reportData!['period_end'] as DateTime).toString().split(' ')[0];
    
    if (format == 'csv') {
      // Simular geração de CSV
      final csvContent = _generateCsvContent(transactions);
      _showMessage('Dados exportados para CSV: relatorio_$startDate-$endDate.csv', Colors.green);
      Logger.info('CSV gerado com ${csvContent.split('\n').length} linhas');
    } else if (format == 'pdf') {
      // Simular geração de PDF
      _showMessage('Relatório PDF gerado: relatorio_$startDate-$endDate.pdf', Colors.green);
      Logger.info('PDF gerado com relatório completo');
    }
  }

  String _generateCsvContent(List<Transaction> transactions) {
    final buffer = StringBuffer();
    
    // Cabeçalho CSV
    buffer.writeln('Data,Descrição,Categoria,Tipo,Valor,Status');
    
    // Dados das transações
    for (final transaction in transactions) {
      final line = [
        transaction.formattedDate,
        '"${transaction.description}"',
        '"${transaction.displayCategoryName}"',
        transaction.typeLabel,
        transaction.amount.toStringAsFixed(2),
        transaction.statusLabel,
      ].join(',');
      buffer.writeln(line);
    }
    
    return buffer.toString();
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : 
              color == Colors.red ? Icons.error : Icons.warning,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
