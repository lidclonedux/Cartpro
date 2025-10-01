# ARQUIVO COMPLETO: src/routes/document_processing.py (100% HÍBRIDO SEM PANDAS LOCAL)

from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
import os
import tempfile
import traceback
from datetime import datetime, date

# Imports ajustados para sua estrutura
from auth import verify_token
# CORREÇÃO: Só importa o HybridProcessor
from src.services.hybrid_processor import HybridProcessor
from models.transaction_mongo import Transaction
from models.category_mongo import Category

document_processing_bp = Blueprint('document_processing', __name__)

ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg', 'csv', 'xlsx', 'xls'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@document_processing_bp.route('/api/documents/process', methods=['POST'])
@verify_token
def process_document(current_user_uid, current_user_data):
    """Processar documento e extrair transações com categorização dinâmica"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'Nenhum arquivo enviado'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'Nenhum arquivo selecionado'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Tipo de arquivo não suportado'}), 400
        
        context = request.form.get('context', 'business')
        auto_save = request.form.get('auto_save', 'false').lower() == 'true'
        filename = secure_filename(file.filename)
        file_extension = filename.rsplit('.', 1)[1].lower()

        with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_extension}') as temp_file:
            file.save(temp_file.name)
            temp_file_path = temp_file.name

        try:
            # ===== CORREÇÃO: SÓ USA HYBRID PROCESSOR =====
            processor = HybridProcessor()
            result = processor.process_document(temp_file_path, file_extension, context)
            
            if not result or not result.get('success', False):
                return jsonify({'success': False, 'error': result.get('error', 'Erro no processamento do documento')}), 500

            # ===== CORREÇÃO: CATEGORIZAÇÃO TAMBÉM VIA HYBRID =====
            valid_transactions = result.get('transactions', [])
            processed_transactions = []
            categories_created = 0

            for transaction in valid_transactions:
                try:
                    description = transaction.get('description', '')
                    
                    # CORREÇÃO: Pede sugestão de categoria via HybridProcessor
                    category_result = processor.suggest_category(description, context)
                    suggested_category_name = category_result.get('category', 'outros')
                    
                    # Verifica se categoria já existe
                    existing_category = Category.find_all({
                        'user_id': current_user_uid, 
                        'context': context, 
                        'name': suggested_category_name
                    })
                    
                    category_id = None
                    if existing_category and len(existing_category) > 0:
                        category_id = str(existing_category[0]._id)
                    else:
                        # CORREÇÃO: Pede dados da categoria via HybridProcessor
                        category_data = processor.get_category_data(suggested_category_name)
                        
                        new_category = Category(
                            name=suggested_category_name,
                            context=context,
                            type='expense',
                            color=category_data.get('color', '#6366f1'),
                            icon=category_data.get('icon', 'shopping-cart'),
                            emoji=category_data.get('emoji', '🛒'),
                            user_id=current_user_uid
                        )
                        new_category.save()
                        category_id = str(new_category._id)
                        categories_created += 1

                    processed_transaction = transaction.copy()
                    processed_transaction.update({
                        'user_id': current_user_uid,
                        'context': context,
                        'category_id': category_id,
                        'category_name': suggested_category_name
                    })
                    processed_transactions.append(processed_transaction)

                except Exception as transaction_error:
                    print(f"Erro ao processar transação: {transaction_error}")
                    # Fallback transaction
                    fallback_transaction = transaction.copy()
                    fallback_transaction.update({
                        'user_id': current_user_uid,
                        'context': context,
                        'category_id': None,
                        'category_name': 'outros'
                    })
                    processed_transactions.append(fallback_transaction)

            # Adiciona status às transações
            today = date.today()
            for t in processed_transactions:
                try:
                    transaction_date = datetime.strptime(t['date'], '%Y-%m-%d').date()
                    t['status'] = 'paid' if transaction_date <= today else 'pending'
                except (ValueError, KeyError):
                    t['status'] = 'pending'

            # Prepara resposta
            summary = result.get('processing_summary', {})
            summary['categories_created'] = categories_created
            
            all_categories = Category.find_all({'user_id': current_user_uid, 'context': context})
            available_categories = [{'id': str(cat._id), 'name': cat.name} for cat in all_categories]

            response_data = {
                'success': True,
                'transactions': processed_transactions,
                'summary': summary,
                'filename': filename,
                'available_categories': available_categories,
                'categories_created': categories_created
            }

            # Auto-save se solicitado
            if auto_save and processed_transactions:
                transaction_model = Transaction()
                saved_count = 0
                for transaction_data in processed_transactions:
                    if transaction_data.get('category_id'):
                        save_result = transaction_model.create_transaction(transaction_data)
                        if save_result.get('success', False):
                            saved_count += 1
                response_data['auto_saved'] = True
                response_data['saved_count'] = saved_count

            return jsonify(response_data), 200

        finally:
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)

    except Exception as e:
        print(f"Erro em process_document: {e}")
        print(traceback.format_exc())
        return jsonify({'success': False, 'error': f'Erro interno: {str(e)}'}), 500

@document_processing_bp.route('/api/documents/save-transactions', methods=['POST'])
@verify_token
def save_extracted_transactions(current_user_uid, current_user_data):
    """Salvar transações extraídas manualmente pelo usuário"""
    try:
        data = request.json
        if not data or 'transactions' not in data:
            return jsonify({'success': False, 'error': 'Dados de transações não fornecidos'}), 400
        
        transactions = data['transactions']
        if not isinstance(transactions, list):
            return jsonify({'success': False, 'error': 'Formato de transações inválido'}), 400
        
        transaction_model = Transaction()
        saved_transactions = []
        errors = []
        
        for i, transaction_data in enumerate(transactions):
            try:
                transaction_data['user_id'] = current_user_uid
                if 'context' not in transaction_data:
                    transaction_data['context'] = 'business'
                
                required_fields = ['description', 'amount', 'category_id', 'type', 'date', 'context']
                missing_fields = [field for field in required_fields if field not in transaction_data or transaction_data[field] is None]
                
                if missing_fields:
                    errors.append({'index': i, 'error': f'Campos obrigatórios faltando: {", ".join(missing_fields)}'})
                    continue
                
                result = transaction_model.create_transaction(transaction_data)
                if result.get('success', False):
                    saved_transactions.append({'index': i, 'transaction_id': result.get('transaction_id')})
                else:
                    errors.append({'index': i, 'error': result.get('error', 'Erro desconhecido ao salvar')})
                    
            except Exception as transaction_error:
                errors.append({'index': i, 'error': f'Erro ao processar transação: {str(transaction_error)}'})
        
        return jsonify({
            'success': True,
            'saved_count': len(saved_transactions),
            'error_count': len(errors),
            'saved_transactions': saved_transactions,
            'errors': errors
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Erro interno: {str(e)}'}), 500

@document_processing_bp.route('/api/documents/test', methods=['GET'])
def test_document_processing():
    """Rota de teste para verificar se o processamento está funcionando"""
    try:
        processor = HybridProcessor()
        test_text = "01/08/2025 COMPRA CARTAO MERCADO EXTRA -150,00"
        
        # Testa processamento via HybridProcessor
        result = processor.test_processing(test_text, 'business')
        
        return jsonify({
            'success': True,
            'test': 'HybridProcessor funcionando',
            'result': result
        }), 200
        
    except Exception as e:
        print(f"Erro no teste: {e}")
        return jsonify({
            'success': False,
            'test': 'FALHOU',
            'error': f'Erro no teste: {str(e)}'
        }), 500

@document_processing_bp.route('/api/documents/preview-categories', methods=['POST'])
def preview_auto_categories():
    """Visualizar categorização automática para uma lista de descrições"""
    try:
        data = request.json
        descriptions = data.get('descriptions', [])
        if not isinstance(descriptions, list):
            return jsonify({'success': False, 'error': 'Lista de descrições inválida'}), 400

        processor = HybridProcessor()
        categorized = []
        
        for description in descriptions:
            try:
                result = processor.suggest_category(description, 'business')
                categorized.append({
                    'description': description,
                    'suggested_category': result.get('category', 'outros')
                })
            except Exception as e:
                categorized.append({
                    'description': description,
                    'suggested_category': 'outros'
                })
        
        return jsonify({
            'success': True,
            'categorized_descriptions': categorized
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Erro interno: {str(e)}'}), 500

@document_processing_bp.route('/api/documents/extract-text', methods=['POST'])
@verify_token
def extract_text_only(current_user_uid, current_user_data):
    """Extrair apenas texto de um documento (sem processar transações)"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'Nenhum arquivo enviado'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'Nenhum arquivo selecionado'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Tipo de arquivo não suportado'}), 400
        
        filename = secure_filename(file.filename)
        file_extension = filename.rsplit('.', 1)[1].lower()

        with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_extension}') as temp_file:
            file.save(temp_file.name)
            temp_file_path = temp_file.name

        try:
            processor = HybridProcessor()
            result = processor.extract_text_only(temp_file_path, file_extension)
            
            if result.get('success'):
                return jsonify({
                    'success': True,
                    'extracted_text': result.get('text', ''),
                    'filename': filename
                }), 200
            else:
                return jsonify({
                    'success': False,
                    'error': result.get('error', 'Erro na extração de texto')
                }), 500
                
        finally:
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
                
    except Exception as e:
        return jsonify({'success': False, 'error': f'Erro interno: {str(e)}'}), 500

@document_processing_bp.route('/api/documents/supported-formats', methods=['GET'])
def get_supported_formats():
    """Retorna formatos suportados para upload"""
    return jsonify({
        'success': True,
        'supported_formats': {
            'documents': ['pdf'],
            'images': ['png', 'jpg', 'jpeg'],
            'spreadsheets': ['csv', 'xlsx', 'xls']
        },
        'max_file_size': '10MB',
        'features': {
            'pdf': 'Extração de texto e transações de extratos bancários',
            'images': 'OCR para extrair texto de comprovantes e extratos',
            'spreadsheets': 'Importação de planilhas com dados financeiros'
        }
    })

@document_processing_bp.route('/api/documents/processing-stats', methods=['GET'])
@verify_token
def get_processing_stats(current_user_uid, current_user_data):
    """Estatísticas de processamento do usuário"""
    return jsonify({
        'success': True,
        'stats': {
            'total_documents_processed': 0,
            'total_transactions_extracted': 0,
            'most_common_categories': [],
            'processing_accuracy': 0.95,
            'last_processed': None
        }
    })
