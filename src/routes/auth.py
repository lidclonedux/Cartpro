# src/routes/auth.py - Rotas de Autenticação JWT

from flask import Blueprint, request, jsonify, current_app
from src.auth import (
    authenticate_user, 
    create_user_with_password, 
    verify_token,
    refresh_user_token,
    update_user_password,
    get_user_from_token
)
from src.models.user_mongo import User
from src.utils.jwt_utils import jwt_manager
import re

auth_bp = Blueprint('auth', __name__)

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/login', methods=['POST'])
def login():
    """
    Login com username/password - substitui Firebase Auth
    """
    try:
        if not request.is_json:
            return jsonify({'error': 'Content-Type deve ser application/json'}), 400
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Body JSON inválido'}), 400
        
        username = data.get('username', '').strip()
        password = data.get('password', '')
        
        if not username:
            return jsonify({'error': 'Username é obrigatório'}), 400
        
        if not password:
            return jsonify({'error': 'Senha é obrigatória'}), 400
        
        if len(username) < 3:
            return jsonify({'error': 'Username deve ter pelo menos 3 caracteres'}), 400
        
        if len(username) > 50:
            return jsonify({'error': 'Username muito longo'}), 400
        
        result = authenticate_user(username, password)
        
        if result['success']:
            print(f"✅ Login API bem-sucedido: {username}")
            return jsonify(result), 200
        else:
            print(f"❌ Login API falhou: {username} - {result.get('error')}")
            return jsonify({'error': result['error']}), 401
            
    except Exception as e:
        print(f"❌ Erro na rota de login: {e}")
        return jsonify({'error': 'Erro interno do servidor'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/register', methods=['POST'])
def register():
    """
    Registro de novo usuário
    """
    try:
        if not request.is_json:
            return jsonify({'error': 'Content-Type deve ser application/json'}), 400
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Body JSON inválido'}), 400
        
        username = data.get('username', '').strip()
        password = data.get('password', '')
        display_name = data.get('display_name', '').strip()
        email = data.get('email', '').strip() if data.get('email') else None
        
        if not username:
            return jsonify({'error': 'Username é obrigatório'}), 400
        
        if not password:
            return jsonify({'error': 'Senha é obrigatória'}), 400
        
        if not re.match(r'^[a-zA-Z0-9_.-]+$', username):
            return jsonify({'error': 'Username só pode conter letras, números, pontos, hífens e underscores'}), 400
        
        if email and not re.match(r'^[^@]+@[^@]+\.[^@]+$', email):
            return jsonify({'error': 'Formato de email inválido'}), 400
        
        result = create_user_with_password(
            username=username,
            password=password,
            display_name=display_name or username,
            email=email,
            role='client'
        )
        
        if result['success']:
            print(f"✅ Registro bem-sucedido: {username}")
            
            login_result = authenticate_user(username, password)
            if login_result['success']:
                response = login_result.copy()
                response['message'] = 'Usuário criado e logado com sucesso'
                return jsonify(response), 201
            else:
                return jsonify(result), 201
        else:
            print(f"❌ Registro falhou: {username} - {result.get('error')}")
            return jsonify({'error': result['error']}), 400
            
    except Exception as e:
        print(f"❌ Erro na rota de registro: {e}")
        return jsonify({'error': 'Erro interno do servidor'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/profile', methods=['GET'])
@verify_token
def get_profile(current_user_uid, current_user_data):
    """
    Obter perfil do usuário logado
    """
    try:
        user = User.find_by_uid(current_user_uid)
        if not user:
            return jsonify({'error': 'Usuário não encontrado no banco'}), 404
        
        user_data = user.to_dict()
        user_data.pop('password_hash', None)
        
        print(f"✅ Perfil obtido para: {user.username}")
        return jsonify({'user': user_data}), 200
        
    except Exception as e:
        print(f"❌ Erro ao buscar perfil: {e}")
        return jsonify({'error': 'Erro ao buscar perfil do usuário'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/refresh', methods=['POST'])
def refresh_token():
    """
    Renovar token JWT usando refresh token
    """
    try:
        refresh_token = None
        
        if request.is_json:
            data = request.get_json()
            refresh_token = data.get('refresh_token') if data else None
        
        if not refresh_token:
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                refresh_token = auth_header.split(' ')[1]
        
        if not refresh_token:
            return jsonify({'error': 'Refresh token é obrigatório'}), 400
        
        result = refresh_user_token(refresh_token)
        
        if result['success']:
            print("✅ Token renovado com sucesso")
            return jsonify(result), 200
        else:
            print(f"❌ Falha ao renovar token: {result.get('error')}")
            return jsonify({'error': result['error']}), 401
            
    except Exception as e:
        print(f"❌ Erro ao renovar token: {e}")
        return jsonify({'error': 'Erro interno do servidor'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/logout', methods=['POST'])
@verify_token
def logout(current_user_uid, current_user_data):
    """
    Logout do usuário - invalida token (implementação básica)
    """
    try:
        username = current_user_data.get('username', 'unknown')
        print(f"✅ Logout realizado para: {username}")
        
        return jsonify({
            'success': True,
            'message': 'Logout realizado com sucesso'
        }), 200
        
    except Exception as e:
        print(f"❌ Erro no logout: {e}")
        return jsonify({'error': 'Erro interno do servidor'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/change-password', methods=['PUT'])
@verify_token
def change_password(current_user_uid, current_user_data):
    """
    Alterar senha do usuário logado
    """
    try:
        if not request.is_json:
            return jsonify({'error': 'Content-Type deve ser application/json'}), 400
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Body JSON inválido'}), 400
        
        current_password = data.get('current_password', '')
        new_password = data.get('new_password', '')
        
        if not current_password:
            return jsonify({'error': 'Senha atual é obrigatória'}), 400
        
        if not new_password:
            return jsonify({'error': 'Nova senha é obrigatória'}), 400
        
        result = update_user_password(current_user_uid, current_password, new_password)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify({'error': result['error']}), 400
            
    except Exception as e:
        print(f"❌ Erro ao alterar senha: {e}")
        return jsonify({'error': 'Erro interno do servidor'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/validate-token', methods=['GET'])
@verify_token
def validate_token(current_user_uid, current_user_data):
    """
    Validar se token atual ainda é válido
    """
    try:
        return jsonify({
            'valid': True,
            'user': {
                'uid': current_user_uid,
                'username': current_user_data.get('username'),
                'role': current_user_data.get('role')
            },
            'expires_in': jwt_manager.expiration_hours * 3600
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Erro na validação'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/user-info', methods=['GET'])
@verify_token
def get_user_info(current_user_uid, current_user_data):
    """
    Obter informações básicas do usuário (mais leve que /profile)
    """
    try:
        return jsonify({
            'uid': current_user_uid,
            'username': current_user_data.get('username'),
            'display_name': current_user_data.get('display_name'),
            'role': current_user_data.get('role'),
            'email': current_user_data.get('email')
        }), 200
        
    except Exception as e:
        return jsonify({'error': 'Erro ao obter informações'}), 500

# ===== ROTAS ADMINISTRATIVAS =====

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/users', methods=['GET'])
@verify_token
def list_users(current_user_uid, current_user_data):
    """
    Listar usuários (apenas para admins)
    """
    try:
        user_role = current_user_data.get('role')
        if user_role not in ['admin', 'owner']:
            return jsonify({'error': 'Acesso negado'}), 403
        
        users = User.get_all_users()
        
        safe_users = []
        for user in users:
            user_dict = user.to_dict()
            user_dict.pop('password_hash', None)
            safe_users.append(user_dict)
        
        return jsonify({'users': safe_users}), 200
        
    except Exception as e:
        print(f"❌ Erro ao listar usuários: {e}")
        return jsonify({'error': 'Erro interno'}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/users/<user_id>/role', methods=['PUT'])
@verify_token
def update_user_role(current_user_uid, current_user_data, user_id):
    """
    Atualizar role de um usuário (apenas para owners)
    """
    try:
        if current_user_data.get('role') != 'owner':
            return jsonify({'error': 'Apenas owners podem alterar roles'}), 403
        
        if not request.is_json:
            return jsonify({'error': 'Content-Type deve ser application/json'}), 400
        
        data = request.get_json()
        new_role = data.get('role')
        
        if new_role not in ['client', 'admin', 'owner']:
            return jsonify({'error': 'Role inválida'}), 400
        
        user = User.find_by_uid(user_id)
        if not user:
            return jsonify({'error': 'Usuário não encontrado'}), 404
        
        if user_id == current_user_uid:
            return jsonify({'error': 'Não é possível alterar sua própria role'}), 400
        
        user.role = new_role
        user.updated_at = datetime.utcnow()
        user.save()
        
        print(f"✅ Role do usuário {user.username} alterada para {new_role}")
        
        return jsonify({
            'success': True,
            'message': f'Role alterada para {new_role}',
            'user': {
                'uid': user.uid,
                'username': user.username,
                'role': user.role
            }
        }), 200
        
    except Exception as e:
        print(f"❌ Erro ao alterar role: {e}")
        return jsonify({'error': 'Erro interno'}), 500

# ===== ROTAS DE COMPATIBILIDADE COM SISTEMA ANTERIOR =====

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/username-login', methods=['POST'])
def username_login():
    """
    Rota de compatibilidade - mesmo que /login
    """
    return login()

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/register-with-username', methods=['POST'])
def register_with_username():
    """
    Rota de compatibilidade - mesmo que /register
    """
    return register()

# ===== ROTAS DE DEBUG (APENAS EM DESENVOLVIMENTO) =====

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/debug/token-info', methods=['POST'])
def debug_token_info():
    """
    Debug: analisar token JWT (apenas desenvolvimento)
    """
    if current_app.config.get('ENV') == 'production':
        return jsonify({'error': 'Não disponível em produção'}), 404
    
    try:
        data = request.get_json()
        token = data.get('token') if data else None
        
        if not token:
            return jsonify({'error': 'Token é obrigatório'}), 400
        
        info = jwt_manager.get_token_info(token)
        return jsonify(info), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# CORREÇÃO: Adicionado o prefixo completo '/api/auth'
@auth_bp.route('/api/auth/debug/generate-admin', methods=['POST'])
def debug_generate_admin():
    """
    Debug: criar usuário admin (apenas desenvolvimento)
    """
    if current_app.config.get('ENV') == 'production':
        return jsonify({'error': 'Não disponível em produção'}), 404
    
    try:
        result = create_user_with_password(
            username='admin',
            password='admin123',
            display_name='Administrator',
            role='admin'
        )
        return jsonify(result), 201 if result['success'] else 400
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ===== TRATAMENTO DE ERROS =====

@auth_bp.errorhandler(400)
def bad_request(error):
    return jsonify({'error': 'Requisição inválida'}), 400

@auth_bp.errorhandler(401)
def unauthorized(error):
    return jsonify({'error': 'Token inválido ou ausente'}), 401

@auth_bp.errorhandler(403)
def forbidden(error):
    return jsonify({'error': 'Acesso negado'}), 403

@auth_bp.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Erro interno do servidor'}), 500
