// lib/screens/splash_screen.dart - VERSÃO CORRIGIDA
import 'package:flutter/material.dart';
import '../utils/logger.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou imagem do app
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF9147FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.store,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            // Nome do app
            const Text(
              'Vitrine Borracharia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gothic',
              ),
            ),
            const SizedBox(height: 16),
            // Subtítulo ou slogan
            const Text(
              'Sua loja digital de pneus e rodas',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'Gothic',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Indicador de carregamento simples
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9147FF)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Iniciando...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontFamily: 'Gothic',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
