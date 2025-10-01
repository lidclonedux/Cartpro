# src/routes/upload.py - VERSÃO COM LOGS INTELIGENTES E CORREÇÕES

from flask import Blueprint, request, jsonify
from src.services.cloudinary_service import CloudinaryService
from src.models.transaction_mongo import Transaction
from src.models.category_mongo import Category
from datetime import datetime
import json
import traceback

# Importando os guardiões do sistema
from src.auth import verify_token
from src.middleware.auth_middleware import is_admin

upload_bp = Blueprint('upload', __name__)

def ensure_https_url(url):
    """Garante que a URL use HTTPS"""
    if url and isinstance(url, str):
        if url.startswith('http://'):
            url_https = url.replace('http://', 'https://')
            print(f"🔒 URL convertida para HTTPS: {url_https}")
            return url_https
    return url

def log_request_details():
    """Logs inteligentes dos detalhes da requisição"""
    print(f"\n{'='*60}")
    print(f"📡 UPLOAD REQUEST - {datetime.now().strftime('%H:%M:%S')}")
    print(f"{'='*60}")
    print(f"🔍 Headers recebidos:")
    for key, value in request.headers.items():
        # Mascarar tokens/auth para segurança
        if 'authorization' in key.lower():
            print(f"  {key}: {'Bearer ' + value.split(' ')[1][:10] + '...' if len(value.split(' ')) > 1 else 'Invalid'}")
        else:
            print(f"  {key}: {value}")
    
    print(f"🔍 Arquivos na requisição:")
    if request.files:
        for key, file in request.files.items():
            file_size = 0
            try:
                # Não mover o cursor, apenas verificar tamanho
                file.stream.seek(0, 2)  # Vai para o final
                file_size = file.stream.tell()
                file.stream.seek(0)  # Volta para o início
            except:
                pass
            print(f"  {key}: {file.filename} ({file_size} bytes, Content-Type: {file.content_type})")
    else:
        print(f"  ❌ Nenhum arquivo encontrado na requisição")
    
    print(f"🔍 Form data:")
    if request.form:
        for key, value in request.form.items():
            print(f"  {key}: {value}")
    else:
        print(f"  (vazio)")
    print(f"{'='*60}\n")

@upload_bp.route('/api/upload/proof', methods=['POST'])
@verify_token
def upload_payment_proof(current_user_uid, current_user_data):
    """Upload específico para comprovantes de pagamento PIX"""
    log_request_details()
    
    try:
        print(f"🏁 Iniciando upload de comprovante para usuário: {current_user_uid}")
        
        if 'file' not in request.files:
            print(f"❌ ERRO: Campo 'file' não encontrado na requisição")
            return jsonify({'error': 'Nenhum arquivo enviado'}), 400
        
        file = request.files['file']
        if file.filename == '':
            print(f"❌ ERRO: Nome do arquivo vazio")
            return jsonify({'error': 'Nenhum arquivo selecionado'}), 400
        
        print(f"✅ Arquivo recebido: {file.filename}")
        
        # Metadados do comprovante
        order_id = request.form.get('order_id')
        description = f"Comprovante do pedido {order_id} enviado por {current_user_uid}"
        context = request.form.get('context', 'ecommerce')
        proof_type = request.form.get('type', 'pix_proof')
        
        print(f"📋 Metadados: order_id={order_id}, context={context}, type={proof_type}")
        
        # Upload para Cloudinary
        print(f"☁️  Iniciando upload para Cloudinary...")
        upload_result = CloudinaryService.upload_file(
            file,
            folder=f"payment_proofs/{context}",
            resource_type="image"
        )
        
        if not upload_result['success']:
            print(f"❌ ERRO Cloudinary: {upload_result['error']}")
            return jsonify({'error': upload_result['error']}), 500
        
        print(f"✅ Upload Cloudinary bem-sucedido!")
        print(f"   URL: {upload_result['url']}")
        print(f"   Public ID: {upload_result['public_id']}")
        
        # Garantir HTTPS na URL
        secure_url = ensure_https_url(upload_result['url'])
        
        # Salvar informações do comprovante no MongoDB
        from src.database.mongodb import mongodb
        proof_data = {
            'filename': file.filename,
            'original_name': file.filename,
            'cloudinary_url': secure_url,
            'cloudinary_public_id': upload_result['public_id'],
            'file_format': upload_result['format'],
            'file_size': upload_result['bytes'],
            'context': context,
            'description': description,
            'proof_type': proof_type,
            'order_id': order_id,
            'user_id': current_user_uid,
            'uploaded_at': datetime.utcnow()
        }
        
        result = mongodb.db.payment_proofs.insert_one(proof_data)
        proof_data['id'] = str(result.inserted_id)
        
        print(f"💾 Comprovante salvo no MongoDB com ID: {proof_data['id']}")
        print(f"🎉 Upload de comprovante concluído com sucesso!")

        # 🎯 NOVA FUNCIONALIDADE: CRIAR TRANSAÇÃO DE CONTABILIDADE PARA COMPROVANTE
        from src.models.order_mongo import Order
        from src.models.category_mongo import Category

        try:
            order = Order.find_by_id(order_id)
            if not order:
                print(f"❌ ERRO: Pedido com ID {order_id} não encontrado para o comprovante.")
                # Não impede o upload do comprovante, mas loga o erro
            
            # Buscar a categoria padrão para pagamentos (ou criar se não existir)
            payment_category = Category.find_one({"name": "Pagamentos Recebidos"})
            if not payment_category:
                payment_category = Category({"name": "Pagamentos Recebidos", "type": "income", "description": "Pagamentos recebidos de clientes", "is_default": True})
                payment_category.save()
                print("✅ Categoria 'Pagamentos Recebidos' criada.")
            
            transaction_data = {
                "user_id": current_user_uid,
                "amount": order.total_amount if order else 0.0, # Usar valor do pedido se encontrado
                "type": "income",  # Comprovante de pagamento é uma receita
                "description": f"Comprovante de pagamento PIX para o pedido #{order_id}",
                "category_id": payment_category._id, # Associar à categoria de pagamentos
                "payment_method": "pix", # Assumindo PIX para comprovante
                "order_id": order_id, # Referência ao pedido
                "proof_url": secure_url, # Referência ao comprovante
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            transaction = Transaction(transaction_data)
            transaction.save()
            print(f"✅ Transação de contabilidade criada para comprovante! ID: {transaction._id}")
        except Exception as transaction_error:
            print(f"🚨 ERRO CRÍTICO ao criar transação de contabilidade para comprovante do pedido {order_id}: {transaction_error}")
            traceback.print_exc()

        return jsonify({
            'success': True,
            'message': 'Comprovante enviado com sucesso',
            'url': secure_url,
            'file_url': secure_url,
            'proof': {
                'id': proof_data['id'],
                'filename': proof_data['filename'],
                'url': secure_url,
                'type': proof_data['proof_type'],
                'size': proof_data['file_size'],
                'uploaded_at': proof_data['uploaded_at'].isoformat()
            }
        }), 201
        
    except Exception as e:
        print(f"\n❌ ERRO CRÍTICO EM /upload/proof:")
        print(f"   Tipo: {type(e).__name__}")
        print(f"   Mensagem: {str(e)}")
        print(f"   Traceback:")
        traceback.print_exc()
        return jsonify({'error': f'Erro interno no upload: {str(e)}'}), 500

# =========================================================================
# ============ ROTA PRINCIPAL CORRIGIDA: UPLOAD IMAGEM PRODUTO ===========
# =========================================================================

@upload_bp.route('/api/upload/product-image', methods=['POST'])
@verify_token
@is_admin
def upload_product_image(current_user_uid, current_user_data):
    """
    Upload de imagem de produto com logs inteligentes e tratamento robusto
    """
    log_request_details()
    
    try:
        print(f"🏁 Iniciando upload de imagem de produto para usuário: {current_user_uid}")
        
        # Validação básica do arquivo
        if 'file' not in request.files:
            print(f"❌ ERRO: Campo 'file' não encontrado")
            print(f"   Campos disponíveis: {list(request.files.keys())}")
            return jsonify({'error': 'Nenhum arquivo enviado'}), 400
        
        file = request.files['file']
        if file.filename == '':
            print(f"❌ ERRO: Nome do arquivo vazio")
            return jsonify({'error': 'Nenhum arquivo selecionado'}), 400
        
        print(f"✅ Arquivo recebido: {file.filename}")
        
        # Validação de tamanho
        file.stream.seek(0, 2)  # Vai para o final do arquivo
        file_size = file.stream.tell()
        file.stream.seek(0)  # Volta para o início
        
        print(f"📏 Tamanho do arquivo: {file_size} bytes ({file_size / (1024*1024):.2f} MB)")
        
        if file_size > 10 * 1024 * 1024:  # 10MB
            print(f"❌ ERRO: Arquivo muito grande")
            return jsonify({'error': 'Arquivo muito grande. Máximo: 10MB'}), 400
        
        if file_size == 0:
            print(f"❌ ERRO: Arquivo vazio")
            return jsonify({'error': 'Arquivo vazio ou corrompido'}), 400
        
        # Validação de tipo de arquivo
        allowed_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
        if file.content_type not in allowed_types:
            print(f"❌ ERRO: Tipo de arquivo não permitido: {file.content_type}")
            return jsonify({'error': f'Tipo de arquivo não suportado: {file.content_type}'}), 400
        
        print(f"✅ Validações de arquivo aprovadas")
        
        # Obter metadados
        product_name = request.form.get('product_name', 'produto_sem_nome')
        context = request.form.get('context', 'ecommerce')
        upload_type = request.form.get('type', 'product_image')
        
        print(f"📋 Metadados:")
        print(f"   Nome do produto: {product_name}")
        print(f"   Contexto: {context}")
        print(f"   Tipo: {upload_type}")
        
        # Configurar pasta do Cloudinary com base no tipo de upload
        if upload_type == 'qr_code':
            folder = f"qr_codes/{current_user_uid}"
        else:
            folder = f"produtos/{current_user_uid}"
        print(f"📁 Pasta de destino: {folder}")

        # Upload para Cloudinary
        print(f"☁️  Iniciando upload para Cloudinary...")
        upload_result = CloudinaryService.upload_file(
            file,
            folder=folder,
            resource_type="image"
        )
        
        if not upload_result['success']:
            print(f"❌ ERRO Cloudinary: {upload_result['error']}")
            return jsonify({'error': f"Falha no Cloudinary: {upload_result['error']}"}), 500
        
        print(f"✅ Upload Cloudinary bem-sucedido!")
        print(f"   URL original: {upload_result['url']}")
        print(f"   Public ID: {upload_result['public_id']}")
        print(f"   Formato: {upload_result['format']}")
        print(f"   Tamanho final: {upload_result['bytes']} bytes")
        
        # Garantir HTTPS
        secure_url = ensure_https_url(upload_result['url'])
        
        # Log de sucesso
        print(f"🎉 UPLOAD DE IMAGEM DE PRODUTO CONCLUÍDO!")
        print(f"   ✅ Produto: {product_name}")
        print(f"   ✅ Usuário: {current_user_uid}")
        print(f"   ✅ URL final: {secure_url}")
        print(f"   ✅ Public ID: {upload_result['public_id']}")
        
        # Resposta padronizada
        response_data = {
            'success': True,
            'message': 'Imagem do produto enviada com sucesso',
            'url': secure_url,
            'public_id': upload_result['public_id'],
            'format': upload_result['format'],
            'size': upload_result['bytes'],
            'folder': folder,
            'product_name': product_name,
            'upload_time': datetime.utcnow().isoformat()
        }
        
        print(f"📤 Enviando resposta de sucesso")
        return jsonify(response_data), 201
        
    except Exception as e:
        print(f"\n❌ ERRO CRÍTICO EM /upload/product-image:")
        print(f"   Tipo: {type(e).__name__}")
        print(f"   Mensagem: {str(e)}")
        print(f"   Usuário: {current_user_uid}")
        print(f"   Traceback completo:")
        traceback.print_exc()
        return jsonify({'error': f'Erro interno no upload: {str(e)}'}), 500

# =========================================================================
# ====================== OUTRAS ROTAS DE UPLOAD =========================
# =========================================================================

@upload_bp.route("/upload/document", methods=["POST"])
@verify_token
def upload_document():
    """Upload de documentos com logs inteligentes"""
    log_request_details()
    
    try:
        print(f"🏁 Iniciando upload de documento")
        
        if 'file' not in request.files:
            print(f"❌ ERRO: Nenhum arquivo na requisição")
            return jsonify({'error': 'Nenhum arquivo enviado'}), 400
        
        file = request.files['file']
        if file.filename == '':
            print(f"❌ ERRO: Nome do arquivo vazio")
            return jsonify({'error': 'Nenhum arquivo selecionado'}), 400
        
        print(f"✅ Documento recebido: {file.filename}")
        
        # Metadados
        context = request.form.get('context', 'business')
        description = request.form.get('description', '')
        document_type = request.form.get('type', 'extract')
        
        print(f"📋 Contexto: {context}, Tipo: {document_type}")
        
        # Upload para Cloudinary
        print(f"☁️  Enviando documento para Cloudinary...")
        upload_result = CloudinaryService.upload_file(
            file,
            folder=f"documents/{context}/{document_type}",
            resource_type="auto"
        )
        
        if not upload_result['success']:
            print(f"❌ ERRO no upload: {upload_result['error']}")
            return jsonify({'error': upload_result['error']}), 500
        
        print(f"✅ Documento enviado com sucesso!")
        
        # Garantir HTTPS
        secure_url = ensure_https_url(upload_result['url'])
        
        # Salvar no MongoDB
        from src.database.mongodb import mongodb
        document_data = {
            'filename': file.filename,
            'original_name': file.filename,
            'cloudinary_url': secure_url,
            'cloudinary_public_id': upload_result['public_id'],
            'file_format': upload_result['format'],
            'file_size': upload_result['bytes'],
            'context': context,
            'description': description,
            'document_type': document_type,
            'uploaded_at': datetime.utcnow(),
            'processed': False
        }
        
        result = mongodb.db.documents.insert_one(document_data)
        document_data['id'] = str(result.inserted_id)
        
        print(f"💾 Documento salvo no MongoDB: {document_data['id']}")
        
        return jsonify({
            'success': True,
            'message': 'Documento enviado com sucesso',
            'url': secure_url,
            'document': {
                'id': document_data['id'],
                'filename': document_data['filename'],
                'url': secure_url,
                'type': document_data['document_type'],
                'size': document_data['file_size'],
                'uploaded_at': document_data['uploaded_at'].isoformat()
            }
        }), 201
        
    except Exception as e:
        print(f"❌ ERRO no upload de documento: {str(e)}")
        traceback.print_exc()
        return jsonify({'error': f'Erro no upload: {str(e)}'}), 500

# Rotas de listagem com logs otimizados
@upload_bp.route('/api/documents', methods=['GET'])
def get_documents():
    """Lista documentos com logs"""
    try:
        print(f"📋 Listando documentos - Filtros: {dict(request.args)}")
        
        context = request.args.get('context')
        document_type = request.args.get('type')
        
        from src.database.mongodb import mongodb
        query = {}
        if context:
            query['context'] = context
        if document_type:
            query['document_type'] = document_type
        
        documents = []
        doc_count = 0
        for doc in mongodb.db.documents.find(query).sort('uploaded_at', -1):
            doc_count += 1
            secure_url = ensure_https_url(doc.get('cloudinary_url'))
            
            documents.append({
                'id': str(doc['_id']),
                'filename': doc.get('filename'),
                'url': secure_url,
                'type': doc.get('document_type'),
                'context': doc.get('context'),
                'description': doc.get('description'),
                'size': doc.get('file_size'),
                'uploaded_at': doc.get('uploaded_at').isoformat() if doc.get('uploaded_at') else None,
                'processed': doc.get('processed', False)
            })
        
        print(f"✅ {doc_count} documentos encontrados e listados")
        return jsonify(documents)
        
    except Exception as e:
        print(f"❌ ERRO ao listar documentos: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Método de diagnóstico
@upload_bp.route('/api/upload/diagnostics', methods=['GET'])
def upload_diagnostics():
    """Diagnósticos do sistema de upload"""
    try:
        diagnostics = {
            'timestamp': datetime.utcnow().isoformat(),
            'cloudinary_configured': False,
            'mongodb_connected': False,
            'available_endpoints': [
                '/upload/product-image',
                '/upload/proof',
                '/upload/document'
            ]
        }
        
        # Testar Cloudinary
        try:
            import cloudinary
            diagnostics['cloudinary_configured'] = True
            diagnostics['cloudinary_version'] = getattr(cloudinary, '__version__', 'N/A')
        except Exception as e:
            diagnostics['cloudinary_error'] = str(e)
        
        # Testar MongoDB
        try:
            from src.database.mongodb import mongodb
            mongodb.client.admin.command('ping')
            diagnostics['mongodb_connected'] = True
        except Exception as e:
            diagnostics['mongodb_error'] = str(e)
        
        # Status geral
        diagnostics['status'] = 'OK' if (diagnostics['cloudinary_configured'] and diagnostics['mongodb_connected']) else 'ISSUES'
        
        print(f"🔍 Diagnósticos executados - Status: {diagnostics['status']}")
        return jsonify(diagnostics)
        
    except Exception as e:
        print(f"❌ ERRO nos diagnósticos: {str(e)}")
        return jsonify({'error': str(e)}), 500
