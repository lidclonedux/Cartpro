import 'package:flutter/material.dart';
import 'package:vitrine_borracharia/utils/temp_lucide_icons.dart';

// Importar todas as telas reais
import 'dashboard/accounting_dashboard_screen.dart';
import 'transactions/admin_transactions_screen.dart';
import 'import/admin_import_screen.dart';
import 'categories/admin_categories_screen.dart';
import 'recurring/admin_recurring_screen.dart';
import 'reports/admin_reports_screen.dart';

class AccountingHomeScreen extends StatefulWidget {
  const AccountingHomeScreen({super.key});

  @override
  State<AccountingHomeScreen> createState() => _AccountingHomeScreenState();
}

class _AccountingHomeScreenState extends State<AccountingHomeScreen> {
  int _selectedIndex = 0;

  // Telas reais substituindo os placeholders
  static final List<Widget> _widgetOptions = <Widget>[
    const AccountingDashboardScreen(), // Dashboard REAL (já funciona)
    const AdminTransactionsScreen(),   // Tela REAL de transações
    const AdminImportScreen(),         // Tela REAL de importação
    const AdminCategoriesScreen(),     // Tela REAL de categorias
    const AdminRecurringScreen(),      // Tela REAL de recorrentes
    const AdminReportsScreen(),        // Tela REAL de relatórios
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contabilidade Inteligente'),
        backgroundColor: const Color(0xFF23272A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFF23272A), // Fundo escuro para todas as telas
        child: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.layoutDashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.arrowUpDown),
            label: 'Lançamentos',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.upload),
            label: 'Importar',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.folderOpen),
            label: 'Categorias',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.repeat),
            label: 'Recorrentes',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.barChart3),
            label: 'Relatórios',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF23272A),
        selectedItemColor: const Color(0xFF9147FF),
        unselectedItemColor: Colors.white54,
      ),
    );
  }
}
