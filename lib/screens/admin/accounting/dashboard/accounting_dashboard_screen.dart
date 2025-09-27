// lib/screens/admin/accounting/dashboard/accounting_dashboard_screen.dart
// Dashboard REVOLUCIONÁRIO com efeitos 3D, parallax e design imersivo
// $SAGRADO
// MODIFICAÇÃO: Design completamente reimaginado com animações fluidas, efeitos 3D e UX moderna

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/screens/admin/widgets/admin_base_widget.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'dart:math' as math;

class AccountingDashboardScreen extends StatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  State<AccountingDashboardScreen> createState() => _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen>
    with TickerProviderStateMixin {
  int touchedBarIndex = -1;
  int touchedPieIndex = -1;
  ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // Controladores de animação para efeitos imersivos
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Paletas de cores com gradientes revolucionários
  final List<List<Color>> _incomeGradients = [
    [const Color(0xFF00F5FF), const Color(0xFF00D4AA)], // Cyan-Teal
    [const Color(0xFF10B981), const Color(0xFF34D399)], // Emerald
    [const Color(0xFF3B82F6), const Color(0xFF60A5FA)], // Blue
    [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)], // Purple
    [const Color(0xFF06B6D4), const Color(0xFF67E8F9)], // Sky
  ];
  
  final List<List<Color>> _expenseGradients = [
    [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)], // Red
    [const Color(0xFFFF7F50), const Color(0xFFFFA07A)], // Coral
    [const Color(0xFFFF1744), const Color(0xFFFF5722)], // Deep Red
    [const Color(0xFFE91E63), const Color(0xFFF06292)], // Pink
    [const Color(0xFFFF5722), const Color(0xFFFF8A65)], // Orange Red
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
      _startInitialAnimations();
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut)
    );
    
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear)
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear)
    );

    // Animações infinitas
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _startInitialAnimations() {
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      HapticFeedback.lightImpact();
      await context.read<AccountingProvider>().fetchDashboardSummary();
    } catch (e) {
      Logger.error('AccountingDashboardScreen: Erro ao carregar dados', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo 3D com parallax e gradiente animado
          _build3DParallaxBackground(),
          
          // Conteúdo principal
          _buildMainContent(),
          
          // AppBar flutuante com glass morphism
          _buildFloatingAppBar(),
        ],
      ),
    );
  }

  Widget _build3DParallaxBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 2.0,
              colors: [
                Color.lerp(
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  (math.sin(_waveAnimation.value) + 1) / 2,
                )!,
                Color.lerp(
                  const Color(0xFF16213E),
                  const Color(0xFF0F3460),
                  (math.cos(_waveAnimation.value * 0.7) + 1) / 2,
                )!,
                Color.lerp(
                  const Color(0xFF0F3460),
                  const Color(0xFF1A1A2E),
                  (math.sin(_waveAnimation.value * 1.3) + 1) / 2,
                )!,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Efeitos de partículas flutuantes
              ...List.generate(20, (index) => _buildFloatingParticle(index)),
              
              // Mesh gradient overlay
              _buildMeshGradient(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticle(int index) {
    final random = math.Random(index);
    final size = 2.0 + random.nextDouble() * 6;
    final speed = 0.5 + random.nextDouble() * 1.5;
    
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        final offset = (_scrollOffset * 0.1 + _waveAnimation.value * speed) % 1.0;
        final x = random.nextDouble();
        final y = (random.nextDouble() + offset) % 1.0;
        
        return Positioned(
          left: MediaQuery.of(context).size.width * x,
          top: MediaQuery.of(context).size.height * y,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.6),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeshGradient() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: _waveAnimation.value,
              endAngle: _waveAnimation.value + math.pi,
              colors: [
                const Color(0xFF9147FF).withOpacity(0.1),
                const Color(0xFF00F5FF).withOpacity(0.05),
                const Color(0xFF10B981).withOpacity(0.1),
                const Color(0xFF9147FF).withOpacity(0.1),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFF9147FF),
                        const Color(0xFF00F5FF),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Dashboard Financeiro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF9147FF).withOpacity(0.2),
                            const Color(0xFF00F5FF).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _loadDashboardData();
                        },
                        icon: AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2 * math.pi,
                              child: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<AccountingProvider>(
      builder: (context, accountingProvider, child) {
        if (accountingProvider.isLoading) {
          return _buildLoadingState();
        }

        if (accountingProvider.errorMessage != null) {
          return _buildErrorState(accountingProvider.errorMessage!);
        }

        final summary = accountingProvider.dashboardSummary;

        if (summary == null) {
          return _buildEmptyState();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  backgroundColor: const Color(0xFF2C2F33).withOpacity(0.9),
                  color: const Color(0xFF9147FF),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Espaçamento para o AppBar flutuante
                      const SliverToBoxAdapter(
                        child: SizedBox(height: kToolbarHeight + 20),
                      ),
                      
                      // Cards de resumo com efeito parallax
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0, _scrollOffset * 0.1),
                          child: _buildRevolutionarySummaryCards(summary),
                        ),
                      ),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      
                      // Gráfico de fluxo de caixa com efeito 3D
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0, _scrollOffset * 0.15),
                          child: _buildRevolutionaryMonthlyCashFlowChart(summary),
                        ),
                      ),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      
                      // Gráfico de pizza unificado com efeitos imersivos
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0, _scrollOffset * 0.2),
                          child: _buildRevolutionaryUnifiedCashFlowChart(summary),
                        ),
                      ),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      
                      // Estatísticas detalhadas com design futurista
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0, _scrollOffset * 0.25),
                          child: _buildRevolutionaryDetailedStats(summary),
                        ),
                      ),
                      
                      // Espaçamento final
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2F33).withOpacity(0.9),
              const Color(0xFF36393F).withOpacity(0.9),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * math.pi,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFF9147FF),
                          Color(0xFF00F5FF),
                          Color(0xFF10B981),
                          Color(0xFF9147FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        color: Colors.transparent,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  const Color(0xFF9147FF),
                  const Color(0xFF00F5FF),
                ],
              ).createShader(bounds),
              child: const Text(
                'Carregando dados contábeis...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.withOpacity(0.1),
              Colors.red.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.red.withOpacity(0.2),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ops! Algo deu errado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: ElevatedButton.icon(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar Novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2F33).withOpacity(0.9),
              const Color(0xFF36393F).withOpacity(0.9),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF9147FF).withOpacity(0.2),
                          const Color(0xFF9147FF).withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF9147FF),
                      size: 64,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  const Color(0xFF9147FF),
                  const Color(0xFF00F5FF),
                ],
              ).createShader(bounds),
              child: const Text(
                'Dashboard Vazio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Adicione algumas transações para ver\nseus dados financeiros aqui',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevolutionarySummaryCards(Map<String, dynamic> summary) {
    final totalIncome = (summary['total_income'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (summary['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final balance = (summary['balance'] as num?)?.toDouble() ?? 0.0;
    final pendingPayments = summary['pending_payments'] as int? ?? 0;
    final upcomingReceivables = summary['upcoming_receivables'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Saldo principal com design hero
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildHeroBalanceCard(balance),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          // Cards de receitas e despesas
          Row(
            children: [
              Expanded(
                child: _buildRevolutionaryCard(
                  'Receitas',
                  _formatCurrency(totalIncome),
                  _incomeGradients[0],
                  Icons.trending_up_rounded,
                  delay: 0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRevolutionaryCard(
                  'Despesas',
                  _formatCurrency(totalExpenses),
                  _expenseGradients[0],
                  Icons.trending_down_rounded,
                  delay: 200,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Cards de pendências
          Row(
            children: [
              Expanded(
                child: _buildRevolutionaryCard(
                  'Pendentes',
                  pendingPayments.toString(),
                  [const Color(0xFFFF6B35), const Color(0xFFFF8E3C)],
                  Icons.pending_actions_rounded,
                  delay: 400,
                  isCount: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRevolutionaryCard(
                  'A Receber',
                  upcomingReceivables.toString(),
                  [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
                  Icons.schedule_rounded,
                  delay: 600,
                  isCount: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: balance >= 0
              ? [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                  const Color(0xFF047857),
                ]
              : [
                  const Color(0xFFEF4444),
                  const Color(0xFFDC2626),
                  const Color(0xFFB91C1C),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                .withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  balance >= 0 ? Icons.account_balance_wallet : Icons.warning_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Saldo Total',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _formatCurrency(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            balance >= 0 ? 'Situação Positiva' : 'Atenção Necessária',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevolutionaryCard(
    String title,
    String value,
    List<Color> gradientColors,
    IconData icon,
    {int delay = 0, bool isCount = false}
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + delay),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCount) ...[
                  const SizedBox(height: 4),
                  Text(
                    int.tryParse(value) == 1 ? 'item' : 'itens',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRevolutionaryMonthlyCashFlowChart(Map<String, dynamic> summary) {
    final List<dynamic> monthlyData = summary['monthly_trend'] as List<dynamic>? ?? [];

    if (monthlyData.isEmpty) {
      return _buildRevolutionaryNoDataCard('Dados de fluxo de caixa não disponíveis', Icons.show_chart);
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
        gradient: LinearGradient(
          colors: _incomeGradients[0],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        width: 18,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      BarChartRodData(
        toY: expenses,
        gradient: LinearGradient(
          colors: _expenseGradients[0],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        width: 18,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
    ],
    barsSpace: 6,
  ),
);
}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2F33).withOpacity(0.95),
            const Color(0xFF36393F).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9147FF).withOpacity(0.2),
                        const Color(0xFF00F5FF).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    color: Color(0xFF9147FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fluxo de Caixa Mensal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Receitas vs Despesas nos últimos meses',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRevolutionaryLegendItem('Receitas', _incomeGradients[0][0]),
                const SizedBox(width: 32),
                _buildRevolutionaryLegendItem('Despesas', _expenseGradients[0][0]),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 320,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF1A1A2E).withOpacity(0.95),
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.all(12),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String month = monthlyData[group.x]['month'];
                        String type = rodIndex == 0 ? 'Receitas' : 'Despesas';
                        Color color = rodIndex == 0 ? _incomeGradients[0][0] : _expenseGradients[0][0];
                        return BarTooltipItem(
                          '$month\n$type: ${_formatCurrency(rod.toY)}',
                          TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
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
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                monthlyData[value.toInt()]['month'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                        reservedSize: 60,
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
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                      left: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
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

  Widget _buildRevolutionaryUnifiedCashFlowChart(Map<String, dynamic> summary) {
    final List<dynamic> cashFlowData = context.read<AccountingProvider>().cashFlowDistribution;

    if (cashFlowData.isEmpty) {
      return _buildRevolutionaryNoDataCard('Nenhuma movimentação encontrada neste período', Icons.pie_chart);
    }

    double totalCashFlow = cashFlowData.fold(0.0, (sum, item) => sum + (item['total'] as num).toDouble());

    if (totalCashFlow == 0) {
      return _buildRevolutionaryNoDataCard('Nenhuma movimentação encontrada neste período', Icons.pie_chart);
    }

    List<PieChartSectionData> sections = _generateRevolutionaryPieSections(cashFlowData, totalCashFlow);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2F33).withOpacity(0.95),
            const Color(0xFF36393F).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9147FF).withOpacity(0.2),
                        const Color(0xFF00F5FF).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Color(0xFF9147FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Composição do Fluxo de Caixa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Receitas e Despesas do mês atual',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value * 0.1,
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 80,
                            sectionsSpace: 4,
                            pieTouchData: PieTouchData(
                              enabled: true,
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
                      );
                    },
                  ),
                  _buildRevolutionaryTooltipCard(cashFlowData, totalCashFlow),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(cashFlowData.length, (index) {
                final item = cashFlowData[index];
                return _buildRevolutionaryLegendItem(
                  item['category_name'] ?? 'Categoria ${index + 1}',
                  _getRevolutionaryColorForCategory(item['type'], index),
                  value: _formatCurrency((item['total'] as num).toDouble()),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateRevolutionaryPieSections(List<dynamic> cashFlowData, double totalCashFlow) {
    List<PieChartSectionData> sections = [];
    for (int i = 0; i < cashFlowData.length; i++) {
      final item = cashFlowData[i];
      final total = (item['total'] as num).toDouble();
      final type = item['type'] as String;
      final percentage = (total / totalCashFlow * 100);
      final isTouched = touchedPieIndex == i;

      final gradientColors = _getRevolutionaryGradientForCategory(type, i);

      sections.add(
        PieChartSectionData(
          color: gradientColors[0],
          value: total,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: isTouched ? 90 : 75,
          titleStyle: TextStyle(
            fontSize: isTouched ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
          borderSide: isTouched
              ? BorderSide(color: gradientColors[1], width: 3)
              : BorderSide.none,
        ),
      );
    }
    return sections;
  }

  Widget _buildRevolutionaryTooltipCard(List<dynamic> cashFlowData, double totalValue) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1A1A2E).withOpacity(0.95),
                  const Color(0xFF16213E).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: touchedPieIndex == -1 || touchedPieIndex >= cashFlowData.length
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            const Color(0xFF9147FF),
                            const Color(0xFF00F5FF),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Total do Mês',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatCurrency(totalValue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : _buildSelectedCategoryTooltip(cashFlowData[touchedPieIndex]),
          ),
        );
      },
    );
  }

  Widget _buildSelectedCategoryTooltip(Map<String, dynamic> selectedData) {
    final categoryName = selectedData['category_name'] ?? 'Desconhecido';
    final value = (selectedData['total'] as num).toDouble();
    final type = selectedData['type'] as String;
    final color = _getRevolutionaryColorForCategory(type, touchedPieIndex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _formatCurrency(value),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            type == 'income' ? 'Receita' : 'Despesa',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevolutionaryDetailedStats(Map<String, dynamic> summary) {
    final avgTransactionValue = (summary['avg_transaction_value'] as num?)?.toDouble() ?? 0.0;
    final transactionCount = summary['transaction_count'] as int? ?? 0;
    final cashFlowTrend = summary['cash_flow_trend'] as String? ?? 'stable';
    final monthlyGrowth = (summary['monthly_growth'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2F33).withOpacity(0.95),
            const Color(0xFF36393F).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9147FF).withOpacity(0.2),
                        const Color(0xFF00F5FF).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assessment_rounded,
                    color: Color(0xFF9147FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumo do Período',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Estatísticas detalhadas',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRevolutionaryStatRow(
              'Valor médio por transação',
              _formatCurrency(avgTransactionValue),
              Icons.calculate_rounded,
              const Color(0xFF10B981),
            ),
            _buildRevolutionaryDivider(),
            _buildRevolutionaryStatRow(
              'Total de transações',
              '$transactionCount transações',
              Icons.receipt_long_rounded,
              const Color(0xFF3B82F6),
            ),
            _buildRevolutionaryDivider(),
            _buildRevolutionaryStatRow(
              'Tendência de fluxo de caixa',
              _formatTrend(cashFlowTrend),
              _getTrendIcon(cashFlowTrend),
              _getTrendColor(cashFlowTrend),
            ),
            _buildRevolutionaryDivider(),
            _buildRevolutionaryStatRow(
              'Crescimento mensal',
              '${monthlyGrowth >= 0 ? '+' : ''}${monthlyGrowth.toStringAsFixed(1)}%',
              monthlyGrowth >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              monthlyGrowth >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevolutionaryStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevolutionaryDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildRevolutionaryLegendItem(String label, Color color, {String? value}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevolutionaryNoDataCard(String message, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2C2F33).withOpacity(0.95),
            const Color(0xFF36393F).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF9147FF).withOpacity(0.2),
                            const Color(0xFF9147FF).withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 48,
                        color: const Color(0xFF9147FF),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRevolutionaryColorForCategory(String type, int index) {
    if (type == 'income') {
      return _incomeGradients[index % _incomeGradients.length][0];
    } else {
      return _expenseGradients[index % _expenseGradients.length][0];
    }
  }

  List<Color> _getRevolutionaryGradientForCategory(String type, int index) {
    if (type == 'income') {
      return _incomeGradients[index % _incomeGradients.length];
    } else {
      return _expenseGradients[index % _expenseGradients.length];
    }
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
        return Icons.trending_up_rounded;
      case 'negative':
        return Icons.trending_down_rounded;
      case 'stable':
        return Icons.trending_flat_rounded;
      default:
        return Icons.trending_flat_rounded;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'positive':
        return const Color(0xFF10B981);
      case 'negative':
        return const Color(0xFFEF4444);
      case 'stable':
        return const Color(0xFFFF6B35);
      default:
        return const Color(0xFFFF6B35);
    }
  }
}
