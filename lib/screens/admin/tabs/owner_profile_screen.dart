import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Boa prática: Usar import de pacote em vez de relativo
import 'package:vitrine_borracharia/providers/auth_provider.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

        if (user == null) {
          return const Center(
            child: Text(
              'Nenhum usuário logado.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perfil do Proprietário',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _buildProfileInfo(context, 'Nome de Usuário', user.username, Icons.person),
              const SizedBox(height: 16),
              // CORREÇÃO APLICADA AQUI:
              _buildProfileInfo(context, 'Nome de Exibição', user.displayName ?? 'Não informado', Icons.badge_outlined),
              const SizedBox(height: 16),
              // CORREÇÃO APLICADA AQUI:
              _buildProfileInfo(context, 'Email', user.email ?? 'Não informado', Icons.email),
              const SizedBox(height: 16),
              _buildProfileInfo(context, 'Telefone', user.phoneNumber ?? 'Não informado', Icons.phone),
              const SizedBox(height: 16),
              _buildProfileInfo(context, 'Função', user.role, Icons.work),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Logger.info('OwnerProfileScreen: Botão de Logout pressionado');
                    await authProvider.logout(context);
                    // Após o logout, o AuthWrapper deve redirecionar para a tela de login
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Sair da Conta',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfo(BuildContext context, String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9147FF), size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
