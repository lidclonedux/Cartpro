import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// Supondo que estes arquivos existam no seu projeto
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/services/api_service.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

enum VoiceState {
  idle,
  recording,
  processing,
  conversation,
  confirmation,
  error
}

class ConversationMessage {
  final String sender;
  final String message;
  final DateTime timestamp;

  ConversationMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}

class VoiceProvider with ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();

  bool _recordingAvailable = false;
  VoiceState _currentState = VoiceState.idle;
  String _currentTranscript = '';
  String _errorMessage = '';
  String _successMessage = '';
  List<ConversationMessage> _conversation = [];
  Map<String, dynamic> _currentTransaction = {};
  List<String> _missingFields = [];
  Map<String, dynamic>? _pendingConfirmation;
  List<AccountingCategory> _categories = [];
  String _context = 'business';
  Function(Map<String, dynamic>)? _onTransactionCreated;
  Function(String)? _onError;

  // --- Getters para a UI ---
  VoiceState get currentState => _currentState;
  String get currentTranscript => _currentTranscript;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  List<ConversationMessage> get conversation => List.unmodifiable(_conversation);
  Map<String, dynamic>? get pendingConfirmation => _pendingConfirmation;
  bool get isRecording => _currentState == VoiceState.recording;
  bool get isInConversation => _currentState == VoiceState.conversation;
  bool get hasConfirmationPending => _currentState == VoiceState.confirmation;
  bool get isRecordingAvailable => _recordingAvailable;
  List<String> get missingFields => List.unmodifiable(_missingFields); // <-- ADICIONADO DE VOLTA

  VoiceProvider() {
    _initializeRecording();
    Logger.info('VoiceProvider: Inicializado com gravador multiplataforma.');
  }

  Future<void> _initializeRecording() async {
    try {
      _recordingAvailable = await _audioRecorder.hasPermission();
      if (_recordingAvailable) {
        Logger.info('VoiceProvider: ✅ Permissões de gravação OK.');
      } else {
        Logger.warning('VoiceProvider: ⚠️ Permissão de gravação negada.');
      }
    } catch (e) {
      _recordingAvailable = false;
      Logger.error('VoiceProvider: ❌ FALHA ao verificar permissões', error: e);
    }
    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_recordingAvailable) {
      _setError('Gravação de áudio não está disponível.');
      return;
    }
    if (_currentState != VoiceState.idle && _currentState != VoiceState.error) {
      Logger.warning('VoiceProvider: Tentativa de iniciar gravação em estado inválido ($_currentState). Ignorando.');
      return;
    }

    try {
      _clearMessages();
      _resetConversationState();
      _setState(VoiceState.recording);

      const config = RecordConfig(encoder: AudioEncoder.aacLc);

      if (kIsWeb) {
        await _audioRecorder.start(config, path: '');
      } else {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/voice_command_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(config, path: path);
      }

      Logger.info('VoiceProvider: Gravação iniciada.');
    } catch (e) {
      _setError('Erro ao iniciar gravação: ${e.toString()}');
    }
  }

  Future<void> stopListening() async {
    if (!await _audioRecorder.isRecording()) return;

    String? path;
    try {
      path = await _audioRecorder.stop();
      if (path == null) {
        _setError('Gravação falhou ou foi cancelada.');
        _setState(VoiceState.idle);
        return;
      }

      _setState(VoiceState.processing);

      final result = kIsWeb
          ? await _apiService.processVoiceCommandFromWeb(path)
          : await _apiService.processVoiceCommandFromFile(File(path));

      if (result['success'] == true) {
        final entities = result['entities'] as Map<String, dynamic>?;
        final transcript = result['transcript'] as String?;

        if (entities != null && transcript != null) {
          _currentTranscript = transcript;
          _addConversationMessage('user', transcript);
          await _processVoiceEntities(entities);
        } else {
          _setError('Resposta incompleta do servidor.');
        }
      } else {
        _setError(result['error'] ?? 'Erro desconhecido no processamento');
      }
    } catch (e) {
      _setError('Erro ao processar comando de voz: ${e.toString()}');
    } finally {
      if (!kIsWeb && path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            Logger.info('VoiceProvider: Arquivo temporário deletado: $path');
          }
        } catch (e) {
          Logger.warning('Falha ao deletar arquivo temporário: $e');
        }
      }
    }
  }

  Future<void> _processVoiceEntities(Map<String, dynamic> entities) async {
    _currentTransaction = Map.from(entities);
    _currentTransaction['context'] = _context;

    List<String> requiredFields = ['type', 'amount', 'description'];
    _missingFields = requiredFields.where((f) =>
      !_currentTransaction.containsKey(f) || _currentTransaction[f] == null || _currentTransaction[f].toString().trim().isEmpty
    ).toList();

    if (_missingFields.isNotEmpty) {
      _setState(VoiceState.conversation);
      _askForNextMissingField();
    } else {
      await _prepareConfirmation();
    }
  }

  void handleConversationResponse(String response) {
    if (_missingFields.isEmpty) return;
    
    _addConversationMessage('user', response);
    final currentField = _missingFields.first;
    dynamic fieldValue = _processFieldResponse(currentField, response);

    if (fieldValue != null) {
      _currentTransaction[currentField] = fieldValue;
      _missingFields.removeAt(0);
      String confirmation = _generateFieldConfirmation(currentField, fieldValue);
      _addConversationMessage('assistant', confirmation);

      if (_missingFields.isNotEmpty) {
        _askForNextMissingField();
      } else {
        _setState(VoiceState.processing);
        _prepareConfirmation();
      }
    } else {
      String clarification = _generateClarificationQuestion(currentField);
      _addConversationMessage('assistant', clarification);
    }
  }

  dynamic _processFieldResponse(String field, String response) {
    switch (field) {
      case 'type':
        final r = response.toLowerCase();
        if (r.contains('receita') || r.contains('entrada') || r.contains('ganho')) return 'income';
        if (r.contains('despesa') || r.contains('gasto') || r.contains('saída')) return 'expense';
        return null;
      case 'amount':
        RegExp regex = RegExp(r'(\d+[,.]?\d*)');
        Match? match = regex.firstMatch(response.replaceAll('reais', '').trim());
        if (match != null) {
          return double.tryParse(match.group(1)!.replaceAll(',', '.'));
        }
        return null;
      case 'description':
        return response.trim().isEmpty ? null : response.trim();
      default:
        return response.trim().isEmpty ? null : response.trim();
    }
  }

  void _askForNextMissingField() {
    if (_missingFields.isEmpty) return;
    final question = _generateQuestionForField(_missingFields.first);
    _addConversationMessage('assistant', question);
  }

  String _generateQuestionForField(String field) {
    switch (field) {
      case 'type': return 'Isso foi uma receita (entrada) ou uma despesa (saída)?';
      case 'amount': return 'Qual foi o valor em reais?';
      case 'description': return 'Pode me dar uma breve descrição?';
      default: return 'Preciso de mais detalhes sobre $field.';
    }
  }

  String _generateFieldConfirmation(String field, dynamic value) {
    switch (field) {
      case 'type': return value == 'income' ? 'Entendi, uma receita.' : 'Ok, uma despesa.';
      case 'amount': return 'Valor registrado: ${formatCurrency(value as double)}';
      case 'description': return 'Descrição: "$value"';
      default: return 'Ok, $field definido.';
    }
  }

  String _generateClarificationQuestion(String field) {
    switch (field) {
      case 'type': return 'Não entendi. É uma entrada ou saída de dinheiro?';
      case 'amount': return 'Não consegui identificar um valor. Pode repetir, por favor?';
      case 'description': return 'Preciso de uma descrição. Para que foi essa transação?';
      default: return 'Não entendi. Pode repetir a informação sobre $field?';
    }
  }

  Future<void> _prepareConfirmation() async {
    _pendingConfirmation = {
      'transaction_data': Map.from(_currentTransaction),
      'category': null,
    };
    _setState(VoiceState.confirmation);
  }

  Future<void> confirmTransaction() async {
    if (_pendingConfirmation == null) return;
    try {
      _setState(VoiceState.processing);
      final transactionData = _pendingConfirmation!['transaction_data'] as Map<String, dynamic>;
      
      _onTransactionCreated?.call(transactionData);
      _setSuccess('Transação criada com sucesso!');
      reset();
    } catch (e) {
      _setError('Erro ao criar transação: ${e.toString()}');
    }
  }

  void cancelTransaction() {
    _setSuccess('Comando cancelado.');
    reset();
  }

  void _setState(VoiceState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = '';
    _setState(VoiceState.error);
    Logger.error('VoiceProvider: $message');
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = '';
    Logger.info('VoiceProvider: $message');
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  void _addConversationMessage(String sender, String message) {
    _conversation.add(ConversationMessage(sender: sender, message: message, timestamp: DateTime.now()));
    notifyListeners();
  }

  void _resetConversationState() {
    _conversation.clear();
    _currentTransaction.clear();
    _missingFields.clear();
    _pendingConfirmation = null;
    _currentTranscript = '';
  }

  void reset() {
    _resetConversationState();
    _setState(VoiceState.idle);
    Logger.info('VoiceProvider: Provider resetado.');
  }

  void setCallbacks({Function(Map<String, dynamic>)? onTransactionCreated, Function(String)? onError}) {
    _onTransactionCreated = onTransactionCreated;
    _onError = onError;
  }

  void updateCategories(List<AccountingCategory> categories) {
    _categories = categories;
  }

  // Método para re-tentar a inicialização da gravação, caso a permissão seja negada inicialmente
  Future<void> enableRecording() async { // <-- ADICIONADO DE VOLTA
    if (!_recordingAvailable) {
      await _initializeRecording();
    }
  }

  String formatCurrency(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  String getTransactionTypeLabel(String type) => type == 'income' ? 'Receita' : 'Despesa';
  Color getTransactionTypeColor(String type) => type == 'income' ? Colors.green : Colors.red;
  IconData getTransactionTypeIcon(String type) => type == 'income' ? Icons.arrow_upward : Icons.arrow_downward;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
    Logger.info('VoiceProvider: Disposed');
  }
}
