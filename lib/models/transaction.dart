// lib/models/transaction.dart
// Modelo completo sincronizado com a API do backend
// Inclui todos os campos: status, category_name, order_id, is_recurring, recurring_day

import 'package:flutter/material.dart';
import 'package:vitrine_borracharia/models/accounting_category.dart';

enum TransactionType {
  income,
  expense,
}

enum TransactionStatus {
  pending,
  paid,
  cancelled,
}

class Transaction {
  final String id;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final DateTime? dueDate;
  final String categoryId;
  final String? notes;
  
  // NOVOS CAMPOS SINCRONIZADOS COM BACKEND
  final String status; // "pending", "paid", "cancelled"
  final String? categoryName; // Nome da categoria retornado pela API
  final String? orderId; // ID do pedido para vincular com e-commerce
  final bool isRecurring; // Se é uma transação recorrente
  final int? recurringDay; // Dia do mês para repetir (1-31)
  final String context; // "business" ou "personal"
  final String? source; // "manual", "voice", "document", "order"
  
  // Objetos relacionados
  final AccountingCategory? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    required this.categoryId,
    this.dueDate,
    this.notes,
    this.status = 'pending',
    this.categoryName,
    this.orderId,
    this.isRecurring = false,
    this.recurringDay,
    this.context = 'business',
    this.source,
    this.category,
    this.createdAt,
    this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['_id'] ?? json['id'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: _parseTransactionType(json['type'] as String?),
      date: _parseDateTime(json['date']) ?? DateTime.now(),
      dueDate: _parseDateTime(json['due_date']),
      categoryId: json['category_id'] ?? '',
      notes: json['notes'] as String?,
      
      // CAMPOS NOVOS DO BACKEND
      status: json['status'] ?? 'pending',
      categoryName: json['category_name'] as String?,
      orderId: json['order_id'] as String?,
      isRecurring: json['is_recurring'] ?? false,
      recurringDay: json['recurring_day'] as int?,
      context: json['context'] ?? 'business',
      source: json['source'] as String?,
      
      // Objetos relacionados
      category: json['category'] != null 
          ? AccountingCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'description': description,
      'amount': amount,
      'type': type.toString().split('.').last,
      'date': date.toIso8601String(),
      'category_id': categoryId,
      'status': status,
      'context': context,
      'is_recurring': isRecurring,
    };

    // Campos opcionais
    if (id.isNotEmpty) data['id'] = id;
    if (dueDate != null) data['due_date'] = dueDate!.toIso8601String();
    if (notes != null) data['notes'] = notes;
    if (orderId != null) data['order_id'] = orderId;
    if (recurringDay != null) data['recurring_day'] = recurringDay;
    if (source != null) data['source'] = source;
    if (createdAt != null) data['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) data['updated_at'] = updatedAt!.toIso8601String();

    return data;
  }

  Transaction copyWith({
    String? id,
    String? description,
    double? amount,
    TransactionType? type,
    DateTime? date,
    DateTime? dueDate,
    String? categoryId,
    String? notes,
    String? status,
    String? categoryName,
    String? orderId,
    bool? isRecurring,
    int? recurringDay,
    String? context,
    String? source,
    AccountingCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      categoryName: categoryName ?? this.categoryName,
      orderId: orderId ?? this.orderId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDay: recurringDay ?? this.recurringDay,
      context: context ?? this.context,
      source: source ?? this.source,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // GETTERS CONVENIENTES PARA A UI

  TransactionStatus get statusEnum {
    switch (status.toLowerCase()) {
      case 'paid':
        return TransactionStatus.paid;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }

  String get statusLabel {
    switch (statusEnum) {
      case TransactionStatus.paid:
        return 'Pago';
      case TransactionStatus.cancelled:
        return 'Cancelado';
      case TransactionStatus.pending:
        return 'Pendente';
    }
  }

  Color get statusColor {
    switch (statusEnum) {
      case TransactionStatus.paid:
        return Colors.green;
      case TransactionStatus.cancelled:
        return Colors.orange;
      case TransactionStatus.pending:
        return Colors.yellow;
    }
  }

  String get typeLabel {
    return type == TransactionType.income ? 'Receita' : 'Despesa';
  }

  Color get typeColor {
    return type == TransactionType.income ? Colors.green : Colors.red;
  }

  IconData get typeIcon {
    return type == TransactionType.income ? Icons.arrow_upward : Icons.arrow_downward;
  }

  String get contextLabel {
    return context == 'business' ? 'Empresarial' : 'Pessoal';
  }

  String get sourceLabel {
    switch (source) {
      case 'manual':
        return 'Manual';
      case 'voice':
        return 'Comando de Voz';
      case 'document':
        return 'Documento';
      case 'order':
        return 'Pedido E-commerce';
      default:
        return 'Manual';
    }
  }

  IconData get sourceIcon {
    switch (source) {
      case 'voice':
        return Icons.mic;
      case 'document':
        return Icons.description;
      case 'order':
        return Icons.shopping_cart;
      default:
        return Icons.edit;
    }
  }

  String get displayCategoryName {
    return categoryName ?? category?.name ?? 'Sem Categoria';
  }

  // Verifica se a transação está vinculada ao e-commerce
  bool get isLinkedToEcommerce {
    return orderId != null && orderId!.isNotEmpty;
  }

  // Verifica se a transação é do dia atual
  bool get isToday {
    final today = DateTime.now();
    return date.year == today.year && 
           date.month == today.month && 
           date.day == today.day;
  }

  // Verifica se a transação está vencida (para pendentes)
  bool get isOverdue {
    if (statusEnum != TransactionStatus.pending) return false;
    final targetDate = dueDate ?? date;
    return targetDate.isBefore(DateTime.now());
  }

  // Formatar valor para exibição
  String get formattedAmount {
    final prefix = type == TransactionType.income ? '+' : '-';
    return '$prefix R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Formatar data para exibição
  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }

  // Formatar data com hora
  String get formattedDateTime {
    return '$formattedDate ${date.hour.toString().padLeft(2, '0')}:'
           '${date.minute.toString().padLeft(2, '0')}';
  }

  // Informações sobre recorrência
  String get recurrenceInfo {
    if (!isRecurring || recurringDay == null) return 'Não recorrente';
    return 'Todo dia ${recurringDay!} do mês';
  }

  // MÉTODOS ESTÁTICOS PARA CRIAÇÃO

  static Transaction createManual({
    required String description,
    required double amount,
    required TransactionType type,
    required String categoryId,
    DateTime? date,
    String? notes,
    String context = 'business',
  }) {
    return Transaction(
      id: '', // Será preenchido pelo backend
      description: description,
      amount: amount,
      type: type,
      date: date ?? DateTime.now(),
      categoryId: categoryId,
      notes: notes,
      context: context,
      source: 'manual',
      status: 'pending',
    );
  }

  static Transaction createFromVoice({
    required String description,
    required double amount,
    required TransactionType type,
    required String categoryId,
    DateTime? date,
    bool isRecurring = false,
    int? recurringDay,
    String context = 'business',
  }) {
    return Transaction(
      id: '', // Será preenchido pelo backend
      description: description,
      amount: amount,
      type: type,
      date: date ?? DateTime.now(),
      categoryId: categoryId,
      context: context,
      source: 'voice',
      status: 'pending',
      isRecurring: isRecurring,
      recurringDay: recurringDay,
      notes: 'Criado via comando de voz',
    );
  }

  static Transaction createFromOrder({
    required String orderId,
    required String description,
    required double amount,
    required String categoryId,
    DateTime? date,
    String context = 'business',
  }) {
    return Transaction(
      id: '', // Será preenchido pelo backend
      description: description,
      amount: amount,
      type: TransactionType.income, // Vendas são sempre receitas
      date: date ?? DateTime.now(),
      categoryId: categoryId,
      context: context,
      source: 'order',
      status: 'paid', // Vendas confirmadas já são pagas
      orderId: orderId,
      notes: 'Gerado automaticamente da venda #$orderId',
    );
  }

  // MÉTODOS DE VALIDAÇÃO

  bool get isValid {
    return description.trim().isNotEmpty &&
           amount > 0 &&
           categoryId.isNotEmpty &&
           (isRecurring ? recurringDay != null && recurringDay! >= 1 && recurringDay! <= 31 : true);
  }

  List<String> get validationErrors {
    final errors = <String>[];
    
    if (description.trim().isEmpty) {
      errors.add('Descrição é obrigatória');
    }
    
    if (amount <= 0) {
      errors.add('Valor deve ser maior que zero');
    }
    
    if (categoryId.isEmpty) {
      errors.add('Categoria é obrigatória');
    }
    
    if (isRecurring && (recurringDay == null || recurringDay! < 1 || recurringDay! > 31)) {
      errors.add('Dia de recorrência deve estar entre 1 e 31');
    }
    
    return errors;
  }

  // MÉTODOS PRIVADOS

  static TransactionType _parseTransactionType(String? typeString) {
    switch (typeString?.toLowerCase()) {
      case 'income':
        return TransactionType.income;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }

  static DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return null;
      }
    }
    
    if (dateValue is DateTime) {
      return dateValue;
    }
    
    return null;
  }

  // COMPARAÇÃO E HASH

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
           other.id == id &&
           other.description == description &&
           other.amount == amount &&
           other.type == type &&
           other.date == date;
  }

  @override
  int get hashCode => Object.hash(id, description, amount, type, date);

  @override
  String toString() {
    return 'Transaction(id: $id, description: $description, amount: $amount, '
           'type: $type, status: $status, category: ${displayCategoryName})';
  }

  // MÉTODOS PARA RELATÓRIOS E ANÁLISES

  bool isInDateRange(DateTime startDate, DateTime endDate) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(endDate.add(const Duration(days: 1)));
  }

  bool matchesSearchQuery(String query) {
    final lowerQuery = query.toLowerCase();
    return description.toLowerCase().contains(lowerQuery) ||
           (notes?.toLowerCase().contains(lowerQuery) ?? false) ||
           displayCategoryName.toLowerCase().contains(lowerQuery) ||
           formattedAmount.contains(lowerQuery);
  }

  Map<String, dynamic> toAnalyticsData() {
    return {
      'amount': amount,
      'type': type.toString().split('.').last,
      'category': displayCategoryName,
      'month': date.month,
      'year': date.year,
      'status': status,
      'source': source ?? 'manual',
      'is_recurring': isRecurring,
      'context': context,
    };
  }
}