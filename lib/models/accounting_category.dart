// lib/models/accounting_category.dart
// Modelo sincronizado com a API do backend, incluindo campos color e emoji

import 'package:flutter/material.dart';

class AccountingCategory {
  final String id;
  final String name;
  final String type; // 'income' or 'expense'
  final String? color; // Hex color string from backend
  final String? emoji; // Emoji string from backend
  final IconData? icon; // Flutter icon para UI local
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AccountingCategory({
    required this.id,
    required this.name,
    required this.type,
    this.color,
    this.emoji,
    this.icon,
    this.createdAt,
    this.updatedAt,
  });

  factory AccountingCategory.fromJson(Map<String, dynamic> json) {
    return AccountingCategory(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'expense',
      color: json['color'] as String?,
      emoji: json['emoji'] as String?,
      // Converter icon string do backend para IconData se necessário
      icon: _parseIconFromBackend(json['icon'] as String?),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'type': type,
      if (color != null) 'color': color,
      if (emoji != null) 'emoji': emoji,
      if (icon != null) 'icon': _iconToBackendString(icon),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  AccountingCategory copyWith({
    String? id,
    String? name,
    String? type,
    String? color,
    String? emoji,
    IconData? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountingCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Getters para facilitar o uso na UI
  Color get displayColor {
    if (color != null) {
      // Converter hex string para Color
      try {
        final hexColor = color!.replaceAll('#', '');
        return Color(int.parse('FF$hexColor', radix: 16));
      } catch (e) {
        // Se falhar, usar cor padrão baseada no tipo
        return type == 'income' ? Colors.green : Colors.red;
      }
    }
    return type == 'income' ? Colors.green : Colors.red;
  }

  String get displayEmoji {
    return emoji ?? (type == 'income' ? '💰' : '💸');
  }

  IconData get displayIcon {
    return icon ?? (type == 'income' ? Icons.arrow_upward : Icons.arrow_downward);
  }

  // Método estático para criar categoria com valores padrão
  static AccountingCategory createDefault({
    required String name,
    required String type,
    String? color,
    String? emoji,
  }) {
    return AccountingCategory(
      id: '', // Será preenchido pelo backend
      name: name,
      type: type,
      color: color ?? (type == 'income' ? '#4CAF50' : '#F44336'),
      emoji: emoji ?? (type == 'income' ? '💰' : '💸'),
      createdAt: DateTime.now(),
    );
  }

  // Método para validar se a categoria é válida
  bool get isValid {
    return name.trim().isNotEmpty && 
           (type == 'income' || type == 'expense');
  }

  // Método para comparação
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountingCategory &&
           other.id == id &&
           other.name == name &&
           other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, name, type);

  @override
  String toString() {
    return 'AccountingCategory(id: $id, name: $name, type: $type, color: $color, emoji: $emoji)';
  }

  // Métodos privados para conversão de ícones
  static IconData? _parseIconFromBackend(String? iconString) {
    if (iconString == null) return null;
    
    // Mapear strings de ícones do backend para IconData
    final iconMap = {
      'utensils': Icons.restaurant,
      'fuel': Icons.local_gas_station,
      'car': Icons.directions_car,
      'heart': Icons.favorite,
      'book': Icons.book,
      'gamepad-2': Icons.games,
      'home': Icons.home,
      'shirt': Icons.checkroom,
      'smartphone': Icons.smartphone,
      'credit-card': Icons.credit_card,
      'building': Icons.business,
      'shopping-cart': Icons.shopping_cart,
      'folder': Icons.folder,
      'arrow-up': Icons.arrow_upward,
      'arrow-down': Icons.arrow_downward,
      'plus': Icons.add,
      'minus': Icons.remove,
    };

    return iconMap[iconString];
  }

  static String? _iconToBackendString(IconData? icon) {
    if (icon == null) return null;
    
    // Mapear IconData para strings do backend (reverso)
    final reverseIconMap = {
      Icons.restaurant: 'utensils',
      Icons.local_gas_station: 'fuel',
      Icons.directions_car: 'car',
      Icons.favorite: 'heart',
      Icons.book: 'book',
      Icons.games: 'gamepad-2',
      Icons.home: 'home',
      Icons.checkroom: 'shirt',
      Icons.smartphone: 'smartphone',
      Icons.credit_card: 'credit-card',
      Icons.business: 'building',
      Icons.shopping_cart: 'shopping-cart',
      Icons.folder: 'folder',
      Icons.arrow_upward: 'arrow-up',
      Icons.arrow_downward: 'arrow-down',
      Icons.add: 'plus',
      Icons.remove: 'minus',
    };

    return reverseIconMap[icon];
  }

  // Método para obter lista de categorias padrão para seeding
  static List<AccountingCategory> getDefaultCategories() {
    return [
      // Categorias de Receita
      AccountingCategory.createDefault(
        name: 'Vendas',
        type: 'income',
        color: '#4CAF50',
        emoji: '💰',
      ),
      AccountingCategory.createDefault(
        name: 'Serviços',
        type: 'income',
        color: '#2196F3',
        emoji: '🔧',
      ),
      AccountingCategory.createDefault(
        name: 'Freelance',
        type: 'income',
        color: '#9C27B0',
        emoji: '💻',
      ),
      
      // Categorias de Despesa
      AccountingCategory.createDefault(
        name: 'Alimentação',
        type: 'expense',
        color: '#FF9800',
        emoji: '🍽️',
      ),
      AccountingCategory.createDefault(
        name: 'Transporte',
        type: 'expense',
        color: '#795548',
        emoji: '🚗',
      ),
      AccountingCategory.createDefault(
        name: 'Saúde',
        type: 'expense',
        color: '#F44336',
        emoji: '❤️',
      ),
      AccountingCategory.createDefault(
        name: 'Casa e Utilidades',
        type: 'expense',
        color: '#607D8B',
        emoji: '🏠',
      ),
      AccountingCategory.createDefault(
        name: 'Lazer',
        type: 'expense',
        color: '#E91E63',
        emoji: '🎮',
      ),
    ];
  }
}