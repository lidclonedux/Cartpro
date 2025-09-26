# ARQUIVO CORRIGIDO E SEGURO: src/routes/categories_mongo.py
# $SAGRADO

from flask import Blueprint, request, jsonify
from models.category_mongo import Category
from auth import verify_token

categories_bp = Blueprint('categories_mongo', __name__)

# ==================================================================
# === ROTA PRINCIPAL /api/categories (CÓDIGO ORIGINAL PRESERVADO) ===
# ==================================================================

@categories_bp.route('/api/categories', methods=['GET'])
@verify_token
def get_categories(current_user_uid, current_user_data, *args, **kwargs):
    """
    Busca e retorna as categorias associadas ao usuário logado.
    Pode ser filtrado por contexto (ex: 'business' ou 'product').
    """
    try:
        context = request.args.get('context')
        filters = {'user_id': current_user_uid}
        if context:
            filters['context'] = context
        
        categories = Category.find_all(filters)
        return jsonify([c.to_dict() for c in categories]), 200
    except Exception as e:
        return jsonify({'error': f"Ocorreu um erro ao buscar categorias: {str(e)}"}), 500

@categories_bp.route('/api/categories', methods=['POST'])
@verify_token
def create_category(current_user_uid, current_user_data, *args, **kwargs):
    """Cria uma nova categoria associada ao usuário logado."""
    try:
        data = request.get_json()
        if not data or not data.get('name'):
            return jsonify({'error': 'O campo "name" é obrigatório.'}), 400
        
        data['user_id'] = current_user_uid
        
        # O construtor do modelo agora aceita um dicionário diretamente
        category = Category(data)
        category.save()
        
        return jsonify(category.to_dict()), 201
    except Exception as e:
        return jsonify({'error': f"Ocorreu um erro ao criar a categoria: {str(e)}"}), 500

@categories_bp.route('/api/categories/<category_id>', methods=['PUT'])
@verify_token
def update_category(current_user_uid, current_user_data, category_id, *args, **kwargs):
    """Atualiza uma categoria existente, verificando a permissão do usuário."""
    try:
        category = Category.find_by_id(category_id)
        if not category or category.user_id != current_user_uid:
            return jsonify({'error': 'Categoria não encontrada ou acesso negado.'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Nenhum dado fornecido para atualização.'}), 400
        
        category.name = data.get('name', category.name)
        category.context = data.get('context', category.context)
        category.type = data.get('type', category.type)
        category.color = data.get('color', category.color)
        category.icon = data.get('icon', category.icon)
        category.emoji = data.get('emoji', category.emoji)
        
        category.save()
        return jsonify(category.to_dict()), 200
    except Exception as e:
        return jsonify({'error': f"Ocorreu um erro ao atualizar a categoria: {str(e)}"}), 500

@categories_bp.route('/api/categories/<category_id>', methods=['DELETE'])
@verify_token
def delete_category(current_user_uid, current_user_data, category_id, *args, **kwargs):
    """Deleta uma categoria, verificando a permissão do usuário."""
    try:
        category = Category.find_by_id(category_id)
        if not category or category.user_id != current_user_uid:
            return jsonify({'error': 'Categoria não encontrada ou acesso negado.'}), 404
        
        category.delete()
        return jsonify({'message': 'Categoria deletada com sucesso.'}), 200
    except Exception as e:
        return jsonify({'error': f"Ocorreu um erro ao deletar a categoria: {str(e)}"}), 500

# ==================================================================
# === ROTAS DE ALIAS /api/accounting/categories (CORRIGIDAS) ===
# ==================================================================

@categories_bp.route('/api/accounting/categories', methods=['GET'])
@verify_token
def accounting_categories_alias_get(current_user_uid, current_user_data, *args, **kwargs):
    """Alias para GET /api/categories. Chama a função principal diretamente."""
    return get_categories(current_user_uid, current_user_data)

@categories_bp.route('/api/accounting/categories', methods=['POST'])
@verify_token
def accounting_categories_alias_post(current_user_uid, current_user_data, *args, **kwargs):
    """Alias para POST /api/categories. Chama a função principal diretamente."""
    return create_category(current_user_uid, current_user_data)

@categories_bp.route('/api/accounting/categories/<category_id>', methods=['PUT'])
@verify_token
def accounting_categories_alias_put(current_user_uid, current_user_data, category_id, *args, **kwargs):
    """Alias para PUT /api/categories/<id>. Chama a função principal diretamente."""
    return update_category(current_user_uid, current_user_data, category_id)

@categories_bp.route('/api/accounting/categories/<category_id>', methods=['DELETE'])
@verify_token
def accounting_categories_alias_delete(current_user_uid, current_user_data, category_id, *args, **kwargs):
    """Alias para DELETE /api/categories/<id>. Chama a função principal diretamente."""
    return delete_category(current_user_uid, current_user_data, category_id)

# ==================================================================
# === ROTAS AUXILIARES (CÓDIGO ORIGINAL PRESERVADO) ===
# ==================================================================

@categories_bp.route('/api/categories/seed', methods=['POST'])
@verify_token
def seed_user_categories(current_user_uid, current_user_data, *args, **kwargs):
    """Cria as categorias padrão para o usuário logado, se ainda não existirem."""
    try:
        count = Category.seed_default_categories(user_id=current_user_uid)
        message = f'{count} categorias padrão foram criadas com sucesso!' if count > 0 else 'Todas as categorias padrão já existem.'
        return jsonify({'success': True, 'message': message, 'categories_created': count}), 200
    except Exception as e:
        return jsonify({'error': f"Ocorreu um erro ao criar categorias padrão: {str(e)}"}), 500

@categories_bp.route('/api/categories/colors', methods=['GET'])
def get_available_colors():
    """Retorna uma paleta de cores pré-definidas para o frontend."""
    vibrant_colors = [
        '#DC2626', '#EA580C', '#D97706', '#CA8A04', '#65A30D', '#059669',
        '#0891B2', '#0284C7', '#2563EB', '#7C3AED', '#C026D3', '#DB2777',
        '#BE123C', '#92400E', '#374151'
    ]
    return jsonify({'success': True, 'colors': vibrant_colors})

@categories_bp.route('/api/categories/emojis', methods=['GET'])
def get_available_emojis():
    """Retorna uma coleção de emojis organizados por tema para o frontend."""
    emoji_categories = {
        'financeiro': ['💰', '💳', '💵', '💸', '💎', '🏦', '📊', '📈', '📉', '💹'],
        'casa': ['🏠', '🏡', '🏢', '🏬', '🏭', '🏪', '🛏️', '🛋️', '🚿', '🔌'],
        'transporte': ['🚗', '🚙', '🚐', '🚚', '🛻', '🏍️', '🚲', '🛴', '⛽', '🚏'],
        'alimentacao': ['🍕', '🍔', '🌭', '🥪', '🌮', '🍝', '🍜', '🍱', '☕', '🍺'],
        'compras': ['🛒', '🛍️', '👕', '👔', '👗', '👠', '💄', '📱', '💻', '⌚'],
        'saude': ['🏥', '💊', '🩺', '💉', '🦷', '👓', '🏃', '🧘', '💪', '❤️'],
        'educacao': ['📚', '📖', '✏️', '🖊️', '📝', '🎓', '🎒', '💡', '🔬', '📐'],
        'lazer': ['🎬', '🎮', '🎵', '🎸', '🎨', '📺', '📷', '🎪', '🎭', '🎫'],
        'trabalho': ['💼', '📊', '📈', '📉', '💹', '📋', '📄', '🖥️', '⌨️', '🖨️'],
        'viagem': ['✈️', '🏨', '🗺️', '🧳', '📷', '🎒', '🌍', '🗽', '🏖️', '⛱️'],
        'servicos': ['🔧', '🔨', '🪚', '⚡', '🔌', '🧹', '🧽', '🧴', '🚿', '🔑'],
        'impostos': ['📋', '📄', '📊', '💼', '🏛️', '⚖️', '📝', '✍️', '🎯', '📌']
    }
    return jsonify({
        'success': True,
        'emoji_categories': emoji_categories,
        'total_emojis': sum(len(emojis) for emojis in emoji_categories.values())
    })
