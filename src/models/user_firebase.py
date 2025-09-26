# src/models/user_firebase.py

from database.mongodb import mongodb
from datetime import datetime
from bson import ObjectId

class UserFirebase:
    def __init__(self):
        self.collection = mongodb.db.users_firebase
    
    def create_user(self, user_data):
        """Criar novo usuário no MongoDB"""
        try:
            # Verificar se usuário já existe
            existing_user = self.collection.find_one({'firebase_uid': user_data['firebase_uid']})
            if existing_user:
                return {'success': False, 'error': 'Usuário já existe'}
            
            # Inserir novo usuário
            result = self.collection.insert_one(user_data)
            
            return {
                'success': True,
                'user_id': str(result.inserted_id),
                'firebase_uid': user_data['firebase_uid']
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_user_by_firebase_uid(self, firebase_uid):
        """Buscar usuário por Firebase UID"""
        try:
            user = self.collection.find_one({'firebase_uid': firebase_uid})
            if user:
                user['_id'] = str(user['_id'])
                return {'success': True, 'user': user}
            else:
                return {'success': False, 'error': 'Usuário não encontrado'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_user_by_email(self, email):
        """Buscar usuário por email"""
        try:
            user = self.collection.find_one({'email': email})
            if user:
                user['_id'] = str(user['_id'])
                return {'success': True, 'user': user}
            else:
                return {'success': False, 'error': 'Usuário não encontrado'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def update_user(self, firebase_uid, update_data):
        """Atualizar dados do usuário"""
        try:
            result = self.collection.update_one(
                {'firebase_uid': firebase_uid},
                {'$set': update_data}
            )
            
            if result.matched_count > 0:
                return {'success': True, 'modified_count': result.modified_count}
            else:
                return {'success': False, 'error': 'Usuário não encontrado'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def update_last_login(self, firebase_uid):
        """Atualizar último login do usuário"""
        try:
            result = self.collection.update_one(
                {'firebase_uid': firebase_uid},
                {'$set': {'last_login': datetime.utcnow()}}
            )
            
            return {'success': True, 'modified_count': result.modified_count}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def delete_user(self, firebase_uid):
        """Deletar usuário"""
        try:
            result = self.collection.delete_one({'firebase_uid': firebase_uid})
            
            if result.deleted_count > 0:
                return {'success': True, 'deleted_count': result.deleted_count}
            else:
                return {'success': False, 'error': 'Usuário não encontrado'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_all_users(self, limit=50, skip=0):
        """Listar todos os usuários (com paginação)"""
        try:
            users = list(self.collection.find().skip(skip).limit(limit))
            
            # Converter ObjectId para string
            for user in users:
                user['_id'] = str(user['_id'])
            
            return {'success': True, 'users': users, 'count': len(users)}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def set_user_active_status(self, firebase_uid, is_active):
        """Ativar/desativar usuário"""
        try:
            result = self.collection.update_one(
                {'firebase_uid': firebase_uid},
                {'$set': {'is_active': is_active, 'updated_at': datetime.utcnow()}}
            )
            
            if result.matched_count > 0:
                return {'success': True, 'modified_count': result.modified_count}
            else:
                return {'success': False, 'error': 'Usuário não encontrado'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
