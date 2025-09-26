# src/auth.py - Sistema de Autenticação JWT (Substitui Firebase)

from src.utils.jwt_utils import jwt_manager
from src.utils.password_utils import password_manager, validate_password
from src.models.user_mongo import User
from flask import request, jsonify
from functools import wraps
import uuid
from datetime import datetime


# ===== FUNÇÕES PRINCIPAIS (MOVIDAS PARA O INÍCIO) =====

def authenticate_user(username: str, password: str) -> dict:
    """
    Autentica usuário e retorna tokens JWT
    
    Args:
        username (str): Nome de usuário
        password (str): Senha em texto puro
        
    Returns:
        dict: Resultado com tokens se sucesso
    """
    try:
        print(f"🔐 Tentando autenticar: {username}")
        
        # 1. Validar entrada
        if not username or not password:
            print(f"❌ Dados inválidos: username='{username}', password_len={len(password) if password else 0}")
            return {'success': False, 'error': 'Username e senha são obrigatórios'}
        
        # Normalizar username (SEM .lower() - mantém case original)
        username_clean = username.strip()
        print(f"🔍 Username normalizado: '{username}' -> '{username_clean}'")
        
        # 2. Buscar usuário no MongoDB
        print(f"🔍 Buscando usuário no banco: {username_clean}")
        user = User.find_by_username(username_clean)
        if not user:
            print(f"❌ Usuário não encontrado no banco: {username_clean}")
            return {'success': False, 'error': 'Usuário não encontrado'}
        
        print(f"✅ Usuário encontrado: {user.username} (UID: {user.uid})")
        
        # 3. Verificar se usuário está ativo (se campo existir)
        if hasattr(user, 'is_active') and not user.is_active:
            print(f"❌ Usuário inativo: {username_clean}")
            return {'success': False, 'error': 'Conta desativada'}
        
        # 4. DEBUG DETALHADO DA VERIFICAÇÃO DE SENHA
        print(f"🔐 Verificando senha para: {username_clean}")
        print(f"   Senha fornecida: '{password}' (len: {len(password)})")
        print(f"   Hash armazenado: '{user.password_hash}' (len: {len(user.password_hash)})")
        print(f"   Hash válido (bcrypt): {user.password_hash.startswith('$2b$')}")
        
        # Verificar senha
        password_valid = password_manager.verify_password(password, user.password_hash)
        print(f"   Resultado verificação: {password_valid}")
        
        if not password_valid:
            print(f"❌ Senha incorreta para: {username_clean}")
            return {'success': False, 'error': 'Senha incorreta'}
        
        # 5. Preparar dados do usuário
        user_data = user.to_dict()
        print(f"📊 Dados do usuário preparados: role={user_data.get('role')}")
        
        # 6. Gerar tokens JWT
        print(f"🔑 Gerando tokens JWT...")
        access_token = jwt_manager.generate_token(user_data, 'access')
        refresh_token = jwt_manager.generate_token(user_data, 'refresh')
        print(f"✅ Tokens gerados com sucesso")
        
        # 7. Atualizar último login (se método existir)
        if hasattr(user, 'update_last_login'):
            try:
                user.update_last_login()
                print(f"📅 Último login atualizado")
            except Exception as login_update_error:
                print(f"⚠️ Falha ao atualizar último login: {login_update_error}")
        
        print(f"✅ Login bem-sucedido: {username_clean} (Role: {user_data.get('role', 'N/A')})")
        
        return {
            'success': True,
            'access_token': access_token,
            'refresh_token': refresh_token,
            'token': access_token,  # Compatibilidade com frontend atual
            'user': user_data,
            'expires_in': jwt_manager.expiration_hours * 3600  # em segundos
        }
        
    except Exception as e:
        print(f"❌ Erro crítico na autenticação: {e}")
        import traceback
        print(f"📊 Stack trace: {traceback.format_exc()}")
        return {'success': False, 'error': f'Erro interno na autenticação: {str(e)}'}


def create_user_with_password(username: str, password: str, display_name: str = None, email: str = None, role: str = 'client') -> dict:
    """
    Cria usuário com senha hash no MongoDB
    
    Args:
        username (str): Nome de usuário único
        password (str): Senha em texto puro
        display_name (str): Nome para exibição
        email (str): Email (opcional)
        role (str): Papel do usuário (client, admin, owner)
        
    Returns:
        dict: Resultado da operação
    """
    try:
        print(f"📝 Tentando criar usuário: {username}")
        
        # 1. Validar entrada
        if not username or not password:
            print(f"❌ Dados inválidos na criação: username='{username}', password_len={len(password) if password else 0}")
            return {'success': False, 'error': 'Username e senha são obrigatórios'}
        
        # Limpar e validar username (SEM .lower() - mantém case original)
        username_clean = username.strip()
        print(f"🔍 Username para criação: '{username}' -> '{username_clean}'")
        
        if len(username_clean) < 3:
            return {'success': False, 'error': 'Username deve ter pelo menos 3 caracteres'}
        
        if len(username_clean) > 50:
            return {'success': False, 'error': 'Username muito longo (máximo 50 caracteres)'}
        
        # 2. Validar força da senha
        print(f"🔒 Validando força da senha...")
        is_valid, password_error = validate_password(password)
        if not is_valid:
            print(f"❌ Senha inválida: {password_error}")
            return {'success': False, 'error': password_error}
        
        # 3. Verificar se usuário já existe
        print(f"🔍 Verificando se usuário já existe: {username_clean}")
        existing_user = User.find_by_username(username_clean)
        if existing_user:
            print(f"❌ Usuário já existe: {username_clean}")
            return {'success': False, 'error': 'Nome de usuário já existe'}
        
        # 4. Verificar email se fornecido
        if email:
            print(f"📧 Verificando email: {email}")
            existing_email = User.find_by_email(email)
            if existing_email:
                print(f"❌ Email já existe: {email}")
                return {'success': False, 'error': 'Email já está em uso'}
        
        # 5. Criar hash da senha COM DEBUG
        print(f"🔐 Gerando hash da senha...")
        print(f"   Senha original: '{password}' (len: {len(password)})")
        password_hash = password_manager.hash_password(password)
        print(f"   Hash gerado: '{password_hash}' (len: {len(password_hash)})")
        print(f"   Hash válido (bcrypt): {password_hash.startswith('$2b$')}")
        
        # TESTE CRÍTICO: Verificar se hash funciona imediatamente
        immediate_test = password_manager.verify_password(password, password_hash)
        print(f"   Teste imediato do hash: {immediate_test}")
        if not immediate_test:
            print(f"❌ ERRO CRÍTICO: Hash não verifica imediatamente!")
            return {'success': False, 'error': 'Erro na geração da senha'}
        
        # 6. Gerar UID único
        new_uid = str(uuid.uuid4())
        print(f"🆔 UID gerado: {new_uid}")
        
        # 7. Criar usuário
        print(f"👤 Criando objeto usuário...")
        new_user = User(
            uid=new_uid,
            username=username_clean,
            password_hash=password_hash,
            display_name=display_name or username_clean,
            email=email,
            role=role,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        # 8. Salvar no MongoDB COM DEBUG
        print(f"💾 Salvando usuário no MongoDB...")
        saved_user = new_user.save()
        if not saved_user:
            print(f"❌ Falha ao salvar usuário no banco")
            return {'success': False, 'error': 'Falha ao salvar usuário no banco de dados'}
        
        print(f"✅ Usuário criado com sucesso: {username_clean} (UID: {new_uid})")
        print(f"📊 Role: {role}, Email: {email or 'N/A'}")
        
        return {
            'success': True, 
            'user': saved_user.to_dict(),
            'message': f'Usuário {username_clean} criado com sucesso'
        }
        
    except Exception as e:
        print(f"❌ Erro crítico na criação de usuário: {e}")
        import traceback
        print(f"📊 Stack trace: {traceback.format_exc()}")
        return {'success': False, 'error': f'Erro interno na criação: {str(e)}'}


def verify_token(f):
    """
    Decorator para verificar token JWT em rotas protegidas
    Substitui o decorator verify_token do Firebase
    
    Args:
        f: Função da rota a proteger
        
    Returns:
        function: Função decorada
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # =======================================================================
        # === INÍCIO DA SEÇÃO COM LOGS DE DIAGNÓSTICO DETALHADOS ===
        # =======================================================================
        payload = None
        token = None
        try:
            print(f"🔐 [VERIFY_TOKEN] Iniciando verificação para rota: {request.endpoint}")
            
            # --- ETAPA 1: Extrair token do cabeçalho ---
            auth_header = request.headers.get('Authorization')
            if not auth_header:
                print(f"❌ [VERIFY_TOKEN] FALHA: Cabeçalho 'Authorization' ausente.")
                return jsonify({'error': 'Token de autorização ausente'}), 401
            
            if not auth_header.startswith('Bearer '):
                print(f"❌ [VERIFY_TOKEN] FALHA: Formato de token inválido. Não começa com 'Bearer '.")
                return jsonify({'error': 'Formato de token inválido. Use: Bearer <token>'}), 401
            
            token = auth_header.split(' ')[1]
            token_preview = f"{token[:20]}..." if len(token) > 20 else token
            print(f"🔑 [VERIFY_TOKEN] Token extraído com sucesso: {token_preview}")
            
            # --- ETAPA 2: Verificar assinatura e expiração do token ---
            print(f"🔎 [VERIFY_TOKEN] Tentando decodificar e validar o token JWT...")
            payload = jwt_manager.verify_token(token, 'access')
            if not payload:
                # Esta condição pode ser acionada por expiração, assinatura inválida, etc.
                print(f"❌ [VERIFY_TOKEN] FALHA: jwt_manager.verify_token retornou None. Token inválido ou expirado.")
                return jsonify({'error': 'Token inválido ou expirado'}), 401
            
            print(f"✅ [VERIFY_TOKEN] Token decodificado com sucesso. Payload: {payload}")
            
            # --- ETAPA 3: Buscar usuário no MongoDB com base no UID do token ---
            user_uid = payload.get('uid')
            if not user_uid:
                print(f"❌ [VERIFY_TOKEN] FALHA: Payload do token não contém 'uid'.")
                return jsonify({'error': 'Payload do token inválido'}), 401
                
            print(f"👤 [VERIFY_TOKEN] Buscando usuário no banco com UID: {user_uid}")
            user = User.find_by_uid(user_uid)
            if not user:
                print(f"❌ [VERIFY_TOKEN] FALHA: Usuário com UID '{user_uid}' não encontrado no banco de dados.")
                return jsonify({'error': 'Usuário do token não encontrado no sistema'}), 401
            
            print(f"✅ [VERIFY_TOKEN] Usuário encontrado: {user.username} (Role: {user.role})")
            
            # --- ETAPA 4: Verificar se o usuário está ativo ---
            if hasattr(user, 'is_active') and not user.is_active:
                print(f"🚫 [VERIFY_TOKEN] FALHA: Usuário '{user.username}' está inativo.")
                return jsonify({'error': 'Conta desativada'}), 403
            
            # --- ETAPA 5: Passar dados para a função da rota ---
            current_user_uid = user.uid
            current_user_data = user.to_dict()
            
            print(f"🚀 [VERIFY_TOKEN] Verificação concluída. Executando a função da rota '{request.endpoint}'.")
            return f(current_user_uid, current_user_data, *args, **kwargs)
            
        except Exception as e:
            # Este bloco captura qualquer erro inesperado durante o processo
            print(f"💥 [VERIFY_TOKEN] ERRO CRÍTICO INESPERADO!")
            print(f"   - Mensagem do Erro: {e}")
            # Adiciona logs de contexto para ajudar na depuração
            print(f"   - Contexto do Erro:")
            print(f"     - Rota: {request.endpoint}")
            print(f"     - Token (preview): {token_preview if 'token_preview' in locals() else 'N/A'}")
            print(f"     - Payload (se decodificado): {payload if payload else 'N/A'}")
            import traceback
            print(f"   - Stack Trace Completo:")
            print(traceback.format_exc())
            # Retorna a mensagem de erro que você está vendo
            return jsonify({'error': 'Erro interno na verificação do token'}), 500
        # =======================================================================
        # === FIM DA SEÇÃO COM LOGS DE DIAGNÓSTICO DETALHADOS ===
        # =======================================================================
    
    return decorated_function


# ===== FUNÇÕES DE TOKENS =====

def get_user_from_token(token: str) -> dict:
    """
    Obtém dados do usuário a partir do token (para compatibilidade)
    
    Args:
        token (str): Token JWT
        
    Returns:
        dict: Dados do usuário ou erro
    """
    try:
        print(f"🔍 Obtendo usuário do token...")
        payload = jwt_manager.verify_token(token, 'access')
        if not payload:
            print(f"❌ Token inválido para obter usuário")
            return {'success': False, 'error': 'Token inválido'}
        
        user = User.find_by_uid(payload['uid'])
        if not user:
            print(f"❌ Usuário não encontrado: {payload['uid']}")
            return {'success': False, 'error': 'Usuário não encontrado'}
        
        print(f"✅ Usuário obtido do token: {user.username}")
        return {'success': True, 'user': user.to_dict()}
        
    except Exception as e:
        print(f"❌ Erro ao obter usuário do token: {e}")
        return {'success': False, 'error': str(e)}


def refresh_user_token(refresh_token: str) -> dict:
    """
    Renova token de acesso usando refresh token
    
    Args:
        refresh_token (str): Token de refresh
        
    Returns:
        dict: Novos tokens ou erro
    """
    try:
        print(f"🔄 Renovando token JWT...")
        tokens = jwt_manager.refresh_token(refresh_token)
        if not tokens:
            print(f"❌ Refresh token inválido")
            return {'success': False, 'error': 'Refresh token inválido ou expirado'}
        
        print(f"✅ Tokens renovados com sucesso")
        return {
            'success': True,
            'access_token': tokens['access_token'],
            'refresh_token': tokens['refresh_token'],
            'token': tokens['access_token'],  # Compatibilidade
            'expires_in': jwt_manager.expiration_hours * 3600
        }
        
    except Exception as e:
        print(f"❌ Erro ao renovar token: {e}")
        return {'success': False, 'error': str(e)}


def update_user_password(uid: str, old_password: str, new_password: str) -> dict:
    """
    Atualiza senha do usuário
    
    Args:
        uid (str): UID do usuário
        old_password (str): Senha atual
        new_password (str): Nova senha
        
    Returns:
        dict: Resultado da operação
    """
    try:
        print(f"🔐 Atualizando senha para UID: {uid}")
        
        # 1. Buscar usuário
        user = User.find_by_uid(uid)
        if not user:
            print(f"❌ Usuário não encontrado para atualização: {uid}")
            return {'success': False, 'error': 'Usuário não encontrado'}
        
        print(f"✅ Usuário encontrado: {user.username}")
        
        # 2. Verificar senha atual
        print(f"🔍 Verificando senha atual...")
        if not password_manager.verify_password(old_password, user.password_hash):
            print(f"❌ Senha atual incorreta")
            return {'success': False, 'error': 'Senha atual incorreta'}
        
        # 3. Validar nova senha
        print(f"🔒 Validando nova senha...")
        is_valid, password_error = validate_password(new_password)
        if not is_valid:
            print(f"❌ Nova senha inválida: {password_error}")
            return {'success': False, 'error': password_error}
        
        # 4. Verificar se nova senha é diferente
        if password_manager.verify_password(new_password, user.password_hash):
            print(f"❌ Nova senha igual à atual")
            return {'success': False, 'error': 'A nova senha deve ser diferente da atual'}
        
        # 5. Atualizar senha
        print(f"🔐 Gerando novo hash...")
        new_password_hash = password_manager.hash_password(new_password)
        user.password_hash = new_password_hash
        user.updated_at = datetime.utcnow()
        user.save()
        
        print(f"✅ Senha atualizada para usuário: {user.username}")
        return {'success': True, 'message': 'Senha atualizada com sucesso'}
        
    except Exception as e:
        print(f"❌ Erro ao atualizar senha: {e}")
        return {'success': False, 'error': str(e)}


# ===== FUNÇÕES DE COMPATIBILIDADE (MANTIDAS COMO ESTAVAM) =====

def reset_user_password(uid: str) -> dict:
    """
    Reseta senha do usuário para uma temporária
    
    Args:
        uid (str): UID do usuário
        
    Returns:
        dict: Resultado com nova senha temporária
    """
    try:
        user = User.find_by_uid(uid)
        if not user:
            return {'success': False, 'error': 'Usuário não encontrado'}
        
        # Gerar senha temporária
        temp_password = password_manager.generate_random_password(length=8)
        temp_password_hash = password_manager.hash_password(temp_password)
        
        # Atualizar no banco
        user.password_hash = temp_password_hash
        user.updated_at = datetime.utcnow()
        user.save()
        
        return {
            'success': True,
            'temporary_password': temp_password,
            'message': 'Senha resetada. Use a senha temporária para fazer login.'
        }
        
    except Exception as e:
        return {'success': False, 'error': str(e)}


def initialize_firebase():
    """Função vazia para compatibilidade - Firebase não é mais necessário"""
    print("⚠️ initialize_firebase() chamada - Firebase foi substituído por JWT")
    pass


def create_user(email, password, display_name=None):
    """Função de compatibilidade - redireciona para create_user_with_password"""
    print("⚠️ create_user() compatibilidade - usando create_user_with_password")
    # Usar email como username se não tiver @, senão extrair parte antes do @
    username = email.split('@')[0] if '@' in email else email
    return create_user_with_password(username, password, display_name, email)


def generate_custom_token(uid):
    """Função de compatibilidade - gera token JWT"""
    print("⚠️ generate_custom_token() compatibilidade - usando JWT")
    try:
        user = User.find_by_uid(uid)
        if not user:
            return None
        
        return jwt_manager.generate_token(user.to_dict(), 'access')
    except Exception as e:
        print(f"Erro ao gerar token customizado: {e}")
        return None


def verify_password_and_get_uid(email, password):
    """Função de compatibilidade - autentica por email"""
    print("⚠️ verify_password_and_get_uid() compatibilidade")
    try:
        # Tentar por email primeiro
        user = User.find_by_email(email)
        if not user:
            # Tentar por username
            username = email.split('@')[0] if '@' in email else email
            user = User.find_by_username(username)
        
        if not user:
            return None
        
        if password_manager.verify_password(password, user.password_hash):
            return user.uid
        return None
        
    except Exception as e:
        print(f"Erro na verificação de senha compatibilidade: {e}")
        return None


def get_user_by_email(email):
    """Compatibilidade"""
    try:
        user = User.find_by_email(email)
        if user:
            return {'success': True, 'user': {'uid': user.uid, 'email': user.email}}
        return {'success': False, 'error': 'Usuário não encontrado'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def update_user(uid, **kwargs):
    """Compatibilidade"""
    try:
        user = User.find_by_uid(uid)
        if not user:
            return {'success': False, 'error': 'Usuário não encontrado'}
        
        # Atualizar campos permitidos
        for key, value in kwargs.items():
            if hasattr(user, key) and key not in ['password_hash', 'uid']:
                setattr(user, key, value)
        
        user.updated_at = datetime.utcnow()
        user.save()
        return {'success': True, 'uid': user.uid}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def delete_user(uid):
    """Compatibilidade"""
    try:
        user = User.find_by_uid(uid)
        if not user:
            return {'success': False, 'error': 'Usuário não encontrado'}
        
        # Marcar como inativo em vez de deletar
        if hasattr(user, 'is_active'):
            user.is_active = False
            user.save()
        
        return {'success': True}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def verify_user_token(token):
    """Compatibilidade"""
    try:
        payload = jwt_manager.verify_token(token, 'access')
        if payload:
            return {'success': True, 'user': payload}
        return {'success': False, 'error': 'Token inválido'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


# ===== UTILITÁRIOS ADICIONAIS =====

def get_token_info(token: str) -> dict:
    """Obtém informações detalhadas sobre um token"""
    return jwt_manager.get_token_info(token)


def is_token_expired(token: str) -> bool:
    """Verifica se token está expirado"""
    info = jwt_manager.get_token_info(token)
    return info.get('expired', True)


def get_user_role_from_token(token: str) -> str:
    """Extrai role do usuário do token"""
    try:
        payload = jwt_manager.verify_token(token, 'access')
        return payload.get('role', 'client') if payload else 'client'
    except Exception as e:
        print(f"❌ Erro ao extrair role do token: {e}")
        return 'client'
