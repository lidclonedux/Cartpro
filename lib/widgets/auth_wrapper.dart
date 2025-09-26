// lib/widgets/auth_wrapper.dart - VERSÃO SIMPLIFICADA E CORRIGIDA
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/home_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/login_screen.dart';
import '../utils/logger.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Inicializa o sistema assim que o widget é criado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // FASE 1: Splash Screen - Sistema inicializando
        if (authProvider.shouldShowSplash) {
          Logger.info('AuthWrapper: Exibindo SplashScreen - Sistema inicializando');
          return const SplashScreen();
        }

        // FASE 2: Login Screen - Usuário não autenticado
        if (authProvider.shouldShowLogin) {
          Logger.info('AuthWrapper: Exibindo LoginScreen - Usuário não logado');
          return const LoginScreen();
        }

        // FASE 3: Loading Screen - Carregando dados do usuário
        if (authProvider.shouldShowLoading) {
          Logger.info('AuthWrapper: Exibindo LoadingScreen - Carregando dados');
          return const LoadingScreen();
        }

        // FASE 4: Aplicação - Tudo pronto
        if (authProvider.shouldShowApp) {
          if (authProvider.user!.isAdmin) {
            Logger.info('AuthWrapper: Exibindo AdminScreen - Usuário admin');
            return const AdminScreen();
          } else {
            Logger.info('AuthWrapper: Exibindo HomeScreen - Usuário cliente');
            return const HomeScreen();
          }
        }

        // Fallback - não deveria chegar aqui
        Logger.warning('AuthWrapper: Estado inesperado, exibindo SplashScreen');
        return const SplashScreen();
      },
    );
  }
}
