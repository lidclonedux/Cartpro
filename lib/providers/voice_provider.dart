import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/services/voice_nlp_processor.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

// Importações condicionais para Web e Mobile
import 'package:speech_to_text/speech_to_text.dart'
    if (dart.library.html) 'package:vitrine_borracharia/services/web_speech_api.dart';

enum VoiceState {
  idle,
  listening,
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
  // <<< `_speechToText` é dinâmico para aceitar ambas as implementações >>>
  dynamic _speechToText;
  late VoiceNlpProcessor _nlpProcessor;
  bool _speechAvailable = false;

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

  VoiceState get currentState => _currentState;
  String get currentTranscript => _currentTranscript;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  List<ConversationMessage> get conversation => List.unmodifiable(_conversation);
  Map<String, dynamic> get currentTransaction => Map.from(_currentTransaction);
  List<String> get missingFields => List.from(_missingFields);
  Map<String, dynamic>? get pendingConfirmation => _pendingConfirmation;
  bool get isListening => _currentState == VoiceState.listening;
  bool get isInConversation => _currentState == VoiceState.conversation;
  bool get hasConfirmationPending => _currentState == VoiceState.confirmation;
  bool get isSpeechAvailable => _speechAvailable;

  VoiceProvider() {
    _nlpProcessor = VoiceNlpProcessor();
    _initializeSpeechToText();
    Logger.info('VoiceProvider: Inicializado');
  }

  // <<< Lógica de inicialização para Web e Mobile com logs detalhados >>>
  Future<void> _initializeSpeechToText() async {
    Logger.info('VoiceProvider: [1/3] Tentando inicializar SpeechToText...');
    try {
      // Cria a instância correta para a plataforma
      _speechToText = SpeechToText();

      bool available = await _speechToText.initialize(
        onError: _handleSpeechError,
        onStatus: _handleSpeechStatus,
      );

      if (available) {
        _speechAvailable = true;
        Logger.info('VoiceProvider: [2/3] ✅ Speech-to-text inicializado com sucesso para a plataforma atual.');
      } else {
        _speechAvailable = false;
        Logger.warning('VoiceProvider: [2/3] ⚠️ Speech-to-text não disponível neste dispositivo.');
      }
      notifyListeners(); // Notifica a UI sobre a disponibilidade
    } catch (e) {
      _speechAvailable = false;
      Logger.error('VoiceProvider: [2/3] ❌ FALHA CRÍTICA ao inicializar speech-to-text', error: e);
      notifyListeners();
    }
    Logger.info('VoiceProvider: [3/3] Final da inicialização. Disponível: $_speechAvailable');
  }

  // <<< CORREÇÃO PRINCIPAL: `startListening` com feedback visual imediato e logs >>>
  Future<void> startListening() async {
    Logger.info('VoiceProvider: [A] `startListening` chamado. Estado atual: $_currentState');
    
    if (!_speechAvailable) {
      Logger.warning('VoiceProvider: [B] Speech não está disponível. Tentando re-inicializar...');
      await _initializeSpeechToText();
      if (!_speechAvailable) {
        _setError('Reconhecimento de voz não está disponível neste dispositivo.');
        Logger.error('VoiceProvider: [C] Re-inicialização falhou. Abortando.');
        return;
      }
      Logger.info('VoiceProvider: [D] Re-inicialização bem-sucedida.');
    }

    if (_isProcessing()) {
      Logger.warning('VoiceProvider: [E] Tentativa de iniciar escuta durante processamento. Ignorando.');
      return;
    }

    try {
      _clearMessages();
      _currentTranscript = '';
      
      // <<< CORREÇÃO APLICADA AQUI >>>
      // Muda o estado ANTES de chamar a função assíncrona `listen`.
      // Isso garante que a UI (animação, cor) reaja instantaneamente ao toque.
      _setState(VoiceState.listening);
      Logger.info('VoiceProvider: [F] Estado alterado para `listening`. UI deve reagir agora.');

      // A chamada `listen` agora funciona para ambas as implementações
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        localeId: 'pt_BR',
      );

      Logger.info('VoiceProvider: [G] Chamada `listen` executada com sucesso.');
    } catch (e) {
      Logger.error('VoiceProvider: [H] ❌ Erro ao chamar `listen`', error: e);
      _setError('Erro ao iniciar escuta: ${e.toString()}');
      // Se der erro, volta pro estado idle para permitir nova tentativa
      _setState(VoiceState.idle);
    }
  }

  // <<< `stopListening` compatível com Web e Mobile >>>
  Future<void> stopListening() async {
    if (_speechToText != null && _speechAvailable) {
      try {
        await _speechToText.stop();
        Logger.info('VoiceProvider: Parou escuta manualmente');
      } catch (e) {
        Logger.warning('VoiceProvider: Erro ao parar escuta: $e');
      }
    }

    if (_currentState == VoiceState.listening) {
      _setState(VoiceState.idle);
    }
  }

  void setCallbacks({
    Function(Map<String, dynamic>)? onTransactionCreated,
    Function(String)? onError,
  }) {
    _onTransactionCreated = onTransactionCreated;
    _onError = onError;
  }

  Future<void> _createTransactionFromVoice(Map<String, dynamic> transactionData) async {
    try {
      if (_onTransactionCreated != null) {
        await _onTransactionCreated!(transactionData);
        Logger.info('VoiceProvider: Transação criada via callback');
      } else {
        Logger.warning('VoiceProvider: Nenhum callback definido para criar transação');
        _setSuccess('Transação processada - configure callback para salvar');
      }
    } catch (e) {
      final errorMsg = 'Erro ao criar transação: ${e.toString()}';
      if (_onError != null) {
        _onError!(errorMsg);
      } else {
        _setError(errorMsg);
      }
      rethrow;
    }
  }

  void updateCategories(List<AccountingCategory> categories) {
    _categories = categories;
    _nlpProcessor.updateCategories(categories);
    Logger.info('VoiceProvider: ${categories.length} categorias atualizadas');
    notifyListeners();
  }

  void setContext(String context) {
    _context = context;
    Logger.info('VoiceProvider: Contexto alterado para $context');
  }

  void _setState(VoiceState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      Logger.debug('VoiceProvider: Estado alterado para $newState');
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

  bool _isProcessing() {
    return _currentState == VoiceState.processing ||
           _currentState == VoiceState.conversation;
  }

  void _handleSpeechResult(dynamic result) {
    try {
      final recognizedWords = result?.recognizedWords ?? '';
      final finalResult = result?.finalResult ?? false;

      _currentTranscript = recognizedWords;

      Logger.debug('VoiceProvider: Transcript atualizado - "$_currentTranscript"');
      notifyListeners();

      if (finalResult && _currentTranscript.isNotEmpty) {
        _processVoiceInput(_currentTranscript);
      }
    } catch (e) {
      Logger.error('VoiceProvider: Erro ao processar resultado de voz', error: e);
      _setError('Erro ao processar áudio: ${e.toString()}');
    }
  }

  void _handleSpeechError(dynamic error) {
    try {
      String errorMsg = 'Erro no reconhecimento: ';
      final errorMsgStr = error?.errorMsg ?? error.toString();

      switch (errorMsgStr) {
        case 'error_network_timeout':
          errorMsg += 'Tempo esgotado. Verifique sua conexão.';
          break;
        case 'error_no_match':
          errorMsg += 'Não consegui entender. Tente falar mais claramente.';
          break;
        case 'error_speech_timeout':
          errorMsg += 'Não detectei fala. Tente novamente.';
          break;
        case 'not-allowed': // Erro comum da Web API
          errorMsg += 'Permissão para usar o microfone foi negada.';
          break;
        default:
          errorMsg += errorMsgStr;
      }

      _setError(errorMsg);
      Logger.error('VoiceProvider: Speech error - $errorMsgStr');
    } catch (e) {
      _setError('Erro no reconhecimento de voz');
      Logger.error('VoiceProvider: Erro ao processar erro de speech', error: e);
    }
  }

  void _handleSpeechStatus(String status) {
    Logger.debug('VoiceProvider: Speech status - $status');

    switch (status) {
      case 'listening':
        _setState(VoiceState.listening);
        break;
      case 'notListening':
        if (_currentState == VoiceState.listening) {
          _setState(VoiceState.idle);
        }
        break;
      case 'done':
        break;
    }
  }

  Future<void> processTextCommand(String command) async {
    if (command.trim().isEmpty) {
      _setError('Comando não pode estar vazio');
      return;
    }

    Logger.info('VoiceProvider: Processando comando de texto: "$command"');
    await _processVoiceInput(command);
  }

  Future<void> _processVoiceInput(String input) async {
    try {
      _setState(VoiceState.processing);
      _addConversationMessage('user', input);

      if (isInConversation) {
        await _handleConversationResponse(input);
      } else {
        await _processInitialCommand(input);
      }
    } catch (e) {
      _setError('Erro ao processar comando: ${e.toString()}');
      Logger.error('VoiceProvider: Erro no processamento de comando', error: e);
    }
  }

  Future<void> _processInitialCommand(String command) async {
    try {
      Logger.info('VoiceProvider: Processando comando inicial - "$command"');

      final result = _nlpProcessor.processCommand(command);

      if (result.containsKey('error')) {
        _setError('Erro no processamento: ${result['error']}');
        return;
      }

      _currentTransaction = Map.from(result['entities'] as Map<String, dynamic>);
      _currentTransaction['context'] = _context;

      final missingFields = List<String>.from(result['missing_fields'] as List);
      _missingFields = missingFields;

      if (missingFields.isNotEmpty) {
        _setState(VoiceState.conversation);
        await _askForNextMissingField();
      } else {
        await _prepareConfirmation(result);
      }
    } catch (e) {
      Logger.error('VoiceProvider: Erro no processamento inicial', error: e);
      _setError('Não consegui processar este comando. Tente novamente.');
    }
  }

  Future<void> _handleConversationResponse(String response) async {
    if (_missingFields.isEmpty) {
      Logger.warning('VoiceProvider: Resposta de conversa sem campos faltantes');
      return;
    }

    final currentField = _missingFields.first;
    Logger.debug('VoiceProvider: Processando resposta para campo "$currentField"');

    final fieldValue = _nlpProcessor.processFieldResponse(currentField, response);

    if (fieldValue != null) {
      _currentTransaction[currentField] = fieldValue;
      _missingFields.removeAt(0);

      String confirmation = _generateFieldConfirmation(currentField, fieldValue);
      _addConversationMessage('assistant', confirmation);

      if (_missingFields.isNotEmpty) {
        await _askForNextMissingField();
      } else {
        _setState(VoiceState.processing);
        await _prepareConfirmation();
      }
    } else {
      String clarification = _generateClarificationQuestion(currentField);
      _addConversationMessage('assistant', clarification);
    }
  }

  Future<void> _askForNextMissingField() async {
    if (_missingFields.isEmpty) return;

    final field = _missingFields.first;
    final question = _nlpProcessor.generateQuestionForField(field, _currentTransaction);

    _addConversationMessage('assistant', question);
    Logger.debug('VoiceProvider: Perguntando sobre campo "$field"');
  }

  String _generateFieldConfirmation(String field, dynamic value) {
    switch (field) {
      case 'type':
        return value == 'income' ? 'Entendi, é uma receita.' : 'Entendi, é uma despesa.';
      case 'amount':
        return 'Valor registrado: R\$ ${(value as double).toStringAsFixed(2).replaceAll('.', ',')}';
      case 'description':
        return 'Descrição: $value';
      case 'recurring_day':
        return 'Agendado para repetir todo dia $value do mês.';
      default:
        return 'Campo $field registrado: $value';
    }
  }

  String _generateClarificationQuestion(String field) {
    switch (field) {
      case 'type':
        return 'Não entendi. É uma entrada de dinheiro (receita) ou saída de dinheiro (despesa)?';
      case 'amount':
        return 'Não consegui identificar o valor. Pode repetir quanto em reais?';
      case 'description':
        return 'Preciso de mais detalhes. Para que foi essa transação?';
      case 'recurring_day':
        return 'Não entendi o dia. Em que dia do mês deve repetir? Por exemplo: "dia 5" ou "dia 15".';
      default:
        return 'Não entendi. Pode repetir a informação sobre $field?';
    }
  }

  Future<void> _prepareConfirmation([Map<String, dynamic>? nlpResult]) async {
    try {
      final transactionObject = _nlpProcessor.buildTransactionObject(_currentTransaction);

      AccountingCategory? category;
      if (transactionObject.containsKey('category_id')) {
        final categoryId = transactionObject['category_id'] as String;
        try {
          category = _categories.firstWhere(
            (cat) => cat.id == categoryId,
          );
        } catch (e) {
          Logger.warning('VoiceProvider: Categoria $categoryId não encontrada');
        }
      }

      _pendingConfirmation = {
        'transaction_data': transactionObject,
        'category': category,
        'original_command': _conversation.isNotEmpty ? _conversation.first.message : '',
        'confidence': nlpResult?['confidence'] ?? 0.85,
      };

      _setState(VoiceState.confirmation);

      Logger.info('VoiceProvider: Confirmação preparada');
    } catch (e) {
      Logger.error('VoiceProvider: Erro ao preparar confirmação', error: e);
      _setError('Erro ao preparar confirmação da transação');
    }
  }

  Future<void> confirmTransaction() async {
    if (_pendingConfirmation == null) {
      _setError('Nenhuma transação para confirmar');
      return;
    }

    try {
      _setState(VoiceState.processing);

      final transactionData = _pendingConfirmation!['transaction_data'] as Map<String, dynamic>;

      Logger.info('VoiceProvider: Transação confirmada - ${transactionData.toString()}');

      _setSuccess('Transação criada com sucesso via comando de voz!');
      _resetConversation();

      await _createTransactionFromVoice(transactionData);
    } catch (e) {
      Logger.error('VoiceProvider: Erro ao confirmar transação', error: e);
      _setError('Erro ao criar transação: ${e.toString()}');
    }
  }

  void cancelTransaction() {
    Logger.info('VoiceProvider: Transação cancelada pelo usuário');
    _setSuccess('Comando cancelado');
    _resetConversation();
  }

  void _addConversationMessage(String sender, String message) {
    _conversation.add(ConversationMessage(
      sender: sender,
      message: message,
      timestamp: DateTime.now(),
    ));

    Logger.debug('VoiceProvider: Mensagem adicionada - $sender: "$message"');
    notifyListeners();
  }

  void _resetConversation() {
    _conversation.clear();
    _currentTransaction.clear();
    _missingFields.clear();
    _pendingConfirmation = null;
    _currentTranscript = '';
    _setState(VoiceState.idle);

    Logger.info('VoiceProvider: Conversa resetada');
  }

  void reset() {
    _resetConversation();
    _clearMessages();
  }

  @override
  void dispose() {
    if (_speechToText != null && _speechAvailable) {
      try {
        _speechToText.stop();
        _speechToText.cancel(); // Importante para a Web API
      } catch (e) {
        // Ignore dispose errors
      }
    }
    super.dispose();
    Logger.info('VoiceProvider: Disposed');
  }

  String formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String getTransactionTypeLabel(String type) {
    return type == 'income' ? 'Receita' : 'Despesa';
  }

  String getContextLabel(String context) {
    return context == 'business' ? 'Empresarial' : 'Pessoal';
  }

  Color getTransactionTypeColor(String type) {
    return type == 'income' ? Colors.green : Colors.red;
  }

  IconData getTransactionTypeIcon(String type) {
    return type == 'income' ? Icons.arrow_upward : Icons.arrow_downward;
  }

  void simulateVoiceCommand(String command) {
    Logger.info('VoiceProvider: Simulando comando de voz: "$command"');
    processTextCommand(command);
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'speech_available': _speechAvailable,
      'current_state': _currentState.toString(),
      'conversation_length': _conversation.length,
      'missing_fields': _missingFields,
      'categories_count': _categories.length,
      'has_pending_confirmation': _pendingConfirmation != null,
      'current_transaction_fields': _currentTransaction.keys.toList(),
    };
  }

  Future<void> enableSpeechToText() async {
    if (_speechAvailable) {
      Logger.info('VoiceProvider: Speech já está ativo');
      return;
    }

    try {
      await _initializeSpeechToText();
      notifyListeners();
    } catch (e) {
      Logger.error('VoiceProvider: Erro ao ativar speech', error: e);
      _setError('Não foi possível ativar reconhecimento de voz: $e');
    }
  }
}
