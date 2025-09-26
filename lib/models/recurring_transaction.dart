// recurring_transaction.dart

import 'package:flutter/material.dart';

// CORREÇÃO: Enum mais robusto com valores e nomes de display
enum RecurringFrequency {
  daily('daily', 'Diário'),
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensal'),
  yearly('yearly', 'Anual');

  const RecurringFrequency(this.value, this.displayName);

  final String value;
  final String displayName;

  static RecurringFrequency fromString(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
        return RecurringFrequency.daily;
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'monthly':
        return RecurringFrequency.monthly;
      case 'yearly':
        return RecurringFrequency.yearly;
      default:
        throw ArgumentError('Invalid RecurringFrequency: $value');
    }
  }

  @override
  String toString() => value;
}

class RecurringTransaction {
  final String id;
  final String description;
  final double amount;
  final String type; // 'income' or 'expense'
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String categoryId;
  final String? notes;

  RecurringTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.categoryId,
    this.notes,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      // CORREÇÃO: Usar método fromString mais robusto
      frequency: RecurringFrequency.fromString(json['frequency'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      categoryId: json['category_id'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      // CORREÇÃO: Usar value em vez de toString().split()
      'frequency': frequency.value,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'category_id': categoryId,
      'notes': notes,
    };
  }

  RecurringTransaction copyWith({
    String? id,
    String? description,
    double? amount,
    String? type,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? notes,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
    );
  }
}
