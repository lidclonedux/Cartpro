# ARQUIVO CORRIGIDO: src/routes/orders_mongo.py - COM LOGS DE DEBUG PARA MODO RELEASE

from flask import Blueprint, request, jsonify
from datetime import datetime
import logging
import traceback

# --- Modelos ---
from src.models.order_mongo import Order
from src.models.product_mongo import Product
from src.models.transaction_mongo import Transaction
from src.models.user_mongo import User
from src.models.category_mongo import Category

# --- Autenticação e Middlewares ---
from src.auth import verify_token
from src.middleware.auth_middleware import is_admin

# --- Conexão com o Banco ---
from src.database.mongodb import mongodb

# --- Configuração dos Logs Inteligentes ---
log = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - [ORDERS] - %(message)s')

orders_bp = Blueprint("orders", __name__)

# --- ROTA PÚBLICA (para o cliente criar o pedido) ---
@orders_bp.route("/api/orders", methods=["POST"])
def create_order():
    """Cria um novo pedido a partir da vitrine."""
    log.info("➡️  [POST /orders] Recebida nova requisição para criar pedido.")
    
    try:
        data = request.get_json()
        if not data:
            log.warning("⚠️  Requisição recebida sem corpo JSON.")
            return jsonify({"error": "Requisição sem corpo JSON"}), 400
            
        log.info(f"📦  Dados recebidos: {data}")

        # --- Validação dos Dados ---
        required_fields = ["user_id", "items", "total_amount", "customer_info"]
        if not all(k in data for k in required_fields):
            log.warning(f"❌  Campos obrigatórios faltando. Recebido: {list(data.keys())}")
            return jsonify({"error": "Campos obrigatórios faltando"}), 400

        customer_info = data.get("customer_info", {})
        is_delivery = customer_info.get("is_delivery", False)

        # ✅ CORREÇÃO: Validação melhorada do client_uid
        client_uid = customer_info.get("client_uid")
        if not client_uid:
            log.warning("❌  client_uid não encontrado no customer_info.")
            return jsonify({"error": "Identificação do cliente é obrigatória"}), 400

        # ✅ CORREÇÃO PRINCIPAL: Indentação correta do bloco if
        if is_delivery:
            delivery_address_data = data.get("delivery_address")
            if (not delivery_address_data or 
                not isinstance(delivery_address_data, dict) or 
                not delivery_address_data.get("street") or 
                not delivery_address_data.get("city")):
                
                log.warning("❌  Pedido de entrega sem o objeto 'delivery_address' ou campos 'street'/'city' faltando.")
                return jsonify({"error": "Endereço e cidade são obrigatórios para entrega"}), 400

        # 🎯 NOVA VALIDAÇÃO: Método de pagamento
        payment_method = data.get("payment_method", "pix")
        valid_payment_methods = ["pix", "other"]
        if payment_method not in valid_payment_methods:
            log.warning(f"❌  Método de pagamento inválido: {payment_method}")
            return jsonify({"error": f"Método de pagamento deve ser um de: {valid_payment_methods}"}), 400
        
        log.info(f"💳  Método de pagamento escolhido: {payment_method}")
        log.info("✅  Validação inicial dos campos passou.")

        # --- 🎯 CONTROLE DE ESTOQUE COM ARMAZENAMENTO DE DADOS ---
        log.info("🔍  Iniciando verificação e reserva de estoque para os itens do pedido.")
        products_to_update = []  # Lista para armazenar produtos que precisam ser atualizados
        
        for item in data["items"]:
            product_id = item.get("product_id")
            if not product_id:
                log.error("🚨  Item no pedido sem 'product_id'.")
                return jsonify({"error": "Item inválido no pedido: product_id faltando."}), 400

            # ✅ CORREÇÃO: Validação adicional para product_id None
            if product_id == "None" or product_id == "null":
                log.error(f"🚨  Product ID inválido recebido: '{product_id}'")
                return jsonify({"error": "Produto inválido: ID não pode ser None ou null."}), 400

            product = Product.find_by_id(product_id)
            if not product:
                log.warning(f"❌  Produto com ID '{product_id}' não encontrado no banco de dados.")
                return jsonify({"error": f"Produto com ID {product_id} não encontrado."}), 404
            
            log.info(f"✅  Produto encontrado: {product.name} (ID: {product_id})")
            
            # 🎯 NOVO: CONTROLE DE ESTOQUE INTELIGENTE
            if not product.is_service:
                requested_quantity = item.get("quantity", 0)
                if product.unit_type == "set":
                    requested_quantity *= product.conversion_factor

                if product.stock_quantity < requested_quantity:
                    log.warning(f"❌  Estoque insuficiente para '{product.name}' (ID: {product_id}). Solicitado: {requested_quantity}, Disponível: {product.stock_quantity}")
                    return jsonify({"error": f"Estoque insuficiente para {product.name}."}), 400
                
                # 🎯 PREPARAR DADOS PARA ATUALIZAÇÃO DE ESTOQUE
                new_stock = product.stock_quantity - requested_quantity
                products_to_update.append({
                    'product': product,
                    'new_stock': new_stock,
                    'quantity_sold': requested_quantity,
                    'item_data': item
                })
                
                log.info(f"📊  Produto '{product.name}': Estoque atual: {product.stock_quantity}, Vendido: {requested_quantity}, Novo estoque: {new_stock}")
        
        log.info("✅  Verificação de estoque concluída com sucesso.")

        # ✅ CORREÇÃO: Criação Segura do Pedido com construtor correto
        log.info("🏗️  Construindo o objeto do pedido com dados validados.")
        
        new_order_data = {
            "user_id": data["user_id"],
            "items": data["items"],
            "total_amount": data["total_amount"],
            "customer_info": data["customer_info"],
            "payment_method": payment_method,  # 🎯 NOVO CAMPO
            "status": "pending",
            "delivery_method": "delivery" if is_delivery else "pickup",
            "delivery_address": data.get("delivery_address"),
            "payment_proof_url": data.get("payment_proof_url"),  # Caso já tenha comprovante
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        log.info(f"📋  Dados do pedido estruturados: {new_order_data}")

        # ✅ CORREÇÃO PRINCIPAL: Usar o construtor correto da classe Order
        order = Order(new_order_data)  # Passa o dicionário inteiro, não argumentos nomeados
        order.save()

        log.info(f"✅  Pedido criado com sucesso! ID do Pedido: {order._id}")

        # 🎯 NOVA FUNCIONALIDADE: ATUALIZAR ESTOQUE APÓS PEDIDO CRIADO
        log.info("🔄  Iniciando atualização de estoque dos produtos vendidos...")
        stock_updates_successful = 0
        
        for update_data in products_to_update:
            try:
                product = update_data['product']
                new_stock = update_data['new_stock']
                quantity_sold = update_data['quantity_sold']
                
                # Atualizar o estoque do produto
                product.stock_quantity = new_stock
                product.updated_at = datetime.utcnow()
                product.save()
                
                stock_updates_successful += 1
                log.info(f"📉  Estoque atualizado para '{product.name}': {product.stock_quantity + quantity_sold} → {product.stock_quantity}")
                
            except Exception as stock_error:
                log.error(f"🚨  ERRO CRÍTICO ao atualizar estoque do produto {product.name}: {stock_error}")
                # Em caso de erro crítico, você pode decidir cancelar o pedido ou continuar
                # Por segurança, vamos continuar mas registrar o erro
        
        log.info(f"✅  Controle de estoque concluído: {stock_updates_successful}/{len(products_to_update)} produtos atualizados")
        
        # 🎯 LOG FINAL COM RESUMO COMPLETO
        log.info(f"🎉  PEDIDO FINALIZADO COM SUCESSO!")
        log.info(f"📋  ID do Pedido: {order._id}")
        log.info(f"👤  Cliente: {customer_info.get('name')} (UID: {client_uid})")
        log.info(f"💰  Valor total: R$ {data['total_amount']}")
        log.info(f"💳  Método de pagamento: {payment_method}")
        log.info(f"📦  Itens: {len(data['items'])} produtos")
        log.info(f"📉  Estoque atualizado: {stock_updates_successful} produtos")

        # 🎯 NOVA FUNCIONALIDADE: CRIAR TRANSAÇÃO DE CONTABILIDADE
        log.info("💰  Iniciando criação de transação de contabilidade...")
        try:
            # Buscar a categoria padrão para vendas (ou criar se não existir)
            sales_category = Category.find_one({"name": "Vendas"})
            if not sales_category:
                sales_category = Category({"name": "Vendas", "type": "income", "description": "Receita de vendas de produtos", "is_default": True})
                sales_category.save()
                log.info("✅  Categoria 'Vendas' criada.")
            
            transaction_data = {
                "user_id": data["user_id"],
                "amount": data["total_amount"],
                "type": "income",  # Vendas são receitas
                "description": f"Venda de produtos - Pedido #{order._id}",
                "category_id": sales_category._id, # Associar à categoria de vendas
                "payment_method": payment_method,
                "order_id": str(order._id), # Referência ao pedido
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            transaction = Transaction(transaction_data)
            transaction.save()
            log.info(f"✅  Transação de contabilidade criada com sucesso! ID: {transaction._id}")
        except Exception as transaction_error:
            log.error(f"🚨  ERRO CRÍTICO ao criar transação de contabilidade para o pedido {order._id}: {transaction_error}")
            # Decidir se o erro na transação deve impedir a criação do pedido
            # Por enquanto, vamos logar e continuar, mas isso pode ser ajustado

        # 🎯 LOG FINAL COM RESUMO COMPLETO
        log.info(f"🎉  PEDIDO FINALIZADO COM SUCESSO!")
        log.info(f"📋  ID do Pedido: {order._id}")
        log.info(f"👤  Cliente: {customer_info.get('name')} (UID: {client_uid})")
        log.info(f"💰  Valor total: R$ {data['total_amount']}")
        log.info(f"💳  Método de pagamento: {payment_method}")
        log.info(f"📦  Itens: {len(data['items'])} produtos")
        log.info(f"📉  Estoque atualizado: {stock_updates_successful} produtos")
            
        return jsonify(order.to_dict()), 201
        
    except Exception as e:
        log.error(f"🚨  Erro interno ao criar pedido: {e}")
        return jsonify({"error": f"Erro interno ao criar pedido: {e}"}), 500


# --- ROTA PROTEGIDA (para o admin ver todos os pedidos) ---
@orders_bp.route("/api/orders", methods=["GET"])
@verify_token
@is_admin
def get_all_orders(current_user_uid, current_user):
    """Retorna todos os pedidos para o administrador."""
    log.info(f"➡️  [GET /orders] Admin {current_user_uid} solicitando todos os pedidos.")
    
    try:
        # Busca todos os pedidos da loja do admin atual
        orders = Order.find_all({"user_id": current_user_uid})
        log.info(f"📊  Encontrados {len(orders)} pedidos para o admin {current_user_uid}")
        
        return jsonify([order.to_dict() for order in orders]), 200
        
    except Exception as e:
        log.error(f"🚨  Erro ao buscar pedidos: {e}")
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


# 🚨 ROTA COM LOGS DE DEBUG PARA DIAGNÓSTICO DO MODO RELEASE
@orders_bp.route("/api/orders/user", methods=["GET"])
@verify_token
def get_current_user_orders(current_user_uid, current_user):
    """Retorna os pedidos do usuário logado (cliente) - COM DEBUG INTENSIVO PARA MODO RELEASE."""
    
    # 🚨 LOGS CRÍTICOS DE DEBUG
    log.info("=" * 80)
    log.info("🚨 [DEBUG RELEASE] INICIANDO get_current_user_orders")
    log.info(f"🔍 current_user_uid: '{current_user_uid}' (tipo: {type(current_user_uid)})")
    log.info(f"🔍 current_user keys: {list(current_user.keys()) if isinstance(current_user, dict) else 'N/A'}")
    log.info(f"🔍 current_user role: {current_user.get('role', 'N/A') if isinstance(current_user, dict) else 'N/A'}")
    log.info(f"🔍 Request headers Authorization: {request.headers.get('Authorization', 'N/A')[:50]}...")
    log.info(f"🔍 Request method: {request.method}")
    log.info(f"🔍 Request path: {request.path}")
    log.info("=" * 80)
    
    try:
        # TESTE 1: Verificar conexão com MongoDB
        log.info("🔍 [TESTE 1] Testando conexão MongoDB...")
        try:
            test_collection = mongodb.db.orders
            total_orders_in_db = test_collection.count_documents({})
            log.info(f"✅ [TESTE 1] MongoDB conectado. Total de pedidos no banco: {total_orders_in_db}")
        except Exception as mongo_error:
            log.error(f"❌ [TESTE 1] ERRO MongoDB: {mongo_error}")
            return jsonify({"error": "Erro de conexão com banco de dados", "details": str(mongo_error)}), 500
        
        # TESTE 2: Montar query e fazer busca
        query = {"customer_info.client_uid": current_user_uid}
        log.info(f"🔍 [TESTE 2] Query MongoDB: {query}")
        
        try:
            log.info("🔍 [TESTE 2] Executando Order.find_all()...")
            orders = Order.find_all(query)
            log.info(f"✅ [TESTE 2] Order.find_all() executado. Resultado: {len(orders)} pedidos")
        except Exception as find_error:
            log.error(f"❌ [TESTE 2] ERRO ao executar find_all: {find_error}")
            log.error(f"❌ [TESTE 2] Stacktrace: {traceback.format_exc()}")
            return jsonify({"error": "Erro ao buscar pedidos", "details": str(find_error)}), 500
        
        # TESTE 3: Análise dos pedidos encontrados
        log.info("🔍 [TESTE 3] Analisando pedidos encontrados...")
        if len(orders) == 0:
            # Se não encontrou pedidos, vamos debugar o porquê
            log.info("🔍 [TESTE 3] Nenhum pedido encontrado. Investigando...")
            
            # Buscar TODOS os pedidos para ver o que tem no banco
            try:
                all_orders = Order.find_all({})
                log.info(f"🔍 [TESTE 3] Total de pedidos existentes no banco: {len(all_orders)}")
                
                # Mostrar os client_uid dos primeiros 5 pedidos para comparação
                for i, order in enumerate(all_orders[:5]):
                    client_uid_in_order = order.customer_info.get("client_uid", "SEM_CLIENT_UID")
                    log.info(f"🔍 [TESTE 3] Pedido {i+1}: client_uid = '{client_uid_in_order}' | status = {order.status}")
                
                # Verificar se existe algum pedido com client_uid parecido
                similar_orders = []
                for order in all_orders:
                    order_client_uid = order.customer_info.get("client_uid", "")
                    if order_client_uid and current_user_uid in order_client_uid or order_client_uid in current_user_uid:
                        similar_orders.append(order)
                
                if similar_orders:
                    log.info(f"🔍 [TESTE 3] Encontrados {len(similar_orders)} pedidos com client_uid similar")
                    for order in similar_orders[:3]:
                        log.info(f"🔍 [TESTE 3] Similar: '{order.customer_info.get('client_uid')}' vs '{current_user_uid}'")
                else:
                    log.info("🔍 [TESTE 3] Nenhum pedido com client_uid similar encontrado")
                    
            except Exception as debug_error:
                log.error(f"❌ [TESTE 3] Erro no debug: {debug_error}")
        
        # TESTE 4: Converter pedidos para dict
        log.info("🔍 [TESTE 4] Convertendo pedidos para dict...")
        try:
            orders_data = []
            for i, order in enumerate(orders):
                log.info(f"🔍 [TESTE 4] Convertendo pedido {i+1}/{len(orders)}: ID={order._id}")
                order_dict = order.to_dict()
                orders_data.append(order_dict)
            
            log.info(f"✅ [TESTE 4] {len(orders_data)} pedidos convertidos com sucesso")
        except Exception as convert_error:
            log.error(f"❌ [TESTE 4] ERRO na conversão: {convert_error}")
            log.error(f"❌ [TESTE 4] Stacktrace: {traceback.format_exc()}")
            return jsonify({"error": "Erro ao processar pedidos", "details": str(convert_error)}), 500
        
        # TESTE 5: Ordenar por data
        log.info("🔍 [TESTE 5] Ordenando pedidos por data...")
        try:
            orders_data.sort(key=lambda x: x.get('created_at', ''), reverse=True)
            log.info(f"✅ [TESTE 5] Pedidos ordenados com sucesso")
        except Exception as sort_error:
            log.error(f"❌ [TESTE 5] ERRO na ordenação: {sort_error}")
            # Mesmo se der erro na ordenação, vamos continuar
        
        # TESTE 6: Preparar resposta
        log.info("🔍 [TESTE 6] Preparando resposta JSON...")
        try:
            response_data = jsonify(orders_data)
            log.info(f"✅ [TESTE 6] Resposta JSON preparada. Tamanho: {len(orders_data)} pedidos")
        except Exception as json_error:
            log.error(f"❌ [TESTE 6] ERRO ao criar JSON: {json_error}")
            return jsonify({"error": "Erro ao gerar resposta JSON", "details": str(json_error)}), 500
        
        # LOG FINAL
        log.info("=" * 80)
        log.info(f"🎉 [DEBUG RELEASE] SUCESSO! Retornando {len(orders_data)} pedidos")
        log.info("=" * 80)
        
        return response_data, 200
        
    except Exception as e:
        log.error("=" * 80)
        log.error(f"💥 [DEBUG RELEASE] ERRO CRÍTICO GERAL: {e}")
        log.error(f"💥 [DEBUG RELEASE] Stacktrace completo:")
        log.error(traceback.format_exc())
        log.error("=" * 80)
        return jsonify({"error": f"Erro crítico no servidor: {str(e)}"}), 500


# ✅ CORREÇÃO: Rota alternativa para buscar pedidos por client_uid específico
@orders_bp.route("/api/orders/user/<user_uid>", methods=["GET"])
@verify_token
def get_user_orders_by_uid(current_user_uid, current_user, user_uid):
    """Retorna os pedidos de um cliente específico."""
    log.info(f"➡️  [GET /orders/user/{user_uid}] Buscando pedidos do cliente específico.")
    
    try:
        # Verificação de permissão: admin pode ver qualquer cliente, cliente só pode ver os próprios
        if current_user.get("role") != "admin" and current_user_uid != user_uid:
            log.warning(f"🚫  Usuário {current_user_uid} tentou acessar pedidos de {user_uid} sem permissão.")
            return jsonify({"error": "Acesso negado"}), 403
        
        # ✅ CORREÇÃO: Buscar por client_uid em vez de email
        orders = Order.find_all({"customer_info.client_uid": user_uid})
        log.info(f"📊  Encontrados {len(orders)} pedidos para o cliente {user_uid}")
        
        return jsonify([order.to_dict() for order in orders]), 200
        
    except Exception as e:
        log.error(f"🚨  Erro ao buscar pedidos do usuário: {e}")
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


# --- ROTA PROTEGIDA (para buscar um pedido específico) ---
@orders_bp.route("/api/orders/<order_id>", methods=["GET"])
@verify_token
def get_order_by_id(current_user_uid, current_user, order_id):
    """Retorna um pedido específico pelo ID."""
    log.info(f"➡️  [GET /orders/{order_id}] Buscando pedido específico.")
    
    try:
        order = Order.find_by_id(order_id)
        if not order:
            log.warning(f"❌  Pedido {order_id} não encontrado.")
            return jsonify({"error": "Pedido não encontrado"}), 404
            
        # Verifica se o usuário tem permissão para ver este pedido
        # Admin pode ver todos, cliente só pode ver os próprios
        if (current_user.get("role") != "admin" and 
            order.customer_info.get("client_uid") != current_user_uid):
            log.warning(f"🚫  Usuário {current_user_uid} tentou acessar pedido {order_id} sem permissão.")
            return jsonify({"error": "Acesso negado"}), 403
            
        log.info(f"✅  Pedido {order_id} encontrado e autorizado.")
        return jsonify(order.to_dict()), 200
        
    except Exception as e:
        log.error(f"🚨  Erro ao buscar pedido: {e}")
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


# --- ROTA PROTEGIDA (para atualizar status do pedido - apenas admin) ---
@orders_bp.route("/api/orders/<order_id>/status", methods=["PUT"])
@verify_token
@is_admin
def update_order_status(current_user_uid, current_user, order_id):
    """Atualiza o status de um pedido."""
    log.info(f"➡️  [PUT /orders/{order_id}/status] Admin atualizando status do pedido.")
    
    try:
        data = request.get_json()
        new_status = data.get("status")
        admin_notes = data.get("admin_notes", "")
        
        if not new_status:
            log.warning("❌  Status não fornecido na requisição.")
            return jsonify({"error": "Status é obrigatório"}), 400
            
        valid_statuses = ["pending", "confirmed", "shipped", "delivered", "cancelled"]
        if new_status not in valid_statuses:
            log.warning(f"❌  Status inválido: {new_status}")
            return jsonify({"error": f"Status deve ser um de: {valid_statuses}"}), 400
            
        order = Order.find_by_id(order_id)
        if not order:
            log.warning(f"❌  Pedido {order_id} não encontrado.")
            return jsonify({"error": "Pedido não encontrado"}), 404
            
        # Verifica se o pedido pertence à loja do admin
        if order.user_id != current_user_uid:
            log.warning(f"🚫  Admin {current_user_uid} tentou atualizar pedido {order_id} de outra loja.")
            return jsonify({"error": "Acesso negado"}), 403
            
        old_status = order.status
        order.status = new_status
        order.updated_at = datetime.utcnow()
        
        # Adiciona notas do admin se fornecidas
        if admin_notes:
            order.admin_notes = admin_notes
            
        order.save()
        
        log.info(f"✅  Status do pedido {order_id} atualizado de '{old_status}' para '{new_status}'")
        log.info(f"💳  Método de pagamento do pedido: {order.payment_method}")
        if admin_notes:
            log.info(f"📝  Notas do admin adicionadas: {admin_notes}")
            
        return jsonify(order.to_dict()), 200
        
    except Exception as e:
        log.error(f"🚨  Erro ao atualizar status do pedido: {e}")
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


# --- ROTA PROTEGIDA (para deletar pedido - apenas admin) ---
@orders_bp.route("/api/orders/<order_id>", methods=["DELETE"])
@verify_token
@is_admin
def delete_order(current_user_uid, current_user, order_id):
    """Deleta um pedido."""
    log.info(f"➡️  [DELETE /orders/{order_id}] Admin deletando pedido.")
    
    try:
        order = Order.find_by_id(order_id)
        if not order:
            log.warning(f"❌  Pedido {order_id} não encontrado.")
            return jsonify({"error": "Pedido não encontrado"}), 404
            
        # Verifica se o pedido pertence à loja do admin
        if order.user_id != current_user_uid:
            log.warning(f"🚫  Admin {current_user_uid} tentou deletar pedido {order_id} de outra loja.")
            return jsonify({"error": "Acesso negado"}), 403
            
        order.delete()
        log.info(f"🗑️  Pedido {order_id} deletado com sucesso.")
        
        return jsonify({"message": "Pedido deletado com sucesso"}), 200
        
    except Exception as e:
        log.error(f"🚨  Erro ao deletar pedido: {e}")
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


# ✅ ROTA EXISTENTE: Buscar informações de pagamento da loja (Endpoint Público)
@orders_bp.route("/api/store/<store_owner_id>/payment-info", methods=["GET"])
def get_store_payment_info(store_owner_id):
    """Retorna as informações de pagamento da loja para o cliente."""
    log.info(f"➡️  [GET /store/{store_owner_id}/payment-info] Buscando dados de pagamento da loja.")
    
    try:
        # Busca o usuário (dono da loja) pelo seu UID
        store_owner = User.find_by_uid(store_owner_id)
        if not store_owner:
            log.warning(f"❌  Dono da loja com UID '{store_owner_id}' não encontrado.")
            return jsonify({"error": "Loja não encontrada"}), 404
            
        # Monta o dicionário com as informações de pagamento
        payment_info = {
            "success": True,
            "store_name": store_owner.display_name or "Loja",
            "phone_number": store_owner.phone_number,
            "pix_key": store_owner.pix_key,
            "pix_qr_code_url": store_owner.pix_qr_code_url
        }
        
        log.info(f"✅  Informações de pagamento da loja {store_owner_id} retornadas com sucesso.")
        return jsonify(payment_info), 200
        
    except Exception as e:
        log.error(f"🚨  Erro ao buscar informações de pagamento: {e}")
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


# --- Validação adicionada automaticamente (fix_release.sh) ---
@orders_bp.before_request
def validate_order_request():
    from flask import request, jsonify
    if request.method == "POST" and request.path.endswith("/orders"):
        data = request.get_json(silent=True) or {}
        if data.get("delivery_method") == "delivery":
            addr = data.get("delivery_address")
            if not addr or not isinstance(addr, dict) or not addr.get("street"):
                return jsonify({
                    "error": "delivery_address obrigatório quando delivery",
                    "expected_fields": ["street", "number", "city"]
                }), 400
