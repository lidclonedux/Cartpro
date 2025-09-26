// lib/screens/admin/accounting/dashboard/accounting_dashboard_screen.dart
// Dashboard com gráficos corrigidos e funcionais
// $SAGRADO
// MODIFICAÇÃO: Unifica o gráfico de pizza para mostrar Receitas e Despesas juntas.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/screens/admin/widgets/admin_base_widget.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class AccountingDashboardScreen extends StatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  State<AccountingDashboardScreen> createState() => _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen> {
  int touchedBarIndex = -1;
  int touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      await context.read<AccountingProvider>().fetchDashboardSummary();
    } catch (e) {
      Logger.error('AccountingDashboardScreen: Erro ao carregar dados', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23272A),
      appBar: AppBar(
        title: const Text('Dashboard Financeiro'),
        backgroundColor: const Color(0xFF23272A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<AccountingProvider>(
        builder: (context, accountingProvider, child) {
          if (accountingProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF9147FF)),
                  SizedBox(height: 16),
                  Text(
                    'Carregando dados contábeis...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          if (accountingProvider.errorMessage != null) {
            return Center(
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
                    'Erro ao carregar dados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accountingProvider.errorMessage!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar Novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9147FF),
                    ),
                  ),
                ],
              ),
            );
          }

          final summary = accountingProvider.dashboardSummary;

          if (summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum dado disponível',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Adicione algumas transações para ver os gráficos',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadDashboardData,
            backgroundColor: const Color(0xFF2C2F33),
            color: const Color(0xFF9147FF),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(summary),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Fluxo de Caixa Mensal',
                    'Receitas vs Despesas nos últimos meses',
                    Icons.show_chart,
                  ),
                  const SizedBox(height: 16),
                  _buildMonthlyCashFlowChart(summary),
                  const SizedBox(height: 24),
                  
                  // --- INÍCIO DA MODIFICAÇÃO ---
                  _buildSectionHeader(
                    'Composição do Fluxo de Caixa', // Título alterado
                    'Receitas e Despesas do mês atual', // Subtítulo alterado
                    Icons.pie_chart,
                  ),
                  const SizedBox(height: 16),
                  // Chamada para o novo gráfico unificado
                  _buildUnifiedCashFlowChart(summary),
                  // --- FIM DA MODIFICAÇÃO ---

                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Resumo do Período',
                    'Estatísticas detalhadas',
                    Icons.assessment,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailedStats(summary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9147FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF9147FF), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    final totalIncome = (summary['total_income'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (summary['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final balance = (summary['balance'] as num?)?.toDouble() ?? 0.0;
    final pendingPayments = summary['pending_payments'] as int? ?? 0;
    final upcomingReceivables = summary['upcoming_receivables'] as int? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Receitas',
                _formatCurrency(totalIncome),
                Colors.green,
                Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Despesas',
                _formatCurrency(totalExpenses),
                Colors.red,
                Icons.arrow_downward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSummaryCard(
          'Saldo Total',
          _formatCurrency(balance),
          balance >= 0 ? Colors.green : Colors.red,
          balance >= 0 ? Icons.trending_up : Icons.trending_down,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Pagamentos Pendentes',
                pendingPayments.toString(),
                Colors.orange,
                Icons.pending_actions,
                isCount: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'A Receber',
                upcomingReceivables.toString(),
                Colors.blue,
                Icons.schedule,
                isCount: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    bool isCount = false,
  }) {
    return Card(
      color: const Color(0xFF2C2F33),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isCount) ...[
              const SizedBox(height: 4),
              Text(
                isCount && int.tryParse(value) == 1 ? 'transação' : 'transações',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCashFlowChart(Map<String, dynamic> summary) {
    final List<dynamic> monthlyData = summary['monthly_trend'] as List<dynamic>? ?? [];

    if (monthlyData.isEmpty) {
      return _buildNoDataCard('Dados de fluxo de caixa não disponíveis');
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 100;

    for (int i = 0; i < monthlyData.length; i++) {
      final month = monthlyData[i];
      final income = (month['income'] as num).toDouble();
      final expenses = (month['expenses'] as num).toDouble();

      if (income > maxY) maxY = income;
      if (expenses > maxY) maxY = expenses;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: income,
              color: Colors.green,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: expenses,
              color: Colors.red,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
          barsSpace: 4,
        ),
      );
    }

    return Card(
      color: const Color(0xFF2C2F33),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Receitas', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('Despesas', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF36393F),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String month = monthlyData[group.x]['month'];
                        String type = rodIndex == 0 ? 'Receitas' : 'Despesas';
                        return BarTooltipItem(
                          '$month\n$type: ${_formatCurrency(rod.toY)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            barTouchResponse == null ||
                            barTouchResponse.spot == null) {
                          touchedBarIndex = -1;
                          return;
                        }
                        touchedBarIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                      });
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              monthlyData[value.toInt()]['month'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              _formatCurrencyShort(value),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                        reservedSize: 50,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xFF36393F),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFF36393F), width: 1),
                      left: BorderSide(color: Color(0xFF36393F), width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- INÍCIO DA MODIFICAÇÃO ---
  // O método `_buildExpenseDistributionChart` foi substituído por `_buildUnifiedCashFlowChart`.

  /// Constrói o gráfico de pizza UNIFICADO para Receitas e Despesas.
  Widget _buildUnifiedCashFlowChart(Map<String, dynamic> summary) {
    // Consome os dados unificados do provider
    final List<dynamic> cashFlowData = context.read<AccountingProvider>().cashFlowDistribution;
    
    if (cashFlowData.isEmpty) {
      return _buildNoDataCard('Nenhuma movimentação encontrada neste período');
    }

    List<PieChartSectionData> sections = [];
    
    // Paletas de cores distintas para receitas e despesas
    List<Color> incomeColors = [Colors.green, Colors.blue, Colors.teal, Colors.lightGreen, Colors.cyan];
    List<Color> expenseColors = [Colors.red, Colors.orange, Colors.purple, Colors.pink, Colors.brown];
    int incomeColorIndex = 0;
    int expenseColorIndex = 0;

    // Calcula o valor total absoluto para o cálculo da porcentagem
    double totalCashFlow = cashFlowData.fold(0.0, (sum, item) => sum + (item['total'] as num).toDouble());

    if (totalCashFlow == 0) {
      return _buildNoDataCard('Nenhuma movimentação encontrada neste período');
    }
    
    for (int i = 0; i < cashFlowData.length; i++) {
      final item = cashFlowData[i];
      final total = (item['total'] as num).toDouble();
      final type = item['type'] as String;
      final percentage = (total / totalCashFlow * 100);
      
      Color sectionColor;
      if (type == 'income') {
        sectionColor = incomeColors[incomeColorIndex % incomeColors.length];
        incomeColorIndex++;
      } else {
        sectionColor = expenseColors[expenseColorIndex % expenseColors.length];
        expenseColorIndex++;
      }
      
      sections.add(
        PieChartSectionData(
          color: sectionColor,
          value: total, // O valor é sempre positivo para o tamanho da fatia
          title: '${percentage.toStringAsFixed(0)}%', // Porcentagem em relação ao todo
          radius: touchedPieIndex == i ? 80 : 70,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFF2C2F33),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 50,
                  sectionsSpace: 3,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedPieIndex = -1;
                          return;
                        }
                        touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Legenda unificada
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(cashFlowData.length, (index) {
                final item = cashFlowData[index];
                final type = item['type'] as String;
                
                Color legendColor;
                if (type == 'income') {
                  legendColor = incomeColors[(incomeColors.length - (incomeColorIndex--)) % incomeColors.length];
                } else {
                  legendColor = expenseColors[(expenseColors.length - (expenseColorIndex--)) % expenseColors.length];
                }

                return _buildLegendItem(
                  item['category_name'] ?? 'Categoria ${index + 1}',
                  legendColor,
                  value: _formatCurrency((item['total'] as num).toDouble()),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
  // --- FIM DA MODIFICAÇÃO ---

  Widget _buildDetailedStats(Map<String, dynamic> summary) {
    final avgTransactionValue = (summary['avg_transaction_value'] as num?)?.toDouble() ?? 0.0;
    final transactionCount = summary['transaction_count'] as int? ?? 0;
    final cashFlowTrend = summary['cash_flow_trend'] as String? ?? 'stable';
    final monthlyGrowth = (summary['monthly_growth'] as num?)?.toDouble() ?? 0.0;

    return Card(
      color: const Color(0xFF2C2F33),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(
              'Valor médio por transação',
              _formatCurrency(avgTransactionValue),
              Icons.calculate,
            ),
            const Divider(color: Color(0xFF36393F)),
            _buildStatRow(
              'Total de transações',
              '$transactionCount transações',
              Icons.receipt_long,
            ),
            const Divider(color: Color(0xFF36393F)),
            _buildStatRow(
              'Tendência de fluxo de caixa',
              _formatTrend(cashFlowTrend),
              _getTrendIcon(cashFlowTrend),
              color: _getTrendColor(cashFlowTrend),
            ),
            const Divider(color: Color(0xFF36393F)),
            _buildStatRow(
              'Crescimento mensal',
              '${monthlyGrowth >= 0 ? '+' : ''}${monthlyGrowth.toStringAsFixed(1)}%',
              monthlyGrowth >= 0 ? Icons.trending_up : Icons.trending_down,
              color: monthlyGrowth >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {String? value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (value != null) ...[
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoDataCard(String message) {
    return Card(
      color: const Color(0xFF2C2F33),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.bar_chart,
                size: 48,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatCurrencyShort(double value) {
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'R\$ ${value.toInt()}';
  }

  String _getMonthName(int index) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return months[index % 12];
  }

  String _formatTrend(String trend) {
    switch (trend.toLowerCase()) {
      case 'positive':
        return 'Positiva';
      case 'negative':
        return 'Negativa';
      case 'stable':
        return 'Estável';
      default:
        return 'Estável';
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'positive':
        return Icons.trending_up;
      case 'negative':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.trending_flat;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'stable':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }
}
