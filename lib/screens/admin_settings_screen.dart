// lib/screens/admin_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final _contactFormKey = GlobalKey<FormState>();
  final _pixFormKey = GlobalKey<FormState>();
  
  // Controladores dos formulários
  final _phoneController = TextEditingController();
  final _pixKeyController = TextEditingController();
  final _pixQrCodeUrlController = TextEditingController();
  
  bool _isLoadingContact = false;
  bool _isLoadingPix = false;
  String? _contactError;
  String? _pixError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _pixKeyController.dispose();
    _pixQrCodeUrlController.dispose();
    super.dispose();
  }

  void _loadCurrentUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null) {
      // Pré-preenche os campos com os dados atuais do usuário, se existirem
      _phoneController.text = user.phoneNumber ?? '';
      _pixKeyController.text = user.pixKey ?? '';
      _pixQrCodeUrlController.text = user.pixQrCodeUrl ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Configurações do Admin'),
        backgroundColor: const Color(0xFF23272A),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Contato', icon: Icon(Icons.phone)),
            Tab(text: 'PIX', icon: Icon(Icons.pix)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactTab(),
          _buildPixTab(),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _contactFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'Informações de Contato',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure suas informações de contato que serão exibidas para os clientes.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            // Campo de Telefone/WhatsApp
            TextFormField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Telefone / WhatsApp',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Ex: (11) 99999-9999',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O número de telefone é obrigatório';
                }
                // Validação básica de telefone (pelo menos 10 dígitos)
                final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
                if (cleaned.length < 10) {
                  return 'Digite um número de telefone válido';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Informações extras
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Informação',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Este número será exibido nos pedidos e poderá ser usado pelos clientes para entrar em contato.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botão de salvar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingContact ? null : _saveContactInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingContact
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Salvando...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text('Salvar Informações de Contato'),
                        ],
                      ),
              ),
            ),
            
            // Mensagem de erro
            if (_contactError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _contactError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPixTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _pixFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pix, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'Configurações PIX',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure suas informações do PIX para recebimento de pagamentos.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            // Campo da Chave PIX
            TextFormField(
              controller: _pixKeyController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Chave PIX',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Ex: seu@email.com ou 11999999999',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.key, color: Colors.green),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'A chave PIX é obrigatória';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Campo da URL do QR Code
            TextFormField(
              controller: _pixQrCodeUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'URL do QR Code PIX (Opcional)',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'https://exemplo.com/qrcode.png',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.qr_code, color: Colors.green),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  // <<< CORREÇÃO APLICADA AQUI >>>
                  if ((Uri.tryParse(value)?.hasAbsolutePath ?? false) == false) {
                    return 'Digite uma URL válida';
                  }
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Informações sobre o PIX
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sobre o PIX',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• A chave PIX será exibida nos pedidos para pagamento\n'
                    '• O QR Code (se fornecido) facilitará o pagamento pelos clientes\n'
                    '• Você pode usar email, telefone, CPF ou chave aleatória',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botão de salvar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingPix ? null : _savePixInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingPix
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Salvando...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text('Salvar Configurações PIX'),
                        ],
                      ),
              ),
            ),
            
            // Mensagem de erro
            if (_pixError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pixError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Método para salvar informações de contato
  Future<void> _saveContactInfo() async {
    if (!_contactFormKey.currentState!.validate()) return;

    setState(() {
      _isLoadingContact = true;
      _contactError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = authProvider.apiService;

      if (apiService == null) {
        throw Exception('Serviço de API não disponível');
      }

      final response = await apiService.updateContactInfo(_phoneController.text.trim());

      if (response['success'] == true) {
        // Atualiza o usuário local com as novas informações
        if (response['user'] != null) {
          // Aqui você precisará implementar um método no AuthProvider para atualizar os dados
             authProvider.updateUserFromJson(response['user']);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informações de contato salvas com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Erro ao salvar informações de contato', error: e);
      setState(() {
        _contactError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContact = false;
        });
      }
    }
  }

  // Método para salvar informações do PIX
  Future<void> _savePixInfo() async {
    if (!_pixFormKey.currentState!.validate()) return;

    setState(() {
      _isLoadingPix = true;
      _pixError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = authProvider.apiService;

      if (apiService == null) {
        throw Exception('Serviço de API não disponível');
      }

      final response = await apiService.updatePixInfo(
        _pixKeyController.text.trim(),
        _pixQrCodeUrlController.text.trim(),
      );

      if (response['success'] == true) {
        // Atualiza o usuário local com as novas informações
        if (response['user'] != null) {
          // Aqui você precisará implementar um método no AuthProvider para atualizar os dados
             authProvider.updateUserFromJson(response['user']);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configurações PIX salvas com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Erro ao salvar configurações PIX', error: e);
      setState(() {
        _pixError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPix = false;
        });
      }
    }
  }
}
