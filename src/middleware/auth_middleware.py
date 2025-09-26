# src/middleware/auth_middleware.py - Middleware JWT (Atualizado)

from functools import wraps
from flask import jsonify
from src.auth import verify_token

def authorize_role(allowed_roles):
    """
    Decorator para verificar se o papel do usuário está na lista de papéis permitidos.
    Este decorator DEVE ser usado DEPOIS de @verify_token.
    
    Agora funciona com tokens JWT em vez de Firebase tokens.
    
    Args:
        allowed_roles (list): Lista de roles permitidas (ex: ['owner', 'admin'])
        
    Returns:
        function: Decorator que verifica autorização
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
            # O dicionário 'current_user_data' é passado pelo @verify_token.
            # Ele contém o papel do usuário vindo do token JWT.
            user_role = current_user_data.get('role')

            # Se o usuário não tiver um papel ou se o papel não estiver na lista de permitidos...
            if not user_role or user_role not in allowed_roles:
                return jsonify({
                    'error': 'Acesso negado. Permissão insuficiente.',
                    'required_roles': allowed_roles,
                    'user_role': user_role or 'Nenhum',
                    'user_id': current_user_uid
                }), 403

            # Se a permissão for válida, simplesmente chama a função original
            # com os mesmos argumentos que recebeu. Não adiciona nem remove nada.
            return f(current_user_uid, current_user_data, *args, **kwargs)
            
        return decorated_function
    return decorator


# --- Decorators Específicos ---
# Agora são muito mais simples de ler e usar com JWT.

def is_owner(f):
    """
    Decorator que permite acesso apenas para usuários com role 'owner'
    
    Usage:
        @app.route('/admin/super-secret')
        @verify_token
        @is_owner
        def super_secret_endpoint(uid, user_data):
            return jsonify({'message': 'Only owners see this'})
    """
    return authorize_role(['owner'])(f)


def is_admin(f):
    """
    Decorator que permite acesso para 'owner' e 'admin'
    
    Usage:
        @app.route('/admin/dashboard')
        @verify_token
        @is_admin
        def admin_dashboard(uid, user_data):
            return jsonify({'message': 'Admins and owners see this'})
    """
    return authorize_role(['owner', 'admin'])(f)


def is_admin_or_self(f):
    """
    Decorator que permite acesso para admins ou para o próprio usuário
    Útil para endpoints de perfil onde usuário pode ver próprios dados
    
    Usage:
        @app.route('/users/<user_id>')
        @verify_token
        @is_admin_or_self
        def get_user_profile(uid, user_data, user_id):
            # Lógica já verifica se é admin OU se user_id == uid
            pass
    """
    @wraps(f)
    def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
        user_role = current_user_data.get('role')
        
        # Se é admin, pode acessar qualquer perfil
        if user_role in ['owner', 'admin']:
            return f(current_user_uid, current_user_data, *args, **kwargs)
        
        # Se não é admin, só pode acessar próprio perfil
        # Assumindo que o user_id está nos kwargs ou args
        target_user_id = kwargs.get('user_id') or (args[0] if args else None)
        
        if target_user_id == current_user_uid:
            return f(current_user_uid, current_user_data, *args, **kwargs)
        
        return jsonify({
            'error': 'Acesso negado. Você só pode acessar seus próprios dados.',
            'user_role': user_role,
            'requested_user': target_user_id,
            'current_user': current_user_uid
        }), 403
    
    return decorated_function


def require_any_role(roles):
    """
    Decorator flexível que aceita qualquer lista de roles
    
    Args:
        roles (list): Lista de roles permitidas
        
    Usage:
        @require_any_role(['admin', 'moderator', 'owner'])
        @verify_token
        def some_endpoint(uid, user_data):
            pass
    """
    return authorize_role(roles)


def is_authenticated_user(f):
    """
    Decorator que apenas verifica se o usuário está autenticado (qualquer role)
    Útil para endpoints que precisam apenas de login válido
    
    Usage:
        @app.route('/profile')
        @verify_token
        @is_authenticated_user
        def user_profile(uid, user_data):
            # Qualquer usuário logado pode acessar
            pass
    """
    @wraps(f)
    def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
        # Se chegou até aqui, o @verify_token já validou o token
        # Apenas garantir que tem dados válidos
        if not current_user_uid or not current_user_data.get('username'):
            return jsonify({
                'error': 'Dados do usuário inválidos no token'
            }), 401
        
        return f(current_user_uid, current_user_data, *args, **kwargs)
    
    return decorated_function


def check_user_active(f):
    """
    Decorator que verifica se usuário está ativo (se campo existir)
    
    Usage:
        @verify_token
        @check_user_active
        def some_endpoint(uid, user_data):
            pass
    """
    @wraps(f)
    def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
        # Verificar se usuário está ativo
        is_active = current_user_data.get('is_active', True)  # Default True se não existir
        
        if not is_active:
            return jsonify({
                'error': 'Conta desativada. Entre em contato com o suporte.',
                'user_id': current_user_uid
            }), 403
        
        return f(current_user_uid, current_user_data, *args, **kwargs)
    
    return decorated_function


# --- Utilitários para uso nas rotas ---

def get_current_user_role(current_user_data):
    """
    Extrai role do usuário dos dados do token
    
    Args:
        current_user_data (dict): Dados do usuário do token
        
    Returns:
        str: Role do usuário
    """
    return current_user_data.get('role', 'client')


def is_user_admin(current_user_data):
    """
    Verifica se usuário é admin ou owner
    
    Args:
        current_user_data (dict): Dados do usuário do token
        
    Returns:
        bool: True se é admin/owner
    """
    role = get_current_user_role(current_user_data)
    return role in ['admin', 'owner']


def is_user_owner(current_user_data):
    """
    Verifica se usuário é owner
    
    Args:
        current_user_data (dict): Dados do usuário do token
        
    Returns:
        bool: True se é owner
    """
    role = get_current_user_role(current_user_data)
    return role == 'owner'


def can_user_access_resource(current_user_data, resource_owner_id, current_user_uid):
    """
    Verifica se usuário pode acessar recurso específico
    Admin pode acessar tudo, usuários só seus próprios recursos
    
    Args:
        current_user_data (dict): Dados do usuário do token
        resource_owner_id (str): ID do dono do recurso
        current_user_uid (str): UID do usuário atual
        
    Returns:
        bool: True se pode acessar
    """
    # Admin pode acessar qualquer recurso
    if is_user_admin(current_user_data):
        return True
    
    # Usuário comum só pode acessar próprios recursos
    return resource_owner_id == current_user_uid


# --- Decorator combinado mais usado ---

def admin_or_owner_required(f):
    """
    Decorator combinado: verifica JWT e role admin/owner
    Mais conveniente para uso comum
    
    Usage:
        @app.route('/admin/products')
        @admin_or_owner_required
        def manage_products(uid, user_data):
            # Automaticamente protegido para admin/owner apenas
            pass
    """
    @verify_token
    @is_admin
    @wraps(f)
    def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
        return f(current_user_uid, current_user_data, *args, **kwargs)
    
    return decorated_function


def owner_only_required(f):
    """
    Decorator combinado: verifica JWT e role owner
    Para operações super sensíveis
    
    Usage:
        @app.route('/admin/delete-everything')
        @owner_only_required
        def dangerous_operation(uid, user_data):
            pass
    """
    @verify_token
    @is_owner
    @wraps(f)
    def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
        return f(current_user_uid, current_user_data, *args, **kwargs)
    
    return decorated_function


def authenticated_user_required(f):
    """
    Decorator combinado: verifica JWT apenas (qualquer usuário logado)
    
    Usage:
        @app.route('/my-profile')
        @authenticated_user_required
        def my_profile(uid, user_data):
            pass
    """
    @verify_token
    @is_authenticated_user
    @wraps(f)
    def decorated_function(current_user_uid, current_user_data, *args, **kwargs):
        return f(current_user_uid, current_user_data, *args, **kwargs)
    
    return decorated_function
