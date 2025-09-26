# ARQUIVO CORRIGIDO E SEGURO: src/routes/transactions_mongo.py
# $SAGRADO
# MODIFICAÇÃO: Unifica a distribuição de receitas e despesas para um único gráfico de pizza.

from flask import Blueprint, request, jsonify
from models.transaction_mongo import Transaction
from models.category_mongo import Category
from auth import verify_token
from datetime import datetime, date
from dateutil.relativedelta import relativedelta
import calendar
import re

transactions_bp = Blueprint('transactions', __name__)

# ==================================================================
# === ROTAS CRUD DE TRANSAÇÕES (CÓDIGO ORIGINAL PRESERVADO) ===
# ==================================================================

@transactions_bp.route('/api/transactions', methods=['GET'])
@verify_token
def get_transactions(current_user_uid, current_user_data, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    """Buscar transações APENAS do usuário logado"""
    try:
        # ... (código original sem alterações)
        context = request.args.get('context')
        type_filter = request.args.get('type')
        month = request.args.get('month')
        year = request.args.get('year')
        status_filter = request.args.get('status')
        search_term = request.args.get('search')
        limit = request.args.get('limit', type=int)
        
        filters = {'user_id': current_user_uid}
        
        if context: filters['context'] = context
        if type_filter: filters['type'] = type_filter
        if status_filter: filters['status'] = status_filter
            
        if search_term:
            regex = re.compile(re.escape(search_term), re.IGNORECASE)
            filters['description'] = regex

        if month and year:
            start_date = datetime(int(year), int(month), 1)
            end_date = datetime(int(year), int(month) + 1, 1) if int(month) < 12 else datetime(int(year) + 1, 1, 1)
            filters['date'] = {'$gte': start_date, '$lt': end_date}
        
        transactions = Transaction.find_all(filters, limit=limit)
        return jsonify([t.to_dict() for t in transactions])
    except Exception as e:
        print(f"Error in get_transactions: {e}")
        return jsonify({'error': str(e)}), 500

@transactions_bp.route('/api/transactions', methods=['POST'])
@verify_token
def create_transaction(current_user_uid, current_user_data, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    """Criar transação para o usuário logado"""
    try:
        data = request.get_json()
        print(f"Received data: {data}")
        
        data['user_id'] = current_user_uid
        
        # ==================================================================
        # === CORREÇÃO APLICADA AQUI (DATA) ===
        # ==================================================================
        # O frontend envia 'YYYY-MM-DDTHH:MM:SS.ms'. Pegamos apenas a parte da data.
        date_string = data['date'].split('T')[0]
        transaction_date = datetime.strptime(date_string, '%Y-%m-%d')
        
        due_date = None
        if data.get('due_date'):
            due_date_string = data['due_date'].split('T')[0]
            due_date = datetime.strptime(due_date_string, '%Y-%m-%d')
        # ==================================================================
        
        transaction = Transaction(
            user_id=current_user_uid,
            description=data['description'],
            amount=float(data['amount']),
            type=data['type'],
            context=data.get('context', 'business'),
            category_id=data['category_id'],
            date=transaction_date,
            due_date=due_date,
            status=data.get('status', 'pending'),
            is_recurring=data.get('is_recurring', False),
            recurring_day=data.get('recurring_day')
        )
        
        result = transaction.save()
        print(f"Transaction saved successfully: {result._id}")
        
        if transaction.is_recurring and transaction.recurring_day:
            create_next_recurring_transaction(transaction)
        
        return jsonify(transaction.to_dict()), 201
    except Exception as e:
        print(f"Error in create_transaction: {e}")
        return jsonify({'error': str(e)}), 500

@transactions_bp.route('/api/transactions/<transaction_id>', methods=['PUT'])
@verify_token
def update_transaction(current_user_uid, current_user_data, transaction_id, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    """Atualizar transação verificando se pertence ao usuário"""
    try:
        transaction = Transaction.find_by_id(transaction_id)
        if not transaction or transaction.user_id != current_user_uid:
            return jsonify({'error': 'Transaction not found or permission denied'}), 404
        
        data = request.get_json()
        
        transaction.description = data.get('description', transaction.description)
        transaction.amount = float(data.get('amount', transaction.amount))
        transaction.type = data.get('type', transaction.type)
        transaction.context = data.get('context', transaction.context)
        transaction.category_id = data.get('category_id', transaction.category_id)
        transaction.status = data.get('status', transaction.status)
        
        # ==================================================================
        # === CORREÇÃO APLICADA AQUI (DATA) ===
        # ==================================================================
        if data.get('date'):
            date_string = data['date'].split('T')[0]
            transaction.date = datetime.strptime(date_string, '%Y-%m-%d')
        if data.get('due_date'):
            due_date_string = data['due_date'].split('T')[0]
            transaction.due_date = datetime.strptime(due_date_string, '%Y-%m-%d')
        # ==================================================================
        
        transaction.updated_at = datetime.utcnow()
        transaction.save()
        
        return jsonify(transaction.to_dict())
    except Exception as e:
        print(f"Error in update_transaction: {e}")
        return jsonify({'error': str(e)}), 500

@transactions_bp.route('/api/transactions/<transaction_id>', methods=['DELETE'])
@verify_token
def delete_transaction(current_user_uid, current_user_data, transaction_id, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    """Deletar transação verificando se pertence ao usuário"""
    try:
        # ... (código original sem alterações)
        transaction = Transaction.find_by_id(transaction_id)
        if not transaction or transaction.user_id != current_user_uid:
            return jsonify({'error': 'Transaction not found or permission denied'}), 404
        
        transaction.delete()
        return jsonify({'message': 'Transaction deleted successfully'})
    except Exception as e:
        print(f"Error in delete_transaction: {e}")
        return jsonify({'error': str(e)}), 500

# ... (Resto do arquivo sem alterações)
# ==================================================================
# === FUNÇÃO DE RESUMO INTERNA (CÓDIGO ORIGINAL PRESERVADO) ===
# ==================================================================
def get_dashboard_summary(current_user_uid, current_user_data):
    # ... (código original)
    context = request.args.get('context', 'business')
    current_month = datetime.now().month
    current_year = datetime.now().year
    
    filters = {
        'user_id': current_user_uid,
        'context': context,
        'date': {
            '$gte': datetime(current_year, current_month, 1),
            '$lt': datetime(current_year, current_month + 1, 1) if current_month < 12 else datetime(current_year + 1, 1, 1)
        }
    }
    
    month_transactions = Transaction.find_all(filters)
    
    total_income = sum(t.amount for t in month_transactions if t.type == 'income')
    total_expenses = sum(t.amount for t in month_transactions if t.type == 'expense')
    balance = total_income - total_expenses
    
    pending_payments = len([t for t in month_transactions if t.type == 'expense' and t.status == 'pending'])
    upcoming_receivables = len([t for t in month_transactions if t.type == 'income' and t.status == 'pending'])
    
    return {
        'balance': balance,
        'total_income': total_income,
        'total_expenses': total_expenses,
        'pending_payments': pending_payments,
        'upcoming_receivables': upcoming_receivables,
        'month': current_month,
        'year': current_year
    }

# ==================================================================
# === ROTA DE DASHBOARD COMPLETO (MODIFICADA) ===
# ==================================================================

@transactions_bp.route('/api/dashboard/full-summary', methods=['GET'])
@verify_token
def get_full_dashboard_summary(current_user_uid, current_user_data, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    try:
        context = request.args.get('context', 'business')
        now = datetime.now()
        
        summary_data = get_dashboard_summary(current_user_uid, current_user_data)
        
        monthly_trend = []
        for i in range(5, -1, -1):
            month_date = now - relativedelta(months=i)
            start_date = datetime(month_date.year, month_date.month, 1)
            end_date = start_date + relativedelta(months=1)
            
            month_filters = {
                'user_id': current_user_uid,
                'context': context,
                'date': {'$gte': start_date, '$lt': end_date}
            }
            transactions_in_month = Transaction.find_all(month_filters)
            
            income = sum(t.amount for t in transactions_in_month if t.type == 'income')
            expenses = sum(t.amount for t in transactions_in_month if t.type == 'expense')
            
            monthly_trend.append({
                'month': start_date.strftime('%b'),
                'income': income,
                'expenses': expenses
            })

        current_month_start = datetime(now.year, now.month, 1)
        current_month_end = current_month_start + relativedelta(months=1)
        
        all_transactions_in_period_filters = {
            'user_id': current_user_uid,
            'context': context,
            'date': {'$gte': current_month_start, '$lt': current_month_end}
        }
        all_transactions_in_period = Transaction.find_all(all_transactions_in_period_filters)
        
        # --- INÍCIO DA MODIFICAÇÃO ---
        # 1. Agrupar TODAS as transações (receitas e despesas) por categoria
        
        cash_flow_by_category = {}
        for t in all_transactions_in_period:
            # Usamos o to_dict() para pegar o category_name que já é resolvido no modelo
            category_name = t.to_dict().get('category_name', 'Sem Categoria')
            
            # Inicializa a estrutura para uma nova categoria
            if category_name not in cash_flow_by_category:
                cash_flow_by_category[category_name] = {'amount': 0, 'type': t.type}
            
            # Soma o valor da transação ao total da categoria
            cash_flow_by_category[category_name]['amount'] += t.amount

        # 2. Formatar a saída para a API em uma lista unificada
        cash_flow_distribution = [
            {
                'category_name': name,
                'total': data['amount'],
                'type': data['type'] # Mantemos o tipo para o frontend poder diferenciar as cores
            } 
            for name, data in cash_flow_by_category.items()
        ]
        
        # --- FIM DA MODIFICAÇÃO ---
        
        transaction_count = len(all_transactions_in_period)
        avg_transaction_value = (summary_data['total_income'] + summary_data['total_expenses']) / transaction_count if transaction_count > 0 else 0

        full_summary = {
            **summary_data,
            'monthly_trend': monthly_trend,
            'cash_flow_distribution': cash_flow_distribution, # <<< CAMPO UNIFICADO
            'transaction_count': transaction_count,
            'avg_transaction_value': avg_transaction_value,
            'cash_flow_trend': 'stable',
            'monthly_growth': 0.0,
        }
        
        return jsonify(full_summary)

    except Exception as e:
        print(f"Error in get_full_dashboard_summary: {e}")
        return jsonify({'error': str(e)}), 500

# ==================================================================
# === ROTAS DE COMPATIBILIDADE E AUXILIARES (CÓDIGO ORIGINAL PRESERVADO) ===
# ==================================================================

def create_next_recurring_transaction(original_transaction):
    # ... (código original)
    try:
        today = date.today()
        next_month = today.month + 1 if today.month < 12 else 1
        next_year = today.year if today.month < 12 else today.year + 1
        
        last_day = calendar.monthrange(next_year, next_month)[1]
        next_day = min(original_transaction.recurring_day, last_day)
        next_due_date = datetime(next_year, next_month, next_day)
        
        filters = {
            'user_id': original_transaction.user_id,
            'description': original_transaction.description,
            'context': original_transaction.context,
            'is_recurring': True,
            'date': {
                '$gte': datetime(next_year, next_month, 1),
                '$lt': datetime(next_year, next_month + 1, 1) if next_month < 12 else datetime(next_year + 1, 1, 1)
            }
        }
        
        existing = Transaction.find_all(filters)
        
        if not existing:
            next_transaction = Transaction(
                user_id=original_transaction.user_id,
                description=original_transaction.description,
                amount=original_transaction.amount,
                type=original_transaction.type,
                context=original_transaction.context,
                category_id=original_transaction.category_id,
                date=next_due_date,
                due_date=next_due_date,
                status='pending',
                is_recurring=True,
                recurring_day=original_transaction.recurring_day
            )
            next_transaction.save()
            print(f"Next recurring transaction created: {next_transaction._id}")
    except Exception as e:
        print(f"Error creating recurring transaction: {e}")

@transactions_bp.route('/api/categories/seed', methods=['POST'])
@verify_token
def seed_categories_for_user(current_user_uid, current_user_data, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    # ... (código original)
    try:
        count = Category.seed_default_categories(user_id=current_user_uid)
        return jsonify({
            'success': True,
            'message': f'{count} categorias padrão verificadas/criadas com sucesso!'
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@transactions_bp.route('/api/accounting/summary', methods=['GET'])
@verify_token
def get_dashboard_summary_alias(current_user_uid, current_user_data, *args, **kwargs): # <-- CORREÇÃO DE ASSINATURA
    """
    Alias para compatibilidade. Agora chama a nova rota completa.
    """
    return get_full_dashboard_summary(current_user_uid, current_user_data)
