
// lib/models/user.dart - VERSÃO CORRIGIDA COM GETTER ID

@pragma('vm:entry-point')
class User {
  final String uid;
  final String username;
  final String? displayName;
  final String? email;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // NOVOS CAMPOS: Informações de contato e PIX
  final String? phoneNumber;
  final String? pixKey;
  final String? pixQrCodeUrl;

  // <<< MUDANÇA: Getters para verificar o papel do usuário de forma computada
  bool get isAdmin => role == 'admin' || role == 'owner';
  bool get isOwner => role == 'owner';
  
  // <<< ADICIONADO: Getter 'id' que retorna o 'uid' - SOLUÇÃO PARA O ERRO
  String get id => uid;

  const User({
    required this.uid,
    required this.username,
    required this.role,
    this.displayName,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.phoneNumber,
    this.pixKey,
    this.pixQrCodeUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'client', 
      displayName: json['display_name'] ?? json['displayName'],
      email: json['email'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      pixKey: json['pix_key'] ?? json['pixKey'],
      pixQrCodeUrl: json['pix_qr_code_url'] ?? json['pixQrCodeUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'display_name': displayName,
      'email': email,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'phone_number': phoneNumber,
      'pix_key': pixKey,
      'pix_qr_code_url': pixQrCodeUrl,
    };
  }

  User copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? phoneNumber,
    String? pixKey,
    String? pixQrCodeUrl,
  }) {
    return User(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pixKey: pixKey ?? this.pixKey,
      pixQrCodeUrl: pixQrCodeUrl ?? this.pixQrCodeUrl,
    );
  }

  @override
  String toString() {
    return 'User{uid: $uid, username: $username, displayName: $displayName, email: $email, role: $role, phoneNumber: $phoneNumber, pixKey: ${pixKey != null ? '***' : null}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          username == other.username &&
          displayName == other.displayName &&
          email == other.email &&
          role == other.role &&
          phoneNumber == other.phoneNumber &&
          pixKey == other.pixKey &&
          pixQrCodeUrl == other.pixQrCodeUrl;

  @override
  int get hashCode =>
      uid.hashCode ^
      username.hashCode ^
      displayName.hashCode ^
      email.hashCode ^
      role.hashCode ^
      phoneNumber.hashCode ^
      pixKey.hashCode ^
      pixQrCodeUrl.hashCode;
}
