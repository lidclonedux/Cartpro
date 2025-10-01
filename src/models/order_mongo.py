# ARQUIVO CORRIGIDO: src/models/order_mongo.py - COM CAMPO PAYMENT_METHOD E CORREÇÃO HTTPS

import logging
from datetime import datetime
from bson import ObjectId
from src.database.mongodb import mongodb # Corrigido o import para ser relativo ao projeto

# Configuração de logging específico para pedidos
log = logging.getLogger(__name__)

def ensure_https_url(url):
    """Garante que a URL use HTTPS - CORREÇÃO PARA MODO RELEASE"""
    if url and isinstance(url, str):
        if url.startswith('http://'):
            return url.replace('http://', 'https://')
    return url

class Order:
    """
    Representa o modelo de um Pedido (Ordem de Compra) e encapsula a lógica
    de interação com a coleção 'orders' no MongoDB.
    """
    def __init__(self, data=None):
        """
        Inicializa uma instância de Pedido a partir de um dicionário de dados.
        """
        if data is None:
            data = {}

        # Esta linha está correta, pois lida com a leitura do banco.
        # O problema estava no método save().
        self._id = ObjectId(data.get('_id')) if data.get('_id') else None
        
        # ID do dono da loja (admin) para agrupar os pedidos por loja.
        self.user_id = data.get('user_id')
        
        # Lista de itens do pedido. Formato esperado para cada item:
        # {'product_id': str, 'name': str, 'quantity': int, 'price': float}
        self.items = data.get('items', [])
        
        # Informações do cliente que realizou a compra.
        self.customer_info = data.get('customer_info', {})
        
        # Método de entrega: 'pickup' (retirada) ou 'delivery' (entrega).
        self.delivery_method = data.get('delivery_method')
        self.delivery_address = data.get('delivery_address')
        
        # URL do comprovante de pagamento, se aplicável.
        # ✅ CORREÇÃO: Garante HTTPS ao carregar do banco
        raw_proof_url = data.get('payment_proof_url')
        self.payment_proof_url = ensure_https_url(raw_proof_url) if raw_proof_url else None
        
        # Novo campo: Método de pagamento escolhido pelo cliente
        # Valores possíveis: 'pix' (padrão) ou 'other' (combinar pagamento)
        self.payment_method = data.get('payment_method', 'pix')
        
        # Status do pedido: 'pending', 'confirmed', 'delivered', 'cancelled'.
        self.status = data.get('status', 'pending')

        # Conversão segura do valor total.
        try:
            self.total_amount = float(data.get('total_amount', 0.0))
        except (ValueError, TypeError):
            log.warning(f"⚠️ Valor total inválido para pedido: {data.get('total_amount')}. Usando 0.0")
            self.total_amount = 0.0

        # Datas de criação e atualização.
        self.created_at = data.get('created_at', datetime.utcnow())
        self.updated_at = data.get('updated_at', datetime.utcnow())

    def save(self):
        """Salva um novo pedido ou atualiza um existente no MongoDB."""
        try:
            collection = mongodb.db.orders
            
            data_to_save = self.to_dict(include_internal_fields=True)
            data_to_save.pop('id', None) # Remove o campo 'id' (string) que é apenas para a API.

            # ✅ CORREÇÃO: Garante HTTPS antes de salvar
            if data_to_save.get('payment_proof_url'):
                data_to_save['payment_proof_url'] = ensure_https_url(data_to_save['payment_proof_url'])

            if self._id:
                # --- LÓGICA DE ATUALIZAÇÃO ---
                log.info(f"🔄 Atualizando pedido existente: {self._id}")
                self.updated_at = datetime.utcnow()
                data_to_save['updated_at'] = self.updated_at
                
                # Boa prática: não incluir a chave _id no operador $set.
                data_to_save.pop('_id', None)
                
                collection.update_one({'_id': self._id}, {'$set': data_to_save})
                log.info(f"✅ Pedido {self._id} atualizado com sucesso")
            else:
                # --- LÓGICA DE INSERÇÃO (NOVO PEDIDO) ---
                log.info(f"➕ Criando novo pedido para user_id: {self.user_id}")
                
                # Correção principal: Remove a chave '_id' antes de inserir.
                # Isso impede que {'_id': None} seja enviado ao banco, resolvendo o erro.
                data_to_save.pop('_id', None)
                
                result = collection.insert_one(data_to_save)
                self._id = result.inserted_id
                log.info(f"✅ Novo pedido criado com ID: {self._id}")
                
        except Exception as e:
            log.error(f"❌ Erro ao salvar pedido: {str(e)}")
            log.error(f"🔍 Dados do pedido: user_id={self.user_id}, total={self.total_amount}")
            raise e
            
        return self

    @classmethod
    def find_all(cls, filters=None):
        """
        Busca todos os pedidos que correspondem a um filtro.
        Ex: filters={'user_id': 'xyz'} ou filters={'customer_info.email': 'a@b.com'}
        """
        try:
            collection = mongodb.db.orders
            query = filters or {}
            log.debug(f"🔍 Buscando pedidos com filtro: {query}")
            
            # Ordena por data de criação, dos mais recentes para os mais antigos.
            pedidos = [cls(doc) for doc in collection.find(query).sort('created_at', -1)]
            log.info(f"📊 Encontrados {len(pedidos)} pedidos")
            return pedidos
            
        except Exception as e:
            log.error(f"❌ Erro ao buscar pedidos: {str(e)}")
            log.error(f"🔍 Filtros aplicados: {filters}")
            raise e

    @classmethod
    def find_by_id(cls, order_id):
        """Busca um pedido específico pelo seu ID."""
        try:
            collection = mongodb.db.orders
            log.debug(f"🔍 Buscando pedido por ID: {order_id}")
            
            doc = collection.find_one({'_id': ObjectId(order_id)})
            if doc:
                log.info(f"✅ Pedido {order_id} encontrado")
                return cls(doc)
            else:
                log.warning(f"⚠️ Pedido {order_id} não encontrado")
                return None
                
        except Exception as e:
            log.error(f"❌ Erro ao buscar pedido {order_id}: {str(e)}")
            return None

    def delete(self):
        """Remove permanentemente o pedido do banco de dados."""
        try:
            if self._id:
                log.info(f"🗑️ Removendo pedido: {self._id}")
                mongodb.db.orders.delete_one({'_id': self._id})
                log.info(f"✅ Pedido {self._id} removido com sucesso")
                self._id = None
            else:
                log.warning("⚠️ Tentativa de deletar pedido sem ID")
                
        except Exception as e:
            log.error(f"❌ Erro ao deletar pedido {self._id}: {str(e)}")
            raise e

    def safe_isoformat(self, date_obj):
        """
        Converte datetime para string ISO de forma segura.
        Resolve o erro 'str' object has no attribute 'isoformat'
        """
        if date_obj is None:
            return None
        elif isinstance(date_obj, str):
            return date_obj  # Já é string
        elif hasattr(date_obj, 'isoformat'):
            return date_obj.isoformat()
        else:
            log.warning(f"⚠️ Tipo de data não reconhecido: {type(date_obj)} - {date_obj}")
            return str(date_obj)

    def to_dict(self, include_internal_fields=False):
        """
        Converte a instância do Pedido para um dicionário, ideal para respostas de API.
        """
        try:
            data = {
                'id': str(self._id),
                'user_id': self.user_id,
                'items': self.items,
                'total_amount': self.total_amount,
                'customer_info': self.customer_info,
                'delivery_method': self.delivery_method,
                'delivery_address': self.delivery_address,
                'payment_proof_url': ensure_https_url(self.payment_proof_url),  # ✅ CORREÇÃO PRINCIPAL
                'payment_method': self.payment_method,
                'status': self.status,
                'created_at': self.safe_isoformat(self.created_at),
                'updated_at': self.safe_isoformat(self.updated_at)
            }
            
            if include_internal_fields:
                data['_id'] = self._id
                
            return data
            
        except Exception as e:
            log.error(f"❌ Erro ao converter pedido para dict: {str(e)}")
            log.error(f"🔍 Pedido ID: {self._id}, created_at: {type(self.created_at)}, updated_at: {type(self.updated_at)}")
            raise e

    def __repr__(self):
        """Retorna uma representação em string do objeto, útil para depuração."""
        return f"<Order id='{self._id}' status='{self.status}' payment_method='{self.payment_method}' total={self.total_amount}>"
