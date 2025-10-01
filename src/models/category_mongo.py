# ARQUIVO CORRIGIDO E SEGURO: src/models/category_mongo.py
# MODIFICAÇÃO: Adicionado campo 'id' persistente (como o 'uid' do User) para consistência e correção de bugs.

from datetime import datetime
from bson import ObjectId
from database.mongodb import mongodb
import uuid # <<< ADICIONADO: Para gerar IDs únicos

class Category:
    """
    Representa o modelo de uma Categoria, que pode ser usada tanto para
    transações financeiras ('business') quanto para agrupar produtos ('product').
    """
    def __init__(self, data=None):
        """
        Inicializa uma instância de Categoria a partir de um dicionário de dados.
        """
        if data is None:
            data = {}

        # --- INÍCIO DA MODIFICAÇÃO ---
        # Padroniza o uso de um campo 'id' único, similar ao 'uid' do modelo User.
        # Se 'id' ou '_id' existem no dicionário de entrada, usa-os. Senão, gera um novo UUID.
        # Isso garante que toda categoria, nova ou carregada, tenha um 'id' consistente.
        self.id = str(data.get('id') or data.get('_id') or uuid.uuid4())
        
        # O _id interno será gerenciado pelo método save() e find_by_id()
        self._id = ObjectId(self.id) if ObjectId.is_valid(self.id) else None
        # --- FIM DA MODIFICAÇÃO ---
        
        self.user_id = data.get('user_id')
        self.name = data.get('name')
        
        self.context = data.get('context', 'business')
        self.type = data.get('type')
        
        self.color = data.get('color', '#3B82F6')
        self.icon = data.get('icon', 'folder')
        self.emoji = data.get('emoji', '📁')
        
        # Se as datas não forem fornecidas, elas são definidas para o momento da criação do objeto.
        self.created_at = data.get('created_at', datetime.utcnow())
        self.updated_at = data.get('updated_at', datetime.utcnow())

    def save(self):
        """Salva uma nova categoria ou atualiza uma existente no MongoDB."""
        collection = mongodb.db.categories
        
        # --- INÍCIO DA MODIFICAÇÃO ---
        # Garante que o 'id' (string) seja o campo principal de busca e persistência.
        data_to_save = self.to_dict() # Obtém todos os campos, incluindo o 'id'
        
        # Converte as datas de string ISO para objetos datetime, se necessário.
        if isinstance(data_to_save.get('created_at'), str):
            data_to_save['created_at'] = datetime.fromisoformat(data_to_save['created_at'].replace('Z', '+00:00'))
        
        # Atualiza a data de modificação sempre que salvar.
        self.updated_at = datetime.utcnow()
        data_to_save['updated_at'] = self.updated_at

        # Usa o 'id' (string) como critério de busca.
        # O operador $set garante que todos os campos sejam atualizados.
        # O upsert=True cria o documento se ele não existir com base no 'id'.
        collection.update_one(
            {'id': self.id},
            {'$set': data_to_save},
            upsert=True
        )
        
        # Garante que o _id interno esteja sincronizado após a operação
        doc = collection.find_one({'id': self.id})
        if doc:
            self._id = doc.get('_id')

        return self
        # --- FIM DA MODIFICAÇÃO ---

    @classmethod
    def find_all(cls, filters=None):
        """Busca todas as categorias que correspondem a um filtro opcional."""
        collection = mongodb.db.categories
        query = filters or {}
        
        return [cls(doc) for doc in collection.find(query).sort('name', 1)]

    @classmethod
    def find_by_id(cls, category_id):
        """
        Busca uma categoria específica pelo seu ID de forma robusta.
        Tenta buscar por 'id' (string) e por '_id' (ObjectId).
        """
        collection = mongodb.db.categories
        
        if not category_id:
            return None

        # 1. Tenta buscar pelo campo 'id' (nosso novo padrão)
        doc = collection.find_one({'id': str(category_id)})
        if doc:
            return cls(doc)

        # 2. Se não encontrou e o ID for um ObjectId válido, tenta buscar pelo '_id'
        if ObjectId.is_valid(str(category_id)):
            doc = collection.find_one({'_id': ObjectId(str(category_id))})
            if doc:
                return cls(doc)
        
        return None

    @classmethod
    def find_one_by_name_and_user_id(cls, name, user_id, context=None):
        """Busca uma categoria pelo nome e user_id, opcionalmente por contexto."""
        collection = mongodb.db.categories
        query = {
            'name': name,
            'user_id': user_id
        }
        if context:
            query['context'] = context
        doc = collection.find_one(query)
        return cls(doc) if doc else None

    def delete(self):
        """Remove a categoria do banco de dados usando o 'id'."""
        if self.id:
            collection = mongodb.db.categories
            # Deleta o documento onde o campo 'id' corresponde ao id do objeto.
            collection.delete_one({'id': self.id})
            self.id = None

    def to_dict(self, include_internal_fields=False):
        """
        Converte a instância da Categoria para um dicionário.
        O campo 'id' agora é a fonte da verdade.
        """
        def safe_isoformat(date_obj):
            if isinstance(date_obj, datetime):
                return date_obj.isoformat()
            return str(date_obj) if date_obj is not None else None

        data = {
            'id': self.id, # <<< MODIFICADO: Usa o self.id
            'user_id': self.user_id,
            'name': self.name,
            'context': self.context,
            'type': self.type,
            'color': self.color,
            'icon': self.icon,
            'emoji': self.emoji,
            'created_at': safe_isoformat(self.created_at),
            'updated_at': safe_isoformat(self.updated_at)
        }
        
        if include_internal_fields:
            data['_id'] = self._id
            
        return data

    @classmethod
    def seed_default_categories(cls, user_id, context=None):
        """
        Cria um conjunto de categorias padrão para um usuário, agora com 'id' único.
        """
        collection = mongodb.db.categories
        
        default_categories = [
            {'name': 'Salários', 'context': 'business', 'type': 'expense', 'color': '#DC2626', 'emoji': '💼', 'icon': 'briefcase'},
            {'name': 'Aluguel', 'context': 'business', 'type': 'expense', 'color': '#7C2D12', 'emoji': '🏢', 'icon': 'building'},
            {'name': 'Combustível', 'context': 'business', 'type': 'expense', 'color': '#EA580C', 'emoji': '⛽', 'icon': 'fuel'},
            {'name': 'Impostos', 'context': 'business', 'type': 'expense', 'color': '#B91C1C', 'emoji': '📋', 'icon': 'receipt'},
            {'name': 'Manutenção', 'context': 'business', 'type': 'expense', 'color': '#92400E', 'emoji': '🔧', 'icon': 'wrench'},
            {'name': 'Fornecedores', 'context': 'business', 'type': 'expense', 'color': '#7C3AED', 'emoji': '🛍️', 'icon': 'shopping-cart'},
            {'name': 'Vendas', 'context': 'business', 'type': 'income', 'color': '#059669', 'emoji': '💰', 'icon': 'dollar-sign'},
            {'name': 'Serviços', 'context': 'business', 'type': 'income', 'color': '#0D9488', 'emoji': '🛠️', 'icon': 'wrench'},
            {'name': 'Rodas', 'context': 'product', 'type': None, 'color': '#2563EB', 'emoji': '🚗', 'icon': 'car'},
            {'name': 'Pneus', 'context': 'product', 'type': None, 'color': '#F59E0B', 'emoji': '⚫', 'icon': 'circle'},
            {'name': 'Serviços de Borracharia', 'context': 'product', 'type': None, 'color': '#10B981', 'emoji': '🛠️', 'icon': 'tools'}
        ]
        
        count = 0
        for cat_data in default_categories:
            if context and cat_data['context'] != context:
                continue

            existing = collection.find_one({
                'user_id': user_id,
                'name': cat_data['name'], 
                'context': cat_data['context']
            })
            if not existing:
                # --- INÍCIO DA MODIFICAÇÃO ---
                # Adiciona um ID único ao criar as categorias padrão
                cat_data['id'] = str(uuid.uuid4())
                # --- FIM DA MODIFICAÇÃO ---
                cat_data['user_id'] = user_id
                cat_data['created_at'] = datetime.utcnow()
                cat_data['updated_at'] = datetime.utcnow()
                collection.insert_one(cat_data)
                count += 1
        
        return count
