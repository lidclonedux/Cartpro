// lib/services/voice_nlp_processor.dart
// Port completo da lógica VoiceNLPProcessor de JavaScript para Dart
// VERSÃO ATUALIZADA PARA SINCRONIZAR COM O BACKEND PYTHON

import 'dart:math';
import 'package:vitrine_borracharia/models/accounting_category.dart';
import 'package:vitrine_borracharia/utils/logger.dart';

class VoiceNlpProcessor {
  // Padrões de intenção - identificar se é criar ou agendar
  final Map<String, List<RegExp>> _intentPatterns = {
    'schedule_transaction': [
      RegExp(r'\b(agendar?|programar?|mensal|recorrente|todo\s+dia)\b', caseSensitive: false),
      RegExp(r'\b(repetir?|automatico|fixo|permanente)\b', caseSensitive: false),
    ],
    'create_transaction': [
      RegExp(r'\b(criar?|adicionar?|lancamento|transacao)\b', caseSensitive: false),
      RegExp(r'\b(registrar?|anotar?|marcar?)\b', caseSensitive: false),
    ],
  };

  // Padrões de tipo - receita ou despesa
  final Map<String, List<RegExp>> _typePatterns = {
    'expense': [
      RegExp(r'\b(pagamento|pagar?|gasto|despesa|saida|debito)\b', caseSensitive: false),
      RegExp(r'\b(compra|comprei|gastei|paguei|conta)\b', caseSensitive: false),
      RegExp(r'\b(aluguel|financiamento|prestacao|parcela)\b', caseSensitive: false),
    ],
    'income': [
      RegExp(r'\b(receita|receber?|entrada|credito|ganho)\b', caseSensitive: false),
      RegExp(r'\b(salario|freelance|venda|vendeu|lucro)\b', caseSensitive: false),
      RegExp(r'\b(rendimento|juros|dividendo|bonificacao)\b', caseSensitive: false),
    ],
  };

  // Palavras-chave contextuais para categorização automática
  final Map<String, List<String>> _contextualKeywords = {
    'Alimentação': [
      'comida', 'almoço', 'jantar', 'lanche', 'restaurante', 'padaria',
      'mercado', 'supermercado', 'ifood', 'uber eats', 'delivery',
      'hamburguer', 'pizza', 'açougue', 'hortifruti'
    ],
    'Transporte': [
      'uber', 'taxi', '99', 'cabify', 'ônibus', 'metrô', 'trem',
      'combustível', 'gasolina', 'etanol', 'posto', 'shell',
      'ipiranga', 'petrobras', 'estacionamento', 'pedágio'
    ],
    'Saúde': [
      'médico', 'dentista', 'farmácia', 'remédio', 'hospital',
      'clínica', 'exame', 'consulta', 'medicamento', 'tratamento'
    ],
    'Casa': [
      'aluguel', 'condomínio', 'luz', 'energia', 'água', 'gás',
      'internet', 'telefone', 'tv', 'streaming', 'netflix',
      'limpeza', 'manutenção'
    ],
    'Lazer': [
      'cinema', 'teatro', 'show', 'festa', 'bar', 'balada',
      'viagem', 'hotel', 'turismo', 'passeio', 'diversão'
    ],
    'Educação': [
      'escola', 'faculdade', 'curso', 'livro', 'material',
      'mensalidade', 'matrícula', 'apostila'
    ],
    'Trabalho': [
      'salário', 'freelance', 'projeto', 'serviço', 'consultoria',
      'comissão', 'bonus', 'hora extra'
    ],
    'PIX': [
      'pix', 'transferência', 'ted', 'doc'
    ],
  };

  // Números por extenso para conversão
  final Map<String, int> _numberWords = {
    'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'três': 3, 'tres': 3,
    'quatro': 4, 'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9,
    'dez': 10, 'onze': 11, 'doze': 12, 'treze': 13, 'quatorze': 14,
    'quinze': 15, 'dezesseis': 16, 'dezessete': 17, 'dezoito': 18,
    'dezenove': 19, 'vinte': 20, 'trinta': 30, 'quarenta': 40,
    'cinquenta': 50, 'sessenta': 60, 'setenta': 70, 'oitenta': 80,
    'noventa': 90, 'cem': 100, 'cento': 100,
  };

  final Map<String, int> _multipliers = {
    'mil': 1000,
    'milhão': 1000000,
    'milhões': 1000000,
    'bilhão': 1000000000,
    'bilhões': 1000000000,
  };

  List<AccountingCategory> _categories = [];

  VoiceNlpProcessor() {
    Logger.info('VoiceNlpProcessor: Inicializado com sucesso');
  }

  void updateCategories(List<AccountingCategory> categories) {
    _categories = categories;
    Logger.info('VoiceNlpProcessor: ${categories.length} categorias carregadas');
  }

  /// Método principal - processar comando de voz completo
  Map<String, dynamic> processCommand(String command) {
    try {
      Logger.info('VoiceNlpProcessor: Processando comando: "$command"');

      final normalizedCommand = _normalizeCommand(command);

      final intent = _extractIntent(normalizedCommand);
      final type = _extractTransactionType(normalizedCommand);
      final amount = _extractAmount(normalizedCommand);
      final description = _extractDescription(normalizedCommand, type, amount);
      final dateInfo = _extractDate(normalizedCommand);
      final recurringInfo = _extractRecurring(normalizedCommand);
      final suggestedCategory = _findBestCategory(description, type);

      final entities = <String, dynamic>{
        'type': type,
        'description': description,
        'context': 'business', // Padrão para o contexto
      };

      if (amount != null) entities['amount'] = amount;
      if (dateInfo != null) entities.addAll(dateInfo);
      if (recurringInfo != null) entities.addAll(recurringInfo);
      if (suggestedCategory != null) entities['category_id'] = suggestedCategory.id;

      // Identificar campos faltantes
      final missingFields = _identifyMissingFields(entities, intent);

      // Calcular confiança
      final confidence = _calculateConfidence(entities, missingFields);

      final result = {
        'intent': intent,
        'entities': entities,
        'missing_fields': missingFields,
        'confidence': confidence,
        'original_command': command,
        'normalized_command': normalizedCommand,
      };

      Logger.info('VoiceNlpProcessor: Processamento concluído - Confiança: ${(confidence * 100).toStringAsFixed(1)}%');
      return result;

    } catch (e) {
      Logger.error('VoiceNlpProcessor: Erro ao processar comando', error: e);
      return {
        'intent': 'unknown',
        'entities': <String, dynamic>{},
        'missing_fields': ['type', 'amount', 'description'],
        'confidence': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Normalizar comando - minúscula, sem pontuação extra
  String _normalizeCommand(String command) {
    return command
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extrair intenção do comando
  String _extractIntent(String command) {
    for (final entry in _intentPatterns.entries) {
      final intent = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        if (pattern.hasMatch(command)) {
          Logger.debug('VoiceNlpProcessor: Intenção detectada - $intent');
          return intent;
        }
      }
    }

    return 'create_transaction'; // Padrão
  }

  /// Extrair tipo de transação (receita ou despesa)
  String _extractTransactionType(String command) {
    int expenseScore = 0;
    int incomeScore = 0;

    // Pontuar baseado nos padrões
    for (final pattern in _typePatterns['expense']!) {
      if (pattern.hasMatch(command)) expenseScore += 2;
    }

    for (final pattern in _typePatterns['income']!) {
      if (pattern.hasMatch(command)) incomeScore += 2;
    }

    // Palavras-chave contextuais também influenciam
    for (final keywords in _contextualKeywords.values) {
      for (final keyword in keywords) {
        if (command.contains(keyword)) {
          // A maioria das categorias são despesas por padrão
          expenseScore += 1;
        }
      }
    }

    final result = incomeScore > expenseScore ? 'income' : 'expense';
    Logger.debug('VoiceNlpProcessor: Tipo detectado - $result (Income: $incomeScore, Expense: $expenseScore)');
    return result;
  }

  /// Extrair valor monetário do comando
  double? _extractAmount(String command) {
    // Padrão 1: Números com dígitos (R$ 150,00, 1500, 1.500,50)
    final digitPattern = RegExp(r'(?:r\$?\s*)?(\d+(?:[.,]\d{3})*(?:[.,]\d{1,2})?)', caseSensitive: false);
    final digitMatch = digitPattern.firstMatch(command);

    if (digitMatch != null) {
      String amountStr = digitMatch.group(1)!;

      // Normalizar formato brasileiro (1.500,50 -> 1500.50)
      if (amountStr.contains('.') && amountStr.contains(',')) {
        amountStr = amountStr.replaceAll('.', '').replaceAll(',', '.');
      } else if (amountStr.contains(',')) {
        // Se só tem vírgula, assumir que é decimal
        if (amountStr.split(',')[1].length <= 2) {
          amountStr = amountStr.replaceAll(',', '.');
        }
      }

      final amount = double.tryParse(amountStr);
      if (amount != null) {
        Logger.debug('VoiceNlpProcessor: Valor detectado (dígitos) - R\$ ${amount.toStringAsFixed(2)}');
        return amount;
      }
    }

    // Padrão 2: Números por extenso
    final extensoAmount = _extractAmountFromWords(command);
    if (extensoAmount != null) {
      Logger.debug('VoiceNlpProcessor: Valor detectado (extenso) - R\$ ${extensoAmount.toStringAsFixed(2)}');
      return extensoAmount;
    }

    return null;
  }

  /// Extrair valor de números por extenso
  double? _extractAmountFromWords(String command) {
    final words = command.split(' ');
    double totalAmount = 0;
    double currentNumber = 0;
    bool foundNumber = false;

    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase();

      // Verificar números básicos
      if (_numberWords.containsKey(word)) {
        currentNumber += _numberWords[word]!;
        foundNumber = true;
        continue;
      }

      // Verificar multiplicadores
      if (_multipliers.containsKey(word)) {
        if (currentNumber == 0) currentNumber = 1; // "mil reais" = 1000
        currentNumber *= _multipliers[word]!;
        totalAmount += currentNumber;
        currentNumber = 0;
        foundNumber = true;
        continue;
      }

      // Verificar conectores
      if (word == 'e') {
        continue;
      }

      // Se chegou a uma palavra não numérica e temos um número acumulado
      if (foundNumber && currentNumber > 0) {
        totalAmount += currentNumber;
        break;
      }
    }

    // Adicionar número final se houver
    if (currentNumber > 0) {
      totalAmount += currentNumber;
    }

    return totalAmount > 0 ? totalAmount : null;
  }

  /// Extrair descrição limpa do comando
  String _extractDescription(String command, String type, double? amount) {
    String description = command;

    // Remover indicadores de tipo
    for (final patterns in _typePatterns.values) {
      for (final pattern in patterns) {
        description = description.replaceAll(pattern, ' ');
      }
    }

    // Remover indicadores de intenção
    for (final patterns in _intentPatterns.values) {
      for (final pattern in patterns) {
        description = description.replaceAll(pattern, ' ');
      }
    }

    // Remover valores monetários
    description = description.replaceAll(RegExp(r'(?:r\$?\s*)?\d+(?:[.,]\d{3})*(?:[.,]\d{1,2})?'), ' ');
    description = description.replaceAll(RegExp(r'\b(?:reais?|real)\b'), ' ');

    // Remover números por extenso
    for (final word in _numberWords.keys) {
      description = description.replaceAll(RegExp('\\b$word\\b'), ' ');
    }
    for (final word in _multipliers.keys) {
      description = description.replaceAll(RegExp('\\b$word\\b'), ' ');
    }

    // Remover palavras temporais
    description = description.replaceAll(RegExp(r'\b(?:hoje|ontem|amanha|todo|dia)\b'), ' ');

    // Limpar espaços extras e capitalizar
    description = description.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (description.isEmpty) {
      return type == 'income' ? 'Receita por voz' : 'Despesa por voz';
    }

    // Capitalizar primeira letra
    if (description.isNotEmpty) {
      description = description[0].toUpperCase() + description.substring(1);
    }

    Logger.debug('VoiceNlpProcessor: Descrição extraída - "$description"');
    return description;
  }

  /// Extrair informações de data
  Map<String, dynamic>? _extractDate(String command) {
    final today = DateTime.now();

    if (command.contains('hoje')) {
      return {'date': today};
    } else if (command.contains('ontem')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return {'date': yesterday};
    } else if (command.contains('amanhã') || command.contains('amanha')) {
      final tomorrow = today.add(const Duration(days: 1));
      return {'date': tomorrow};
    }

    // Se não especificado, usar hoje
    return {'date': today};
  }

  /// Extrair informações de recorrência
  Map<String, dynamic>? _extractRecurring(String command) {
    // Padrão: "todo dia X"
    final dayPattern = RegExp(r'todo\s+dia\s+(\d+)', caseSensitive: false);
    final dayMatch = dayPattern.firstMatch(command);

    if (dayMatch != null) {
      final day = int.tryParse(dayMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        return {
          'is_recurring': true,
          'recurring_day': day,
        };
      }
    }

    // Outros padrões de recorrência
    if (command.contains('mensal') || command.contains('todo mês') || command.contains('todo mes')) {
      return {
        'is_recurring': true,
        'recurring_day': DateTime.now().day,
      };
    }

    return null;
  }

  /// Encontrar melhor categoria baseada na descrição
  AccountingCategory? _findBestCategory(String description, String type) {
    if (_categories.isEmpty || description.isEmpty) return null;

    final descriptionLower = description.toLowerCase();
    AccountingCategory? bestMatch;
    int bestScore = 0;

    // Filtrar categorias do tipo correto
    final typeCategories = _categories.where((cat) => cat.type == type).toList();

    for (final category in typeCategories) {
      int score = 0;
      final categoryName = category.name.toLowerCase();

      // Verificar correspondência direta no nome da categoria
      if (descriptionLower.contains(categoryName) || categoryName.contains(descriptionLower)) {
        score += 10;
      }

      // Verificar palavras-chave contextuais
      for (final entry in _contextualKeywords.entries) {
        final contextCategory = entry.key;
        final keywords = entry.value;

        if (categoryName.contains(contextCategory.toLowerCase())) {
          for (final keyword in keywords) {
            if (descriptionLower.contains(keyword.toLowerCase())) {
              score += 5;
            }
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = category;
      }
    }

    if (bestMatch != null) {
      Logger.debug('VoiceNlpProcessor: Categoria sugerida - ${bestMatch.name} (Score: $bestScore)');
    }

    return bestMatch;
  }

  /// Identificar campos obrigatórios faltantes
  List<String> _identifyMissingFields(Map<String, dynamic> entities, String intent) {
    final missing = <String>[];

    final requiredFields = intent == 'schedule_transaction'
        ? ['type', 'amount', 'description', 'recurring_day']
        : ['type', 'amount', 'description'];

    for (final field in requiredFields) {
      if (!entities.containsKey(field) || entities[field] == null) {
        missing.add(field);
      }
    }

    return missing;
  }

  /// Calcular confiança do processamento
  double _calculateConfidence(Map<String, dynamic> entities, List<String> missingFields) {
    double confidence = 0.0;

    // Pontuação base por campo preenchido
    if (entities.containsKey('type')) confidence += 0.25;
    if (entities.containsKey('amount')) confidence += 0.35;
    if (entities.containsKey('description')) confidence += 0.25;
    if (entities.containsKey('category_id')) confidence += 0.15;

    // Penalizar campos faltantes
    confidence -= (missingFields.length * 0.15);

    // Garantir que está entre 0 e 1
    return confidence.clamp(0.0, 1.0);
  }

  /// Gerar pergunta para campo faltante (para uso na conversa)
  String generateQuestionForField(String field, Map<String, dynamic> currentEntities) {
    switch (field) {
      case 'type':
        return 'Esta é uma receita (entrada de dinheiro) ou uma despesa (saída de dinheiro)?';
      case 'amount':
        return 'Qual é o valor da transação em reais?';
      case 'description':
        return 'Pode me dar mais detalhes sobre esta transação?';
      case 'recurring_day':
        return 'Em qual dia do mês deve repetir? (exemplo: dia 5, dia 15)';
      case 'category_id':
        return 'Qual categoria melhor descreve esta transação?';
      default:
        return 'Preciso de mais informações sobre: $field';
    }
  }

  /// Processar resposta para campo específico (para uso na conversa)
  dynamic processFieldResponse(String field, String response) {
    switch (field) {
      case 'type':
        return _extractTransactionType(response);
      case 'amount':
        return _extractAmount(response);
      case 'description':
        final cleaned = response.trim();
        return cleaned.isNotEmpty ? cleaned : null;
      case 'recurring_day':
        final dayMatch = RegExp(r'\b(\d+)\b').firstMatch(response);
        if (dayMatch != null) {
          final day = int.tryParse(dayMatch.group(1)!);
          if (day != null && day >= 1 && day <= 31) {
            return day;
          }
        }
        return null;
      default:
        return response.trim();
    }
  }

  /// <<< CORREÇÃO PRINCIPAL: `buildTransactionObject` agora monta o objeto completo >>>
  /// Construir objeto final de transação, alinhado com o backend
  Map<String, dynamic> buildTransactionObject(Map<String, dynamic> entities) {
    final DateTime transactionDate = entities['date'] ?? DateTime.now();
    final DateTime today = DateTime.now();
    // Normaliza as datas para ignorar a hora na comparação
    final DateUtils = DateTime(today.year, today.month, today.day);
    final transactionDateOnly = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);

    // Lógica de status replicada do backend Python
    String status = 'pending';
    if (transactionDateOnly.isBefore(DateUtils) || transactionDateOnly.isAtSameMomentAs(DateUtils)) {
      status = 'paid';
    }

    final transaction = <String, dynamic>{
      'description': entities['description'] ?? 'Transação por voz',
      'amount': entities['amount'] ?? 0.0,
      'type': entities['type'] ?? 'expense',
      'context': entities['context'] ?? 'business',
      'date': transactionDate.toIso8601String(), // Envia em formato ISO 8601
      'status': status, // Adiciona o status calculado
      'source': 'voice', // Define a origem da transação
    };

    if (entities.containsKey('category_id')) {
      transaction['category_id'] = entities['category_id'];
    }

    if (entities['is_recurring'] == true) {
      transaction['is_recurring'] = true;
      transaction['recurring_day'] = entities['recurring_day'];
    } else {
      transaction['is_recurring'] = false;
    }

    // Adiciona campos que o backend pode esperar, mesmo que nulos
    transaction.putIfAbsent('notes', () => 'Criado via comando de voz.');
    transaction.putIfAbsent('due_date', () => null);
    transaction.putIfAbsent('order_id', () => null);

    Logger.info('VoiceNlpProcessor: Objeto de transação final montado: $transaction');
    return transaction;
  }
}
