// lib/screens/admin/tabs/accounting_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/providers/accounting_provider.dart';
import 'package:vitrine_borracharia/providers/auth_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';
import 'package:vitrine_borracharia/utils/temp_lucide_icons.dart';

// --- CORREÇÃO ESTÁ AQUI ---
// O caminho correto para importar o arquivo, baseado na sua estrutura de pastas.
import '../accounting/accounting_home_screen.dart';
// --------------------------

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  // Não precisamos mais chamar o fetch no initState, pois o pré-carregamento
  // no AdminScreen já está fazendo isso. Esta tela agora apenas reflete o estado.
  // A chamada foi removida para evitar buscas duplicadas.

  // NOVO: Função para tentar buscar os dados novamente
  Future<void> _retryFetch() async {
    Logger.info('AccountingScreen: Tentando buscar dados do resumo novamente...');
    // Chama o fetch com isPreload: false para mostrar o indicador de carregamento
    await Provider.of<AccountingProvider>(context, listen: false).fetchDashboardSummary(isPreload: false);
  }

  @override
  Widget build(BuildContext context) {
    // Usamos um Consumer simples aqui, pois o AuthProvider já foi verificado
    // no widget pai que mostra as abas.
    return Consumer<AccountingProvider>(
      builder: (context, accountingProvider, child) {
        return RefreshIndicator(
          onRefresh: _retryFetch,
          backgroundColor: const Color(0xFF2C2F33),
          color: const Color(0xFF9147FF),
          child: SingleChildScrollView(
            // Garante que o SingleChildScrollView sempre possa ser "puxado" para atualizar
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Painel de Contabilidade',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // =======================================================================
                // === LÓGICA DE RENDERIZAÇÃO INTELIGENTE ===
                // =======================================================================
                _buildContent(accountingProvider),
                // =======================================================================
                const SizedBox(height: 16),
                _buildAccountingAccessCard(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Constrói o conteúdo principal baseado no estado do AccountingProvider
  Widget _buildContent(AccountingProvider provider) {
    // ESTADO 1: Carregando (se não for pré-carregamento)
    if (provider.isLoading && provider.dashboardSummary == null) {
      Logger.info('AccountingScreen: Exibindo estado de CARREGAMENTO.');
      return _buildLoadingState();
    }

    // ESTADO 2: Erro
    if (provider.errorMessage != null && provider.dashboardSummary == null) {
      Logger.error('AccountingScreen: Exibindo estado de ERRO: ${provider.errorMessage}');
      return _buildErrorState(provider.errorMessage!);
    }

    // ESTADO 3: Sucesso (mesmo que os dados sejam nulos, mas sem erro)
    // Isso cobre o caso de não haver transações ainda.
    Logger.info('AccountingScreen: Exibindo cards de resumo.');
    return _buildSummaryCards(provider.dashboardSummary);
  }

  /// Widget para o estado de carregamento
  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF9147FF)),
            SizedBox(height: 16),
            Text(
              'Buscando resumo financeiro...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget para o estado de erro
  Widget _buildErrorState(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Falha ao Carregar Resumo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            // Mostra a mensagem de erro real vinda da API
            errorMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _retryFetch,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic>? summary) {
    // Se o summary for nulo (após o carregamento inicial), mostra valores zerados.
    // Isso evita que a tela quebre se a API retornar um sucesso com corpo vazio.
    final totalIncome = summary?['total_income'] ?? 0.0;
    final totalExpenses = summary?['total_expenses'] ?? 0.0;
    final balance = summary?['balance'] ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Receitas',
                'R\$${(totalIncome as num).toStringAsFixed(2)}',
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Despesas',
                'R\$${(totalExpenses as num).toStringAsFixed(2)}',
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSummaryCard(
          'Saldo Total',
          'R\$${(balance as num).toStringAsFixed(2)}',
          balance >= 0 ? Colors.blue : Colors.red,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      color: const Color(0xFF2C2F33),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountingAccessCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF23272A),
      child: InkWell(
        onTap: () {
          Logger.info("Contabilidade: Navegando para o hub de Contabilidade Inteligente");
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AccountingHomeScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF9147FF),
                const Color(0xFF6A11CB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Contabilidade Inteligente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(LucideIcons.arrowRight, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
