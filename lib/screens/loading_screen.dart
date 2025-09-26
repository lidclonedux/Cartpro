// lib/screens/loading_screen.dart - VERSÃO SIMPLIFICADA
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _currentLoadingText = 'Carregando dados...';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Inicia o carregamento assim que a tela é criada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      Logger.info('LoadingScreen: Iniciando carregamento de dados');

      _updateLoadingText('Verificando autenticação...');
      
      if (!authProvider.isLoggedIn) {
        Logger.info('LoadingScreen: Usuário não logado, finalizando');
        return;
      }

      _updateLoadingText('Carregando produtos...');
      await Future.delayed(const Duration(milliseconds: 500)); // Pequena pausa visual

      _updateLoadingText('Carregando pedidos...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Chama o método centralizado do AuthProvider para carregar dados
      await authProvider.loadUserData(context);

      _updateLoadingText('Finalizando...');
      await Future.delayed(const Duration(milliseconds: 500));

      Logger.info('LoadingScreen: Carregamento completo');

    } catch (e) {
      Logger.error('LoadingScreen: Erro durante carregamento', error: e);
      setState(() {
        _hasError = true;
        _errorMessage = 'Erro ao carregar dados: ${e.toString()}';
      });
      
      // Mesmo com erro, permite prosseguir após 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          // Força o carregamento como completo para prosseguir
          authProvider.loadUserData(context);
        }
      });
    }
  }

  void _updateLoadingText(String text) {
    if (mounted) {
      setState(() {
        _currentLoadingText = text;
      });
    }
  }

  void _retryLoading() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _currentLoadingText = 'Tentando novamente...';
    });
    _loadData();
  }

  void _forceNext() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.loadUserData(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF9147FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.store,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              if (_hasError) ...[
                // Estado de erro
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ops! Algo deu errado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Erro desconhecido',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _retryLoading,
                  child: const Text('Tentar Novamente'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _forceNext,
                  child: const Text(
                    'Continuar mesmo assim',
                    style: TextStyle(color: Color(0xFF7289DA)),
                  ),
                ),
              ] else ...[
                // Estado de carregamento normal
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9147FF)),
                ),
                const SizedBox(height: 24),
                Text(
                  _currentLoadingText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Isso pode levar alguns segundos...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
