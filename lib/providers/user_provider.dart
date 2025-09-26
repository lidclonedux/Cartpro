import 'package:flutter/material.dart';
// <<< CORREÇÃO: O nome do arquivo foi corrigido de 'user_model.dart' para 'user.dart'.
import '../models/user.dart'; 
import '../services/api_service.dart'; // <<< MUDANÇA ESTRUTURAL: Importar o ApiService

// <<< MUDANÇA ESTRUTURAL >>>
// A classe UserModel (agora User) está corretamente definida em lib/models/user.dart
// para seguir as boas práticas do Dart.
class UserProvider extends ChangeNotifier {
  // <<< MUDANÇA ESTRUTURAL >>>
  // Armazena a instância do ApiService que será injetada.
  // Embora não seja usado ativamente agora, prepara o provider para futuras
  // funcionalidades, como "editar perfil", e mantém a consistência da arquitetura.
  final ApiService? apiService;

  // <<< CORREÇÃO: O tipo da variável foi corrigido de 'UserModel' para 'User'.
  User? _user;
  bool _isLoading = false;

  // <<< MUDANÇA ESTRUTURAL >>>
  // O construtor agora recebe a instância do ApiService.
  UserProvider(this.apiService);
  
  // <<< CORREÇÃO: O tipo de retorno do getter foi corrigido.
  User? get user => _user;
  bool get isLoading => _isLoading;
  
  // <<< CORREÇÃO: O tipo do parâmetro do método foi corrigido.
  void setUser(User user) {
    _user = user;
    notifyListeners();
  }
  
  void clearUser() {
    _user = null;
    notifyListeners();
  }
  
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // A lógica de isLoggedIn, isAdmin e isOwner foi movida para o AuthProvider,
  // que é a fonte única da verdade sobre o estado de autenticação.
  // Manter essa lógica aqui criaria redundância e possíveis conflitos de estado.
  // O UserProvider agora se concentra apenas em gerenciar os dados do perfil do usuário,
  // uma vez que o AuthProvider confirme que ele está logado.
}
