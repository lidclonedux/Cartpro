# src/routes/products_mongo.py - VERSÃO FINAL CORRIGIDA E PADRONIZADA

from flask import Blueprint, request, jsonify
from models.product_mongo import Product
from auth import verify_token
from middleware.auth_middleware import is_admin
from models.transaction_mongo import Transaction
from datetime import datetime
import traceback

products_bp = Blueprint("products_mongo", __name__)

# Rota pública para listar produtos (vitrine)
@products_bp.route("/api/products", methods=["GET"])
@verify_token
def get_products(current_user_uid, current_user_data):
    """
    Lista produtos. Rota agora protegida para usuários logados.
    Pode ser filtrada por user_id para mostrar produtos de uma loja específica.
    """
    try:
        print("➡️  [GET /products] Iniciando busca de produtos. Filtros recebidos:", request.args)
        
        filters = {"is_active": True}
        
        category_id = request.args.get("category_id")
        if category_id:
            filters["category_id"] = category_id
            
        user_id = request.args.get("user_id")
        if user_id:
            filters["user_id"] = user_id

        is_service_param = request.args.get("is_service")
        if is_service_param is not None:
            filters["is_service"] = is_service_param.lower() == "true"

        print(f"⚙️  Filtros aplicados ao MongoDB: {filters}")

        products = Product.find_all(filters)
        
        print(f"✅ {len(products)} produtos encontrados no banco de dados.")
        
        product_list = [p.to_dict() for p in products]
        
        print(f"✅ {len(product_list)} produtos serializados com sucesso. Retornando resposta.")
        
        return jsonify(product_list), 200
    except Exception as e:
        print(f"❌ ERRO 500 em GET /products: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": f"Ocorreu um erro ao buscar produtos: {str(e)}"}), 500

# Rota pública para ver um produto específico
@products_bp.route("/api/products/<product_id>", methods=["GET"])
def get_product_by_id(product_id):
    """Busca e retorna um único produto pelo seu ID."""
    try:
        product = Product.find_by_id(product_id)
        if product and product.is_active:
            return jsonify(product.to_dict()), 200
        return jsonify({"error": "Produto não encontrado ou inativo."}), 404
    except Exception as e:
        return jsonify({"error": f"Ocorreu um erro ao buscar o produto: {str(e)}"}), 500

# --- ROTAS PROTEGIDAS (Apenas Administrador/Dono da Loja) ---

@products_bp.route("/api/products", methods=["POST"])
@verify_token
@is_admin
def create_product(current_user_uid, current_user_data):
    """Cria um novo produto. Apenas para usuários administradores."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Requisição sem dados."}), 400

        required_fields = ["name", "price", "category_id"]
        missing = [field for field in required_fields if field not in data]
        if missing:
            return jsonify({"error": f"Campos obrigatórios ausentes: {', '.join(missing)}"}), 400
        
        if not data["name"].strip():
            return jsonify({"error": "O nome do produto não pode ser vazio."}), 400
        if float(data["price"]) < 0:
            return jsonify({"error": "Preço não pode ser negativo."}), 400

        is_service = data.get("is_service", False)
        stock_quantity = 0
        unit_type = "unit"
        conversion_factor = 1

        if not is_service:
            if "stock_quantity" not in data or int(data["stock_quantity"]) < 0:
                return jsonify({"error": "Para produtos físicos, 'stock_quantity' é obrigatório e não pode ser negativo."}), 400
            stock_quantity = int(data["stock_quantity"])
            unit_type = data.get("unit_type", "unit")
            conversion_factor = int(data.get("conversion_factor", 1))
            if unit_type == "set" and conversion_factor == 1:
                conversion_factor = 4

        data["user_id"] = current_user_uid
        data["is_service"] = is_service
        data["stock_quantity"] = stock_quantity
        data["unit_type"] = unit_type
        data["conversion_factor"] = conversion_factor
        
        # O campo 'image_url' já estará presente em 'data' se o upload foi feito no frontend.
        # O construtor do Product já lida com isso.
        product = Product(data)
        product.save()
        
        return jsonify(product.to_dict()), 201
        
    except (ValueError, TypeError) as e:
        return jsonify({"error": f"Erro de tipo de dado: {str(e)}. Verifique 'price' (número) e 'stock_quantity' (inteiro)."}), 400
    except Exception as e:
        return jsonify({"error": f"Ocorreu um erro ao criar o produto: {str(e)}"}), 500

@products_bp.route("/api/products/<product_id>", methods=["PUT"])
@verify_token
@is_admin
def update_product(current_user_uid, current_user_data, product_id):
    """Atualiza um produto existente. Apenas para o dono do produto."""
    try:
        product = Product.find_by_id(product_id)
        if not product:
            return jsonify({"error": "Produto não encontrado."}), 404

        if product.user_id != current_user_uid:
            return jsonify({"error": "Acesso negado. Você não é o dono deste produto."}), 403

        data = request.get_json()
        if not data:
            return jsonify({"error": "Nenhum dado fornecido para atualização."}), 400

        # --- INÍCIO DA CORREÇÃO ---
        product.name = data.get("name", product.name)
        product.description = data.get("description", product.description)
        product.category_id = data.get("category_id", product.category_id)
        product.is_active = data.get("is_active", product.is_active)
        product.is_service = data.get("is_service", product.is_service)
        product.unit_type = data.get("unit_type", product.unit_type)
        product.conversion_factor = data.get("conversion_factor", product.conversion_factor)
        
        # ✅ LINHA CRÍTICA: Garante que a URL da imagem seja atualizada se enviada.
        product.image_url = data.get("image_url", product.image_url)
        
        if "price" in data:
            product.price = float(data["price"])
        
        if not product.is_service and "stock_quantity" in data:
            if int(data["stock_quantity"]) < 0:
                return jsonify({"error": "Estoque não pode ser negativo para produtos físicos."}), 400
            product.stock_quantity = int(data["stock_quantity"])
        # --- FIM DA CORREÇÃO ---

        product.save()
        return jsonify(product.to_dict()), 200
    except (ValueError, TypeError) as e:
        return jsonify({"error": f"Erro de tipo de dado: {str(e)}. Verifique 'price' (número) e 'stock_quantity' (inteiro)."}), 400
    except Exception as e:
        return jsonify({"error": f"Ocorreu um erro ao atualizar o produto: {str(e)}"}), 500

@products_bp.route("/api/products/<product_id>", methods=["DELETE"])
@verify_token
@is_admin
def delete_product(current_user_uid, current_user_data, product_id):
    """Desativa um produto (soft delete). Apenas para o dono do produto."""
    try:
        product = Product.find_by_id(product_id)
        if not product:
            return jsonify({"error": "Produto não encontrado."}), 404

        if product.user_id != current_user_uid:
            return jsonify({"error": "Acesso negado. Você não é o dono deste produto."}), 403

        product.delete()
        
        return jsonify({"message": "Produto desativado com sucesso."}), 200
    except Exception as e:
        return jsonify({"error": f"Ocorreu um erro ao desativar o produto: {str(e)}"}), 500

@products_bp.route("/api/products/stock/add", methods=["POST"])
@verify_token
@is_admin
def add_stock(current_user_uid, current_user_data):
    """Adiciona estoque a um produto existente e gera uma transação de despesa."""
    try:
        data = request.get_json()
        product_id = data.get("product_id")
        quantity = data.get("quantity")
        cost_per_unit = data.get("cost_per_unit")
        supplier = data.get("supplier")
        description = data.get("description")
        transaction_category_id = data.get("transaction_category_id")

        if not all([product_id, quantity, cost_per_unit, supplier, transaction_category_id]):
            return jsonify({"error": "Campos obrigatórios ausentes: product_id, quantity, cost_per_unit, supplier, transaction_category_id."}), 400

        product = Product.find_by_id(product_id)
        if not product:
            return jsonify({"error": "Produto não encontrado."}), 404

        if product.user_id != current_user_uid:
            return jsonify({"error": "Acesso negado. Você não é o dono deste produto."}), 403

        if product.is_service:
            return jsonify({"error": "Não é possível adicionar estoque a um serviço."}), 400

        quantity = int(quantity)
        cost_per_unit = float(cost_per_unit)
        if quantity <= 0 or cost_per_unit <= 0:
            return jsonify({"error": "Quantidade e custo por unidade devem ser maiores que zero."}), 400

        product.stock_quantity += quantity
        product.save()

        total_cost = quantity * cost_per_unit
        transaction_data = {
            "user_id": current_user_uid,
            "amount": total_cost,
            "type": "expense",
            "description": description or f"Compra de {quantity} unidades de {product.name} do fornecedor {supplier}",
            "category_id": transaction_category_id,
            "date": datetime.utcnow().isoformat(),
            "status": "paid"
        }
        transaction = Transaction(transaction_data)
        transaction.save()

        return jsonify({"message": "Estoque adicionado e transação de despesa registrada com sucesso.", "product": product.to_dict()}), 200
    except (ValueError, TypeError) as e:
        return jsonify({"error": f"Erro de tipo de dado: {str(e)}. Verifique 'quantity' (inteiro) e 'cost_per_unit' (número)."}), 400
    except Exception as e:
        return jsonify({"error": f"Ocorreu um erro ao adicionar estoque: {str(e)}"}), 500
