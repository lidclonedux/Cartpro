// lib/widgets/voice_command_widget.dart
// Interface completa para comando de voz integrada com VoiceProvider
// VERSÃO CORRIGIDA: Compatível com o novo fluxo de gravação de áudio

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vitrine_borracharia/providers/voice_provider.dart';
import 'package:vitrine_borracharia/providers/transaction_provider.dart';
import 'package:vitrine_borracharia/models/transaction.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class VoiceCommandWidget extends StatefulWidget {
  const VoiceCommandWidget({super.key});

  @override
  State<VoiceCommandWidget> createState() => _VoiceCommandWidgetState();
}

class _VoiceCommandWidgetState extends State<VoiceCommandWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Configurar callbacks do VoiceProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupVoiceProviderCallbacks();
    });
  }

  void _setupVoiceProviderCallbacks() {
    final voiceProvider = context.read<VoiceProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    voiceProvider.setCallbacks(
      onTransactionCreated: (transactionData) async {
        try {
          await transactionProvider.createTransaction(transactionData);
          Logger.info('VoiceCommandWidget: Transação criada via callback do VoiceProvider');
          
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lançamento criado com sucesso via comando de voz!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          Logger.error('VoiceCommandWidget: Erro no callback de criação', error: e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao criar lançamento: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onError: (error) {
        Logger.error('VoiceCommandWidget: Erro via callback do VoiceProvider: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Consumer<VoiceProvider>(
        builder: (context, voiceProvider, child) {
          // Controlar animação baseado no estado (CORRIGIDO para isRecording)
          if (voiceProvider.isRecording) {
            _animationController.repeat(reverse: true);
          } else {
            _animationController.stop();
            _animationController.reset();
          }

          return Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2F33),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(voiceProvider),
                if (voiceProvider.hasConfirmationPending)
                  _buildConfirmationView(voiceProvider)
                else if (voiceProvider.isInConversation)
                  _buildConversationView(voiceProvider)
                else
                  _buildMainView(voiceProvider),
                _buildFooter(voiceProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(VoiceProvider voiceProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF23272A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic,
            color: const Color(0xFF9147FF),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comando de Voz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getStatusText(voiceProvider.currentState),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (!voiceProvider.isRecording && !voiceProvider.hasConfirmationPending)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildMainView(VoiceProvider voiceProvider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Verificar se a gravação está disponível
          if (!voiceProvider.isRecordingAvailable) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gravação de áudio não está disponível. Verifique as permissões.',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => voiceProvider.enableRecording(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tentar Ativar Gravação', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],

          // Botão principal de microfone com animação (CORRIGIDO)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: GestureDetector(
                    onTap: voiceProvider.isRecordingAvailable 
                        ? (voiceProvider.isRecording
                            ? voiceProvider.stopListening
                            : voiceProvider.startListening)
                        : null,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: voiceProvider.isRecording
                            ? Colors.red.withOpacity(0.2)
                            : const Color(0xFF9147FF).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: voiceProvider.isRecording
                              ? Colors.red
                              : (voiceProvider.isRecordingAvailable 
                                  ? const Color(0xFF9147FF)
                                  : Colors.grey),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        voiceProvider.isRecording 
                            ? Icons.stop 
                            : (voiceProvider.isRecordingAvailable 
                                ? Icons.mic_none 
                                : Icons.mic_off),
                        size: 48,
                        color: voiceProvider.isRecording
                            ? Colors.red
                            : (voiceProvider.isRecordingAvailable 
                                ? const Color(0xFF9147FF)
                                : Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          
          // Texto de instrução (CORRIGIDO)
          Text(
            voiceProvider.isRecording
                ? 'Gravando... Fale agora e toque novamente para parar'
                : (voiceProvider.isRecordingAvailable 
                    ? 'Toque no microfone e fale seu comando'
                    : 'Gravação não disponível'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          
          // Exemplos de comandos (apenas se não estiver gravando)
          if (!voiceProvider.isRecording && voiceProvider.isRecordingAvailable) ...[
            const Text(
              'Exemplos:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleCommand('• "Despesa de 50 reais para almoço"'),
            _buildExampleCommand('• "Receita de 1000 reais de venda"'),
            _buildExampleCommand('• "Gasto de 200 reais em combustível"'),
          ],
          
          // Transcript atual
          if (voiceProvider.currentTranscript.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF36393F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hearing, color: Color(0xFF9147FF), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Comando detectado:',
                        style: TextStyle(
                          color: Color(0xFF9147FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${voiceProvider.currentTranscript}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationView(VoiceProvider voiceProvider) {
    return Expanded(
      child: Column(
        children: [
          // Lista de conversas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: voiceProvider.conversation.length,
              itemBuilder: (context, index) {
                final message = voiceProvider.conversation[index];
                return _buildConversationMessage(message);
              },
            ),
          ),
          
          // Campo de entrada manual (opcional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF36393F), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    voiceProvider.missingFields.isNotEmpty
                        ? 'Aguardando: ${voiceProvider.missingFields.first}'
                        : 'Conversa em andamento...',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (voiceProvider.isRecordingAvailable)
                  IconButton(
                    onPressed: voiceProvider.isRecording 
                        ? voiceProvider.stopListening 
                        : voiceProvider.startListening,
                    icon: Icon(
                      voiceProvider.isRecording ? Icons.stop : Icons.mic, 
                      color: voiceProvider.isRecording ? Colors.red : const Color(0xFF9147FF)
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationMessage(ConversationMessage message) {
    final isUser = message.sender == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF9147FF),
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF9147FF)
                    : const Color(0xFF36393F),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Text(
                message.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF36393F),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationView(VoiceProvider voiceProvider) {
    final confirmation = voiceProvider.pendingConfirmation!;
    final transactionData = confirmation['transaction_data'] as Map<String, dynamic>;
    final category = confirmation['category'];

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ícone de confirmação
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF9147FF).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF9147FF),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 40,
                color: Color(0xFF9147FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Confirmar Lançamento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comando: "${confirmation['original_command']}"',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Detalhes da transação
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF36393F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfirmationDetail(
                      'Descrição',
                      transactionData['description'] ?? 'N/A',
                      Icons.description,
                    ),
                    _buildConfirmationDetail(
                      'Tipo',
                      transactionData['type'] == 'income' ? 'Receita' : 'Despesa',
                      transactionData['type'] == 'income'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    _buildConfirmationDetail(
                      'Valor',
                      voiceProvider.formatCurrency(transactionData['amount']?.toDouble() ?? 0.0),
                      Icons.attach_money,
                    ),
                    _buildConfirmationDetail(
                      'Data',
                      _formatDateFromString(transactionData['date']),
                      Icons.calendar_today,
                    ),
                    if (category != null)
                      _buildConfirmationDetail(
                        'Categoria',
                        category.name ?? 'N/A',
                        Icons.category,
                      ),
                    if (transactionData['is_recurring'] == true)
                      _buildConfirmationDetail(
                        'Recorrência',
                        'Todo dia ${transactionData['recurring_day']} do mês',
                        Icons.repeat,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      voiceProvider.cancelTransaction();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmTransaction(voiceProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9147FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationDetail(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9147FF), size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(VoiceProvider voiceProvider) {
    if (voiceProvider.errorMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                voiceProvider.errorMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (voiceProvider.successMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                voiceProvider.successMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildExampleCommand(String command) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        command,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getStatusText(VoiceState state) {
    switch (state) {
      case VoiceState.idle:
        return 'Pronto para gravar comandos';
      case VoiceState.recording:  // CORRIGIDO: era listening
        return 'Gravando...';
      case VoiceState.processing:
        return 'Processando comando...';
      case VoiceState.conversation:
        return 'Conversa em andamento';
      case VoiceState.confirmation:
        return 'Aguardando confirmação';
      case VoiceState.error:
        return 'Erro no processamento';
    }
  }

  String _formatDateFromString(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/'
             '${date.month.toString().padLeft(2, '0')}/'
             '${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Método de confirmação atualizado
  Future<void> _confirmTransaction(VoiceProvider voiceProvider) async {
    try {
      // Usar o método próprio do VoiceProvider que já tem os callbacks configurados
      await voiceProvider.confirmTransaction();
      
      Logger.info('VoiceCommandWidget: Confirmação delegada ao VoiceProvider');
      
    } catch (e) {
      Logger.error('VoiceCommandWidget: Erro ao confirmar transação', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao confirmar lançamento: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
