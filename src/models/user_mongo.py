# src/models/user_mongo.py - Modelo de Usuário Atualizado para JWT

from datetime import datetime
from typing import Optional, List, Dict, Any
from src.database.mongodb import mongodb


class User:
    """Modelo de usuário para MongoDB com suporte a autenticação JWT"""
    
    def __init__(
        self, 
        uid: str, 
        username: str, 
        password_hash: str,
        role: str = 'client',
        display_name: Optional[str] = None,
        email: Optional[str] = None,
        phone_number: Optional[str] = None,
        pix_key: Optional[str] = None,
        pix_qr_code_url: Optional[str] = None,
        is_active: bool = True,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None,
        last_login_at: Optional[datetime] = None,
        **kwargs
    ):
        """
        Inicializa usuário
        
        Args:
            uid (str): UID único do usuário
            username (str): Nome de usuário único
            password_hash (str): Hash da senha (bcrypt)
            role (str): Papel do usuário ('client', 'admin', 'owner')
            display_name (str): Nome para exibição
            email (str): Email do usuário
            phone_number (str): Telefone
            pix_key (str): Chave PIX
            pix_qr_code_url (str): URL do QR Code PIX
            is_active (bool): Se usuário está ativo
            created_at (datetime): Data de criação
            updated_at (datetime): Data da última atualização
            last_login_at (datetime): Data do último login
        """
        self.uid = uid
        self.username = username
        self.password_hash = password_hash
        self.role = role
        self.display_name = display_name or username
        self.email = email
        
        # Campos adicionais do projeto
        self.phone_number = phone_number
        self.pix_key = pix_key
        self.pix_qr_code_url = pix_qr_code_url
        
        # Campos de controle
        self.is_active = is_active
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()
        self.last_login_at = last_login_at
        
        # Campos extras (para flexibilidade)
        for key, value in kwargs.items():
            setattr(self, key, value)
    
    @property
    def db(self):
        """Referência ao banco de dados"""
        return mongodb.db
    
    @property
    def collection(self):
        """Referência à coleção de usuários"""
        return self.db.users
    
    # ===== MÉTODOS DE PERSISTÊNCIA =====
    
    def save(self) -> 'User':
        """
        Salva ou atualiza usuário no MongoDB
        
        Returns:
            User: Instância atualizada
        """
        try:
            self.updated_at = datetime.utcnow()
            
            # Preparar dados para salvar
            user_data = self.to_dict(include_sensitive=True)
            
            # Atualizar ou inserir
            result = self.collection.update_one(
                {'uid': self.uid},
                {'$set': user_data},
                upsert=True
            )
            
            print(f"✅ Usuário salvo: {self.username} (UID: {self.uid})")
            return self
            
        except Exception as e:
            print(f"❌ Erro ao salvar usuário: {e}")
            raise RuntimeError(f"Falha ao salvar usuário: {e}")
    
    def delete(self) -> bool:
        """
        Remove usuário do MongoDB (soft delete - marca como inativo)
        
        Returns:
            bool: True se deletado com sucesso
        """
        try:
            # Soft delete - marcar como inativo
            self.is_active = False
            self.updated_at = datetime.utcnow()
            self.save()
            
            print(f"✅ Usuário desativado: {self.username}")
            return True
            
        except Exception as e:
            print(f"❌ Erro ao desativar usuário: {e}")
            return False
    
    def hard_delete(self) -> bool:
        """
        Remove usuário permanentemente do MongoDB
        
        Returns:
            bool: True se deletado com sucesso
        """
        try:
            result = self.collection.delete_one({'uid': self.uid})
            success = result.deleted_count > 0
            
            if success:
                print(f"✅ Usuário removido permanentemente: {self.username}")
            else:
                print(f"⚠️ Usuário não encontrado para remoção: {self.uid}")
            
            return success
            
        except Exception as e:
            print(f"❌ Erro ao remover usuário: {e}")
            return False
    
    # ===== MÉTODOS DE CONSULTA =====
    
    @classmethod
    def find_by_uid(cls, uid: str) -> Optional['User']:
        """
        Busca usuário por UID
        
        Args:
            uid (str): UID do usuário
            
        Returns:
            User ou None: Usuário encontrado
        """
        try:
            if not uid:
                return None
                
            user_data = cls._get_collection().find_one({'uid': uid})
            if user_data:
                return cls.from_dict(user_data)
            return None
            
        except Exception as e:
            print(f"❌ Erro ao buscar usuário por UID: {e}")
            return None
    
    @classmethod
    def find_by_username(cls, username: str) -> Optional['User']:
        """
        Busca usuário por username (case-sensitive)
        """
        try:
            if not username:
                return None
            
            # Busca EXATA e literal, respeitando maiúsculas/minúsculas
            user_data = cls._get_collection().find_one({'username': username.strip()})
            
            if user_data:
                return cls.from_dict(user_data)
            return None
            
        except Exception as e:
            print(f"❌ Erro ao buscar usuário por username: {e}")
            return None
    
    @classmethod
    def find_by_email(cls, email: str) -> Optional['User']:
        """
        Busca usuário por email
        
        Args:
            email (str): Email do usuário
            
        Returns:
            User ou None: Usuário encontrado
        """
        try:
            if not email:
                return None
                
            user_data = cls._get_collection().find_one({
                'email': {'$regex': f'^{email}$', '$options': 'i'}  # Case insensitive
            })
            
            if user_data:
                return cls.from_dict(user_data)
            return None
            
        except Exception as e:
            print(f"❌ Erro ao buscar usuário por email: {e}")
            return None
    
    @classmethod
    def get_all_users(cls, active_only: bool = True) -> List['User']:
        """
        Busca todos os usuários
        
        Args:
            active_only (bool): Se deve retornar apenas usuários ativos
            
        Returns:
            List[User]: Lista de usuários
        """
        try:
            query = {'is_active': True} if active_only else {}
            users_data = cls._get_collection().find(query).sort('created_at', -1)
            
            users = []
            for user_data in users_data:
                user = cls.from_dict(user_data)
                if user:
                    users.append(user)
            
            return users
            
        except Exception as e:
            print(f"❌ Erro ao buscar todos os usuários: {e}")
            return []
    
    @classmethod
    def get_users_by_role(cls, role: str, active_only: bool = True) -> List['User']:
        """
        Busca usuários por role
        
        Args:
            role (str): Role a buscar ('client', 'admin', 'owner')
            active_only (bool): Se deve retornar apenas usuários ativos
            
        Returns:
            List[User]: Lista de usuários
        """
        try:
            query = {'role': role}
            if active_only:
                query['is_active'] = True
                
            users_data = cls._get_collection().find(query).sort('created_at', -1)
            
            users = []
            for user_data in users_data:
                user = cls.from_dict(user_data)
                if user:
                    users.append(user)
            
            return users
            
        except Exception as e:
            print(f"❌ Erro ao buscar usuários por role: {e}")
            return []
    
    @classmethod
    def count_users(cls, active_only: bool = True) -> int:
        """
        Conta total de usuários
        
        Args:
            active_only (bool): Se deve contar apenas usuários ativos
            
        Returns:
            int: Número de usuários
        """
        try:
            query = {'is_active': True} if active_only else {}
            return cls._get_collection().count_documents(query)
            
        except Exception as e:
            print(f"❌ Erro ao contar usuários: {e}")
            return 0
    
    # ===== MÉTODOS DE ATUALIZAÇÃO =====
    
    def update_password(self, new_password_hash: str) -> bool:
        """
        Atualiza senha do usuário
        
        Args:
            new_password_hash (str): Novo hash da senha
            
        Returns:
            bool: True se atualizada com sucesso
        """
        try:
            self.password_hash = new_password_hash
            self.updated_at = datetime.utcnow()
            self.save()
            
            print(f"✅ Senha atualizada para: {self.username}")
            return True
            
        except Exception as e:
            print(f"❌ Erro ao atualizar senha: {e}")
            return False
    
    def update_last_login(self) -> None:
        """Atualiza timestamp do último login"""
        try:
            self.last_login_at = datetime.utcnow()
            self.collection.update_one(
                {'uid': self.uid},
                {'$set': {'last_login_at': self.last_login_at}}
            )
        except Exception as e:
            print(f"⚠️ Erro ao atualizar último login: {e}")
    
    def update_profile(self, **kwargs) -> bool:
        """
        Atualiza campos do perfil do usuário
        
        Args:
            **kwargs: Campos a atualizar
            
        Returns:
            bool: True se atualizado com sucesso
        """
        try:
            # Campos permitidos para atualização
            allowed_fields = {
                'display_name', 'email', 'phone_number', 
                'pix_key', 'pix_qr_code_url'
            }
            
            # Atualizar apenas campos permitidos
            for field, value in kwargs.items():
                if field in allowed_fields and hasattr(self, field):
                    setattr(self, field, value)
            
            self.updated_at = datetime.utcnow()
            self.save()
            
            return True
            
        except Exception as e:
            print(f"❌ Erro ao atualizar perfil: {e}")
            return False
    
    # ===== MÉTODOS DE CONVERSÃO =====
    
    def to_dict(self, include_sensitive: bool = False) -> Dict[str, Any]:
        """
        Converte usuário para dicionário
        
        Args:
            include_sensitive (bool): Se deve incluir dados sensíveis
            
        Returns:
            dict: Dados do usuário
        """
        data = {
            'uid': self.uid,
            'username': self.username,
            'role': self.role,
            'display_name': self.display_name,
            'email': self.email,
            'phone_number': self.phone_number,
            'pix_key': self.pix_key,
            'pix_qr_code_url': self.pix_qr_code_url,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'last_login_at': self.last_login_at.isoformat() if self.last_login_at else None
        }
        
        # Incluir dados sensíveis apenas se solicitado
        if include_sensitive:
            data['password_hash'] = self.password_hash
        
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> Optional['User']:
        """
        Cria usuário a partir de dicionário
        
        Args:
            data (dict): Dados do usuário
            
        Returns:
            User ou None: Usuário criado
        """
        try:
            # Campos obrigatórios
            required_fields = ['uid', 'username']
            for field in required_fields:
                if not data.get(field):
                    print(f"❌ Campo obrigatório ausente: {field}")
                    return None
            
            # Converter datas de string para datetime se necessário
            def parse_date(date_str):
                if not date_str:
                    return None
                if isinstance(date_str, datetime):
                    return date_str
                try:
                    return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                except:
                    return datetime.utcnow()
            
            return cls(
                uid=data['uid'],
                username=data['username'],
                password_hash=data.get('password_hash', ''),
                role=data.get('role', 'client'),
                display_name=data.get('display_name'),
                email=data.get('email'),
                phone_number=data.get('phone_number'),
                pix_key=data.get('pix_key'),
                pix_qr_code_url=data.get('pix_qr_code_url'),
                is_active=data.get('is_active', True),
                created_at=parse_date(data.get('created_at')),
                updated_at=parse_date(data.get('updated_at')),
                last_login_at=parse_date(data.get('last_login_at'))
            )
            
        except Exception as e:
            print(f"❌ Erro ao criar usuário a partir de dict: {e}")
            return None
    
    # ===== MÉTODOS UTILITÁRIOS =====
    
    @classmethod
    def _get_collection(cls):
        """Obtém referência à coleção de usuários"""
        return mongodb.db.users
    
    @property
    def is_admin(self) -> bool:
        """Verifica se usuário é admin ou owner"""
        return self.role in ['admin', 'owner']
    
    @property
    def is_owner(self) -> bool:
        """Verifica se usuário é owner"""
        return self.role == 'owner'
    
    @property
    def is_client(self) -> bool:
        """Verifica se usuário é cliente"""
        return self.role == 'client'
    
    def has_permission(self, required_role: str) -> bool:
        """
        Verifica se usuário tem permissão para determinada role
        
        Args:
            required_role (str): Role necessária
            
        Returns:
            bool: True se tem permissão
        """
        role_hierarchy = {
            'client': 0,
            'admin': 1,
            'owner': 2
        }
        
        user_level = role_hierarchy.get(self.role, 0)
        required_level = role_hierarchy.get(required_role, 0)
        
        return user_level >= required_level
    
    def __str__(self) -> str:
        return f"User(uid={self.uid}, username={self.username}, role={self.role})"
    
    def __repr__(self) -> str:
        return self.__str__()
    
    def __eq__(self, other) -> bool:
        if not isinstance(other, User):
            return False
        return self.uid == other.uid
    
    def __hash__(self) -> int:
        return hash(self.uid)

