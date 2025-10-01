from datetime import datetime
from bson import ObjectId
from database.mongodb import mongodb
from models.category_mongo import Category

class Transaction:
    def __init__(self, description=None, amount=None, type=None, context=None, 
                 category_id=None, date=None, due_date=None, status='pending', 
                 is_recurring=False, recurring_day=None, user_id=None, order_id=None, _id=None):
        self._id = _id
        self.user_id = user_id
        self.description = description
        self.amount = amount
        self.type = type
        self.context = context
        self.category_id = category_id
        self.date = date
        self.due_date = due_date
        self.status = status
        self.is_recurring = is_recurring
        self.recurring_day = recurring_day
        self.order_id = order_id # Novo campo para vincular a um pedido
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def save(self):
        """Salva a transação no MongoDB"""
        collection = mongodb.db.transactions
        
        data = {
            'user_id': self.user_id,
            'description': self.description,
            'amount': self.amount,
            'type': self.type,
            'context': self.context,
            'category_id': self.category_id,
            'date': self.date,
            'due_date': self.due_date,
            'status': self.status,
            'is_recurring': self.is_recurring,
            'recurring_day': self.recurring_day,
            'order_id': self.order_id, # Incluído order_id nos dados salvos
            'created_at': self.created_at,
            'updated_at': self.updated_at
        }
        
        if self._id:
            data['updated_at'] = datetime.utcnow()
            collection.update_one({'_id': ObjectId(self._id)}, {'$set': data})
        else:
            result = collection.insert_one(data)
            self._id = result.inserted_id
        
        return self
    
    @classmethod
    def find_all(cls, filters=None, limit=None):
        """Busca todas as transações com filtros e limite opcionais"""
        collection = mongodb.db.transactions
        query = filters or {}
        
        # Constrói a busca com ordenação
        cursor = collection.find(query).sort('date', -1)
        
        # Aplica o limite SE ele for fornecido
        if limit is not None:
            cursor = cursor.limit(limit)
            
        transactions = []
        for doc in cursor:
            transaction = cls(
                _id=str(doc['_id']),
                user_id=doc.get('user_id'),
                description=doc.get('description'),
                amount=doc.get('amount'),
                type=doc.get('type'),
                context=doc.get('context'),
                category_id=doc.get('category_id'),
                date=doc.get('date'),
                due_date=doc.get('due_date'),
                status=doc.get('status'),
                is_recurring=doc.get('is_recurring'),
                recurring_day=doc.get('recurring_day'),
                order_id=doc.get('order_id') # Carregado order_id do banco
            )
            transaction.created_at = doc.get('created_at')
            transaction.updated_at = doc.get('updated_at')
            transactions.append(transaction)
        
        return transactions
    
    @classmethod
    def find_by_id(cls, transaction_id):
        """Busca uma transação por ID"""
        collection = mongodb.db.transactions
        doc = collection.find_one({'_id': ObjectId(transaction_id)}) 
        
        if doc:
            transaction = cls(
                _id=str(doc['_id']),
                user_id=doc.get('user_id'),
                description=doc.get('description'),
                amount=doc.get('amount'),
                type=doc.get('type'),
                context=doc.get('context'),
                category_id=doc.get('category_id'),
                date=doc.get('date'),
                due_date=doc.get('due_date'),
                status=doc.get('status'),
                is_recurring=doc.get('is_recurring'),
                recurring_day=doc.get('recurring_day'),
                order_id=doc.get('order_id') # Carregado order_id do banco
            )
            transaction.created_at = doc.get('created_at')
            transaction.updated_at = doc.get('updated_at')
            return transaction
        
        return None
    
    def delete(self):
        """Remove a transação do MongoDB"""
        if self._id:
            collection = mongodb.db.transactions
            collection.delete_one({'_id': ObjectId(self._id)})
    
    def to_dict(self):
        """Converte a transação para dicionário"""
        category_name = None
        if self.category_id:
            category = Category.find_by_id(self.category_id)
            if category:
                category_name = category.name
        
        def safe_date_format(date_obj):
            if date_obj is None:
                return None
            if isinstance(date_obj, datetime):
                return date_obj.isoformat()
            elif hasattr(date_obj, 'isoformat'):
                return date_obj.isoformat()
            else:
                return str(date_obj)
        
        return {
            'id': str(self._id) if self._id else None,
            'user_id': self.user_id,
            'description': self.description,
            'amount': self.amount,
            'type': self.type,
            'context': self.context,
            'category_id': self.category_id,
            'category_name': category_name,
            'date': safe_date_format(self.date),
            'due_date': safe_date_format(self.due_date),
            'status': self.status,
            'is_recurring': self.is_recurring,
            'recurring_day': self.recurring_day,
            'order_id': self.order_id, # Incluído order_id no dicionário
            'created_at': safe_date_format(self.created_at),
            'updated_at': safe_date_format(self.updated_at)
        }

    @classmethod
    def create_transaction(cls, transaction_data):
        """Método auxiliar para criar transações com validação"""
        try:
            required_fields = ['description', 'amount', 'type', 'context', 'user_id']
            for field in required_fields:
                if field not in transaction_data or transaction_data[field] is None:
                    return {'success': False, 'error': f'Campo obrigatório ausente: {field}'}
            
            transaction_date = transaction_data.get('date')
            if isinstance(transaction_date, str):
                transaction_date = datetime.strptime(transaction_date, '%Y-%m-%d')
            
            due_date = transaction_data.get('due_date')
            if due_date and isinstance(due_date, str):
                due_date = datetime.strptime(due_date, '%Y-%m-%d')
            
            transaction = cls(
                user_id=transaction_data['user_id'],
                description=transaction_data['description'],
                amount=float(transaction_data['amount']),
                type=transaction_data['type'],
                context=transaction_data['context'],
                category_id=transaction_data.get('category_id'),
                date=transaction_date or datetime.utcnow(),
                due_date=due_date,
                status=transaction_data.get('status', 'pending'),
                is_recurring=transaction_data.get('is_recurring', False),
                recurring_day=transaction_data.get('recurring_day'),
                order_id=transaction_data.get('order_id') # Incluído order_id na criação
            )
            
            transaction.save()
            
            return {
                'success': True,
                'transaction_id': str(transaction._id),
                'message': 'Transação criada com sucesso'
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'Erro ao criar transação: {str(e)}'
            }

