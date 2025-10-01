# src/utils/jwt_utils.py - Sistema de JWT Tokens

import jwt
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, Union
from src.config import Config
import secrets
import uuid


class JWTManager:
    """Gerenciador de tokens JWT para autenticação"""
    
    def __init__(self):
        self.secret_key = Config.JWT_SECRET_KEY
        self.algorithm = Config.JWT_ALGORITHM
        self.expiration_hours = Config.JWT_EXPIRATION_HOURS
        self.refresh_hours = Config.JWT_REFRESH_HOURS
        
        # Validar configurações
        if not self.secret_key or len(self.secret_key) < 32:
            raise ValueError("JWT_SECRET_KEY deve ter pelo menos 32 caracteres")
    
    def generate_token(self, user_data: Dict[str, Any], token_type: str = 'access') -> str:
        """
        Gera token JWT com dados do usuário
        
        Args:
            user_data (dict): Dados do usuário do MongoDB
            token_type (str): 'access' ou 'refresh'
            
        Returns:
            str: Token JWT assinado
        """
        now = datetime.utcnow()
        
        # Definir tempo de expiração baseado no tipo
        if token_type == 'refresh':
            exp_hours = self.refresh_hours
        else:
            exp_hours = self.expiration_hours
        
        # Payload padrão
        payload = {
            # Claims registrados (RFC 7519)
            'iss': 'vitrine-borracharia',  # Issuer
            'sub': user_data.get('uid'),   # Subject (user ID)
            'aud': 'vitrine-borracharia-app',  # Audience
            'iat': now,                    # Issued At
            'exp': now + timedelta(hours=exp_hours),  # Expiration
            'nbf': now,                    # Not Before
            'jti': str(uuid.uuid4()),      # JWT ID (único)
            
            # Claims customizados do projeto
            'uid': user_data.get('uid'),
            'username': user_data.get('username'),
            'role': user_data.get('role', 'client'),
            'display_name': user_data.get('display_name'),
            'email': user_data.get('email'),
            'token_type': token_type,
            
            # Metadados de segurança
            'session_id': str(uuid.uuid4()),
            'created_at': user_data.get('created_at'),
        }
        
        try:
            token = jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
            print(f"Token {token_type} gerado para usuário: {user_data.get('username')}")
            return token
            
        except Exception as e:
            print(f"Erro ao gerar token JWT: {e}")
            raise RuntimeError(f"Falha na geração do token: {e}")
    
    def verify_token(self, token: str, token_type: str = 'access') -> Optional[Dict[str, Any]]:
        """
        Verifica e decodifica token JWT
        
        Args:
            token (str): Token JWT a verificar
            token_type (str): Tipo esperado ('access' ou 'refresh')
            
        Returns:
            dict ou None: Payload do token se válido, None se inválido
        """
        # =======================================================================
        # === INÍCIO DA SEÇÃO COM LOGS DE DIAGNÓSTICO DETALHADOS ===
        # =======================================================================
        if not token:
            print("🕵️ [JWT_VERIFY] FALHA PRECOCE: Token fornecido é nulo ou vazio.")
            return None
            
        try:
            print(f"🕵️ [JWT_VERIFY] Iniciando verificação para token do tipo '{token_type}'.")
            
            # Log da chave secreta (apenas o início, por segurança)
            secret_key_preview = f"{self.secret_key[:4]}...{self.secret_key[-4:]}"
            print(f"   - Usando Secret Key: '{secret_key_preview}' (tamanho: {len(self.secret_key)})")
            print(f"   - Usando Algoritmo: '{self.algorithm}'")
            
            # Decodificar token
            payload = jwt.decode(
                token, 
                self.secret_key, 
                algorithms=[self.algorithm],
                options={
                    'verify_signature': True,
                    'verify_exp': True,
                    'verify_nbf': True,
                    'verify_iat': True,
                    'verify_aud': True
                },
                audience='vitrine-borracharia-app'
            )
            
            print("✅ [JWT_VERIFY] Token decodificado com sucesso pela biblioteca JWT.")
            
            # Verificar tipo de token
            if payload.get('token_type') != token_type:
                print(f"❌ [JWT_VERIFY] FALHA: Tipo de token incorreto. Esperado: '{token_type}', Recebido: '{payload.get('token_type')}'")
                return None
            
            # Verificar campos obrigatórios
            required_fields = ['uid', 'username', 'role']
            for field in required_fields:
                if not payload.get(field):
                    print(f"❌ [JWT_VERIFY] FALHA: Campo obrigatório '{field}' ausente no payload do token.")
                    return None
            
            print("✅ [JWT_VERIFY] Todas as verificações passaram. Token é válido.")
            return payload
            
        except jwt.ExpiredSignatureError:
            print("🕒 [JWT_VERIFY] FALHA: Token JWT expirado.")
            return None
        except jwt.InvalidTokenError as e:
            # Erro genérico da biblioteca, como assinatura inválida, etc.
            print(f"❌ [JWT_VERIFY] FALHA: Token JWT inválido. Erro da biblioteca: {e}")
            return None
        except Exception as e:
            # Captura qualquer outro erro inesperado durante o processo
            print(f"💥 [JWT_VERIFY] ERRO CRÍTICO INESPERADO ao verificar token.")
            print(f"   - Mensagem do Erro: {e}")
            import traceback
            print(f"   - Stack Trace:")
            print(traceback.format_exc())
            return None
        # =======================================================================
        # === FIM DA SEÇÃO COM LOGS DE DIAGNÓSTICO DETALHADOS ===
        # =======================================================================
    
    def refresh_token(self, refresh_token: str) -> Optional[Dict[str, str]]:
        """
        Renova token usando refresh token
        
        Args:
            refresh_token (str): Token de refresh
            
        Returns:
            dict ou None: Novos tokens se válido
        """
        # Verificar refresh token
        payload = self.verify_token(refresh_token, token_type='refresh')
        if not payload:
            return None
        
        try:
            # Remover campos temporais para renovação
            user_data = {
                'uid': payload['uid'],
                'username': payload['username'],
                'role': payload['role'],
                'display_name': payload.get('display_name'),
                'email': payload.get('email'),
                'created_at': payload.get('created_at')
            }
            
            # Gerar novos tokens
            new_access_token = self.generate_token(user_data, 'access')
            new_refresh_token = self.generate_token(user_data, 'refresh')
            
            return {
                'access_token': new_access_token,
                'refresh_token': new_refresh_token
            }
            
        except Exception as e:
            print(f"Erro ao renovar token: {e}")
            return None
    
    def decode_without_verify(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Decodifica token sem verificar assinatura (apenas para debug/logs)
        
        Args:
            token (str): Token a decodificar
            
        Returns:
            dict ou None: Payload se decodificável
        """
        try:
            payload = jwt.decode(token, options={"verify_signature": False})
            return payload
        except Exception as e:
            print(f"Erro ao decodificar token: {e}")
            return None
    
    def get_token_info(self, token: str) -> Dict[str, Any]:
        """
        Obtém informações detalhadas sobre o token
        
        Args:
            token (str): Token a analisar
            
        Returns:
            dict: Informações do token
        """
        info = {
            'valid': False,
            'expired': False,
            'payload': None,
            'error': None,
            'expires_at': None,
            'time_remaining': None
        }
        
        try:
            # Tentar decodificar sem verificar
            payload = self.decode_without_verify(token)
            if payload:
                info['payload'] = payload
                
                # Verificar expiração
                if 'exp' in payload:
                    exp_timestamp = payload['exp']
                    exp_datetime = datetime.utcfromtimestamp(exp_timestamp)
                    now = datetime.utcnow()
                    
                    info['expires_at'] = exp_datetime.isoformat()
                    info['expired'] = now > exp_datetime
                    
                    if not info['expired']:
                        remaining = exp_datetime - now
                        info['time_remaining'] = str(remaining)
            
            # Verificar se é válido
            verified_payload = self.verify_token(token)
            info['valid'] = verified_payload is not None
            
        except Exception as e:
            info['error'] = str(e)
        
        return info
    
    def generate_secure_random_key(self, length: int = 64) -> str:
        """
        Gera chave secreta aleatória para JWT
        
        Args:
            length (int): Tamanho da chave em bytes
            
        Returns:
            str: Chave secreta em hex
        """
        return secrets.token_hex(length)
    
    def create_password_reset_token(self, user_uid: str, expires_minutes: int = 30) -> str:
        """
        Cria token especial para reset de senha
        
        Args:
            user_uid (str): UID do usuário
            expires_minutes (int): Minutos até expirar
            
        Returns:
            str: Token de reset
        """
        now = datetime.utcnow()
        payload = {
            'iss': 'vitrine-borracharia',
            'sub': user_uid,
            'aud': 'password-reset',
            'iat': now,
            'exp': now + timedelta(minutes=expires_minutes),
            'token_type': 'password_reset',
            'uid': user_uid,
            'jti': str(uuid.uuid4())
        }
        
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
    
    def verify_password_reset_token(self, token: str) -> Optional[str]:
        """
        Verifica token de reset de senha
        
        Args:
            token (str): Token de reset
            
        Returns:
            str ou None: UID do usuário se token válido
        """
        try:
            payload = jwt.decode(
                token,
                self.secret_key,
                algorithms=[self.algorithm],
                audience='password-reset'
            )
            
            if payload.get('token_type') == 'password_reset':
                return payload.get('uid')
                
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
            pass
            
        return None


# Instância global para uso em todo o projeto
jwt_manager = JWTManager()


# Funções de conveniência para compatibilidade
def generate_access_token(user_data: Dict[str, Any]) -> str:
    """Função de conveniência para gerar token de acesso"""
    return jwt_manager.generate_token(user_data, 'access')


def generate_refresh_token(user_data: Dict[str, Any]) -> str:
    """Função de conveniência para gerar token de refresh"""
    return jwt_manager.generate_token(user_data, 'refresh')


def verify_access_token(token: str) -> Optional[Dict[str, Any]]:
    """Função de conveniência para verificar token de acesso"""
    return jwt_manager.verify_token(token, 'access')


def verify_refresh_token(token: str) -> Optional[Dict[str, Any]]:
    """Função de conveniência para verificar token de refresh"""
    return jwt_manager.verify_token(token, 'refresh')
