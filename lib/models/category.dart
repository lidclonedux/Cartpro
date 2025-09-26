
// ARQUIVO REATORADO: lib/models/category.dart

@pragma('vm:entry-point')
class Category {
  final String id;
  final String name;
  final String context;
  final String? type;
  final String color;
  final String icon;
  final String emoji;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.context,
    this.type,
    required this.color,
    required this.icon,
    required this.emoji,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Cria uma instância de Category a partir de um Map (JSON vindo da API).
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Sem Categoria',
      context: json['context'] ?? 'product',
      type: json['type'],
      color: json['color'] ?? '#808080', // Cor cinza como padrão
      icon: json['icon'] ?? 'tag',
      emoji: json['emoji'] ?? '🏷️',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  /// Converte a instância de Category para um Map (JSON para enviar à API).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'context': context,
      'type': type,
      'color': color,
      'icon': icon,
      'emoji': emoji,
    };
  }

  /// Método copyWith para criar uma nova instância com campos modificados
  Category copyWith({
    String? id,
    String? name,
    String? context,
    String? type,
    String? color,
    String? icon,
    String? emoji,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      context: context ?? this.context,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, context: $context)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
