// ignore_for_file: unused_field, unnecessary_this

import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

// Simula a classe SpeechRecognitionResult do pacote original para compatibilidade
class SpeechRecognitionResult {
  final String recognizedWords;
  final bool finalResult;

  SpeechRecognitionResult(this.recognizedWords, this.finalResult);
}

// Simula a classe RecognitionError do pacote original para compatibilidade
class RecognitionError {
  final String errorMsg;
  final bool permanent;

  RecognitionError(this.errorMsg, this.permanent);
}

// Esta é a nossa implementação da Web Speech API que "imita" o pacote speech_to_text
class SpeechToText {
  html.SpeechRecognition? _webSpeech;
  bool _isListening = false;
  String _lastWords = '';

  // Callbacks que serão fornecidos pelo VoiceProvider
  void Function(String)? onStatus;
  void Function(RecognitionError)? onError;
  void Function(SpeechRecognitionResult)? onResult;

  Future<bool> initialize({
    required Function(String) onStatus,
    required Function(RecognitionError) onError,
    debugLogging = false,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;

    if (!html.SpeechRecognition.supported) {
      Logger.error('[WebSpeechAPI] Speech Recognition não é suportado neste navegador.');
      return false;
    }

    _webSpeech = html.SpeechRecognition();
    _webSpeech!.continuous = true;
    _webSpeech!.interimResults = true;
    _webSpeech!.lang = 'pt-BR';

    _webSpeech!.onStart.listen((_) {
      _isListening = true;
      this.onStatus?.call('listening');
      Logger.info('[WebSpeechAPI] Evento onStart disparado. Escuta iniciada.');
    });

    _webSpeech!.onEnd.listen((_) {
      _isListening = false;
      this.onStatus?.call('notListening');
      Logger.info('[WebSpeechAPI] Evento onEnd disparado. Escuta finalizada.');
    });

    _webSpeech!.onError.listen((html.SpeechRecognitionError event) {
      String errorType = event.error ?? 'unknown';
      Logger.error('[WebSpeechAPI] Evento onError disparado: $errorType');
      this.onError?.call(RecognitionError(errorType, true));
    });

    _webSpeech!.onResult.listen((html.SpeechRecognitionEvent event) {
      if (event.results == null) return;

      String transcript = '';
      bool isFinal = false;

      for (final result in event.results!) {
        if (result.length != null && result.length! > 0) {
          final alternative = result.item(0);
          if (alternative != null) {
            transcript += alternative.transcript ?? '';
          }
        }
        if (result.isFinal ?? false) {
          isFinal = true;
        }
      }
      
      _lastWords = transcript;
      this.onResult?.call(SpeechRecognitionResult(_lastWords, isFinal));
    });

    Logger.info('[WebSpeechAPI] Inicializado com sucesso.');
    return true;
  }

  Future<void> listen({
    required Function(SpeechRecognitionResult) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    bool? partialResults,
    bool? cancelOnError,
    String? localeId,
  }) async {
    if (_webSpeech == null) {
      Logger.error('[WebSpeechAPI] Não inicializado. Chame initialize() primeiro.');
      throw Exception("SpeechToText não inicializado.");
    }
    if (_isListening) {
      Logger.warning('[WebSpeechAPI] Já está ouvindo. Ignorando chamada `listen`.');
      return;
    }
    
    this.onResult = onResult;
    if (localeId != null) {
      _webSpeech!.lang = localeId.replaceAll('_', '-');
    }
    
    try {
      Logger.info('[WebSpeechAPI] Chamando _webSpeech.start()...');
      _webSpeech!.start();
    } catch (e) {
      Logger.error('[WebSpeechAPI] Erro ao chamar _webSpeech.start()', error: e);
      throw Exception("Erro ao iniciar a escuta do navegador: $e");
    }
  }

  Future<void> stop() async {
    if (_isListening) {
      Logger.info('[WebSpeechAPI] Chamando _webSpeech.stop()...');
      _webSpeech?.stop();
    }
  }

  Future<void> cancel() async {
    if (_isListening) {
      Logger.info('[WebSpeechAPI] Chamando _webSpeech.abort()...');
      _webSpeech?.abort();
    }
  }
}
