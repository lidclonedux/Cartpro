from datetime import datetime
from bson import ObjectId
from database.mongodb import mongodb
import traceback # Adicionado para logs de erro detalhados

# Função auxiliar para converter datas de forma segura
def parse_date(date_value):
    if isinstance(date_value, datetime):
        return date_value
    if isinstance(date_value, str):
        try:
            return datetime.fromisoformat(date_value.replace('Z', '+00:00'))
        except (ValueError, TypeError):
            # Log se a conversão da string falhar
            print(f"⚠️ AVISO: Falha ao converter a string de data '{date_value}' para datetime.")
            return None
    return None

class Product:
    """
    Representa o modelo de um Produto e encapsula toda a lógica de interação
    com a coleção 'products' no MongoDB.
    """
    def __init__(self, data=None):
        """
        Inicializa uma instância de Produto a partir de um dicionário de dados.
        """
        if data is None:
            data = {}

        self._id = ObjectId(data.get("_id")) if data.get("_id") else None
        self.user_id = data.get("user_id")
        self.name = data.get("name")
        self.description = data.get("description")
        self.category_id = data.get("category_id")
        self.image_url = data.get("image_url")
        self.is_active = data.get("is_active", True)
        self.is_service = data.get("is_service", False)
        self.unit_type = data.get("unit_type", "unit")
        self.conversion_factor = data.get("conversion_factor", 1)

        try:
            self.price = float(data.get("price", 0.0))
        except (ValueError, TypeError):
            self.price = 0.0
        
        try:
            self.stock_quantity = int(data.get("stock_quantity", 0))
        except (ValueError, TypeError):
            self.stock_quantity = 0

        # <<< CORREÇÃO APLICADA COM LOGS >>>
        # Garante que as datas sejam sempre objetos datetime
        self.created_at = parse_date(data.get("created_at"))
        if not self.created_at:
            # Se a data não pôde ser parseada ou não existia, cria uma nova
            self.created_at = datetime.utcnow()
            if data.get("created_at"): # Loga apenas se havia um valor inválido
                 print(f"ℹ️ INFO: 'created_at' inválido, usando data atual. Valor recebido: {data.get('created_at')}")

        self.updated_at = parse_date(data.get("updated_at")) or datetime.utcnow()

    # --- Propriedades Computadas ---
    
    @property
    def is_in_stock(self):
        return not self.is_service and self.stock_quantity > 0

    @property
    def is_low_stock(self, threshold=5):
        return not self.is_service and 0 < self.stock_quantity <= threshold

    @property
    def formatted_price(self):
        return f"R$ {self.price:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")

    # --- Métodos de Interação com o Banco de Dados ---

    def save(self):
        """Salva um novo produto ou atualiza um existente no MongoDB."""
        collection = mongodb.db.products
        
        data_to_save = self.to_dict(include_internal_fields=False, include_properties=False)
        data_to_save.pop("id", None)

        try:
            if self._id:
                # ATUALIZAÇÃO
                self.updated_at = datetime.utcnow()
                data_to_save["updated_at"] = self.updated_at
                data_to_save.pop("user_id", None)
                data_to_save.pop("created_at", None)
                
                print(f"🔄 Atualizando produto ID: {self._id}")
                collection.update_one({"_id": self._id}, {"$set": data_to_save})
            else:
                # CRIAÇÃO
                data_to_save.pop("_id", None)
                
                print(f"➕ Criando novo produto com nome: {self.name}")
                result = collection.insert_one(data_to_save)
                self._id = result.inserted_id
                print(f"✅ Produto criado com sucesso. Novo ID: {self._id}")
                
            return self
        except Exception as e:
            print(f"❌ ERRO no método Product.save() para o produto '{self.name}': {e}")
            print(traceback.format_exc())
            # Re-lança a exceção para que a rota possa tratá-la
            raise

    @classmethod
    def find_all(cls, filters=None):
        """Busca todos os produtos que correspondem a um filtro."""
        collection = mongodb.db.products
        query = filters or {}
        return [cls(doc) for doc in collection.find(query).sort("name", 1)]

    @classmethod
    def find_by_id(cls, product_id):
        """Busca um produto específico pelo seu ID."""
        collection = mongodb.db.products
        try:
            doc = collection.find_one({"_id": ObjectId(product_id)})
            return cls(doc) if doc else None
        except Exception as e:
            print(f"⚠️ AVISO: Erro ao buscar produto por ID '{product_id}': {e}")
            return None

    def delete(self, hard_delete=False):
        """Deleta um produto. Por padrão, faz um 'soft delete'."""
        if not self._id:
            return

        if hard_delete:
            print(f"🗑️ Deletando permanentemente o produto ID: {self._id}")
            mongodb.db.products.delete_one({"_id": self._id})
            self._id = None
        else:
            print(f"➖ Desativando (soft delete) o produto ID: {self._id}")
            self.is_active = False
            self.save()

    # --- Métodos de Serialização e Representação ---

    def to_dict(self, include_internal_fields=False, include_properties=True):
        """Converte a instância do Produto para um dicionário."""
        data = {
            "id": str(self._id),
            "user_id": self.user_id,
            "name": self.name,
            "description": self.description,
            "price": self.price,
            "stock_quantity": self.stock_quantity,
            "category_id": self.category_id,
            "image_url": self.image_url,
            "is_active": self.is_active,
            "is_service": self.is_service,
            "unit_type": self.unit_type,
            "conversion_factor": self.conversion_factor,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
        
        if include_properties:
            data["is_in_stock"] = self.is_in_stock
            data["is_low_stock"] = self.is_low_stock
            data["formatted_price"] = self.formatted_price

        if include_internal_fields:
            data["_id"] = self._id
            
        return data

    def __repr__(self):
        """Retorna uma representação em string do objeto."""
        return f"<Product id='{self._id}' name='{self.name}' stock={self.stock_quantity}>"
