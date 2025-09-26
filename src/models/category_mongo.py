
from datetime import datetime
from bson import ObjectId
from database.mongodb import mongodb

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

        # O _id é um ObjectId do MongoDB, enquanto 'id' é a sua representação em string.
        self._id = ObjectId(data.get('_id')) if data.get('_id') else None
        self.user_id = data.get('user_id')
        self.name = data.get('name')
        
        # 'context' define o uso da categoria: 'business' para finanças, 'product' para vitrine.
        self.context = data.get('context', 'business')
        
        # 'type' é mais relevante para o contexto 'business' (income/expense).
        self.type = data.get('type')
        
        # Atributos visuais com valores padrão.
        self.color = data.get('color', '#3B82F6')
        self.icon = data.get('icon', 'folder')
        self.emoji = data.get('emoji', '📁')
        
        # Datas de criação e atualização.
        self.created_at = data.get('created_at', datetime.utcnow())
        self.updated_at = data.get('updated_at', datetime.utcnow())

    def save(self):
        """Salva uma nova categoria ou atualiza uma existente no MongoDB."""
        collection = mongodb.db.categories
        
        # Prepara os dados para o banco a partir do estado atual do objeto.
        # Chamamos o to_dict aqui para garantir que os dados estejam formatados corretamente.
        data_to_save = self.to_dict(include_internal_fields=True)
        
        # Converte as datas de string ISO para objetos datetime antes de salvar, se necessário.
        if isinstance(data_to_save.get('created_at'), str):
            data_to_save['created_at'] = datetime.fromisoformat(data_to_save['created_at'].replace('Z', '+00:00'))
        if isinstance(data_to_save.get('updated_at'), str):
            data_to_save['updated_at'] = datetime.fromisoformat(data_to_save['updated_at'].replace('Z', '+00:00'))

        data_to_save.pop('id', None) # Remove a versão string do ID.

        if self._id:
            # Atualiza uma categoria existente, definindo a data de atualização.
            self.updated_at = datetime.utcnow()
            data_to_save.pop('_id', None) # Remove o _id do dicionário para a atualização
            data_to_save['updated_at'] = self.updated_at # Atualiza o campo updated_at
            collection.update_one({'_id': self._id}, {'$set': data_to_save})
        else:
            # Insere uma nova categoria.
            data_to_save.pop('_id', None) # Remove o _id para permitir que o MongoDB gere um novo
            result = collection.insert_one(data_to_save)
            self._id = result.inserted_id
        
        return self

    @classmethod
    def find_all(cls, filters=None):
        """Busca todas as categorias que correspondem a um filtro opcional."""
        collection = mongodb.db.categories
        query = filters or {}
        
        # Retorna uma lista de instâncias da classe Category.
        return [cls(doc) for doc in collection.find(query).sort('name', 1)]

    @classmethod
    def find_by_id(cls, category_id):
        """Busca uma categoria específica pelo seu ID (string ou ObjectId)."""
        collection = mongodb.db.categories
        try:
            # Garante que a busca seja feita com um ObjectId válido.
            doc = collection.find_one({'_id': ObjectId(category_id)})
            return cls(doc) if doc else None
        except Exception:
            # Retorna None se o ID for inválido.
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
        """Remove a categoria do banco de dados."""
        if self._id:
            collection = mongodb.db.categories
            collection.delete_one({'_id': ObjectId(self._id)})
            self._id = None # Invalida o objeto após a exclusão.

    def to_dict(self, include_internal_fields=False):
        """
        Converte a instância da Categoria para um dicionário de forma segura,
        verificando os tipos de dados antes da formatação.
        """
        
        # Função auxiliar para formatar datas de forma segura
        def safe_isoformat(date_obj):
            # Verifica se o objeto é do tipo datetime
            if isinstance(date_obj, datetime):
                return date_obj.isoformat()
            # Se for qualquer outra coisa (string, None, etc.), retorna como está
            # para evitar que o programa quebre.
            return str(date_obj) if date_obj is not None else None

        data = {
            'id': str(self._id),
            'user_id': self.user_id,
            'name': self.name,
            'context': self.context,
            'type': self.type,
            'color': self.color,
            'icon': self.icon,
            'emoji': self.emoji,
            # Usa a função segura para evitar o erro 'isoformat'
            'created_at': safe_isoformat(self.created_at),
            'updated_at': safe_isoformat(self.updated_at)
        }
        
        # Campo usado internamente para operações de banco de dados.
        if include_internal_fields:
            data['_id'] = self._id
            
        return data

    @classmethod
    def seed_default_categories(cls, user_id, context=None):
        """
        Cria um conjunto de categorias padrão para um usuário específico,
        se elas ainda não existirem. Pode filtrar por contexto.
        """
        collection = mongodb.db.categories
        
        default_categories = [
            # Categorias para o contexto 'business' (financeiro)
            {'name': 'Salários', 'context': 'business', 'type': 'expense', 'color': '#DC2626', 'emoji': '💼', 'icon': 'briefcase'},
            {'name': 'Aluguel', 'context': 'business', 'type': 'expense', 'color': '#7C2D12', 'emoji': '🏢', 'icon': 'building'},
            {'name': 'Combustível', 'context': 'business', 'type': 'expense', 'color': '#EA580C', 'emoji': '⛽', 'icon': 'fuel'},
            {'name': 'Impostos', 'context': 'business', 'type': 'expense', 'color': '#B91C1C', 'emoji': '📋', 'icon': 'receipt'},
            {'name': 'Manutenção', 'context': 'business', 'type': 'expense', 'color': '#92400E', 'emoji': '🔧', 'icon': 'wrench'},
            {'name': 'Fornecedores', 'context': 'business', 'type': 'expense', 'color': '#7C3AED', 'emoji': '🛍️', 'icon': 'shopping-cart'},
            {'name': 'Vendas', 'context': 'business', 'type': 'income', 'color': '#059669', 'emoji': '💰', 'icon': 'dollar-sign'},
            {'name': 'Serviços', 'context': 'business', 'type': 'income', 'color': '#0D9488', 'emoji': '🛠️', 'icon': 'wrench'},
            
            # Categoria para o contexto 'product' (vitrine)
            {'name': 'Rodas', 'context': 'product', 'type': None, 'color': '#2563EB', 'emoji': '🚗', 'icon': 'car'},
            {'name': 'Pneus', 'context': 'product', 'type': None, 'color': '#F59E0B', 'emoji': '⚫', 'icon': 'circle'},
            {'name': 'Serviços de Borracharia', 'context': 'product', 'type': None, 'color': '#10B981', 'emoji': '🛠️', 'icon': 'tools'}
        ]
        
        count = 0
        for cat_data in default_categories:
            # Se um contexto específico foi fornecido, filtra as categorias padrão por ele.
            if context and cat_data['context'] != context:
                continue

            existing = collection.find_one({
                'user_id': user_id,
                'name': cat_data['name'], 
                'context': cat_data['context']
            })
            if not existing:
                cat_data['user_id'] = user_id
                cat_data['created_at'] = datetime.utcnow()
                cat_data['updated_at'] = datetime.utcnow()
                collection.insert_one(cat_data)
                count += 1
        
        return count
