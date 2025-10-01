# ARQUIVO ESPECIALIZADO: src/services/transaction_reconciler.py
# MÓDULO FILHO: Lógica avançada de reconciliação e anti-duplicidade

from datetime import datetime, timedelta
import re
from typing import List, Dict, Optional, Tuple
from bson import ObjectId
import hashlib
from config import Config

class TransactionReconciler:
    """
    Módulo especializado em reconciliação inteligente de transações
    Responsável por evitar duplicidades e reconciliar com pedidos do e-commerce
    """
    
    def __init__(self):
        # Configurações de tolerância para matching
        self.tolerance_config = {
            'time_tolerance_minutes': 10,  # ±10 minutos para timestamp
            'amount_tolerance_percent': 0.01,  # 1% de tolerância no valor
            'description_similarity_threshold': 0.75,  # 75% similaridade
            'name_similarity_threshold': 0.6,  # 60% para nomes
            'exact_match_priority': True
        }
        
        # Cache para otimizar consultas repetitivas
        self._user_cache = {}
        self._cache_ttl = 300  # 5 minutos
        
        # Patterns específicos para diferentes tipos de transação
        self.pix_patterns = {
            'received': [
                r'pix\s+recebido\s+(?:de\s+)?([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+?)(?:\s|$)',
                r'recebimento\s+pix\s+(?:de\s+)?([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+?)(?:\s|$)',
                r'transferencia\s+recebida\s+(?:de\s+)?([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+?)(?:\s|$)'
            ],
            'sent': [
                r'pix\s+(?:para\s+|enviado\s+para\s+)?([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+?)(?:\s|$)',
                r'pagamento\s+pix\s+(?:para\s+)?([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+?)(?:\s|$)',
                r'transferencia\s+(?:para\s+)?([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+?)(?:\s|$)'
            ]
        }

        # Sistema expandido de categorias inteligentes
        self.advanced_categories = {
            'Alimentação e Bebidas': {
                'keywords': [
                    'mercado', 'supermercado', 'padaria', 'restaurante', 'lanchonete', 'pizzaria',
                    'hamburgueria', 'açougue', 'hortifruti', 'extra', 'carrefour', 'pão de açúcar',
                    'big', 'walmart', 'ifood', 'uber eats', 'delivery', 'comida', 'alimento',
                    'bebida', 'café', 'bar', 'choperia', 'sorveteria', 'confeitaria', 'doçaria',
                    'panificadora', 'empório', 'mercearia', 'quitanda', 'feira', 'frutaria',
                    'mcdonald', 'burger king', 'subway', 'kfc', 'domino', 'pizza hut',
                    'outback', 'spoleto', 'bobs', 'habib', 'giraffas', 'vivenda'
                ],
                'patterns': [
                    r'(mercado|super|padaria|restaurante)\s+\w+',
                    r'\w+\s+(food|lanches|pizza|burger)',
                    r'delivery\s+\w+'
                ]
            },
            'Transporte e Combustível': {
                'keywords': [
                    'uber', 'taxi', '99', 'cabify', 'ônibus', 'metrô', 'trem', 'estacionamento',
                    'pedágio', 'vlt', 'brt', 'passagem', 'viagem', 'posto', 'shell', 'petrobras',
                    'ipiranga', 'ale', 'br', 'combustível', 'gasolina', 'etanol', 'diesel',
                    'abastecimento', 'oficina', 'mecanica', 'pneu', 'lavagem', 'autolavagem',
                    'estacionamento', 'zona azul', 'detran', 'ipva', 'seguro auto', 'guincho'
                ],
                'patterns': [
                    r'posto\s+\w+',
                    r'\w+\s+(combustivel|gasolina)',
                    r'uber\s+trip'
                ]
            },
            'Saúde e Bem-estar': {
                'keywords': [
                    'farmácia', 'drogaria', 'hospital', 'clínica', 'laboratório', 'médico',
                    'dentista', 'fisioterapeuta', 'psicólogo', 'remédio', 'medicamento',
                    'consulta', 'exame', 'raio x', 'ultrassom', 'ressonância', 'tomografia',
                    'academia', 'ginástica', 'pilates', 'yoga', 'nutricionista', 'oftalmologista',
                    'cardiologista', 'dermatologista', 'veterinário', 'pet shop', 'spa',
                    'massagem', 'estética', 'salão', 'barbearia', 'manicure', 'pedicure'
                ],
                'patterns': [
                    r'dr\.\s+\w+',
                    r'clinica\s+\w+',
                    r'\w+\s+(medica|saude)'
                ]
            },
            'Educação e Desenvolvimento': {
                'keywords': [
                    'escola', 'faculdade', 'universidade', 'curso', 'livro', 'material escolar',
                    'mensalidade', 'matrícula', 'formação', 'inglês', 'idioma', 'informática',
                    'treinamento', 'capacitação', 'workshop', 'seminário', 'palestra', 'coaching',
                    'mentoria', 'consultoria', 'assessoria', 'papelaria', 'livraria', 'editora'
                ],
                'patterns': [
                    r'colegio\s+\w+',
                    r'universidade\s+\w+',
                    r'curso\s+de\s+\w+'
                ]
            },
            'Casa e Moradia': {
                'keywords': [
                    'aluguel', 'condomínio', 'luz', 'energia', 'água', 'gás', 'internet',
                    'telefone', 'tv', 'streaming', 'netflix', 'casa', 'manutenção', 'limpeza',
                    'móveis', 'decoração', 'reforma', 'pintura', 'eletricista', 'encanador',
                    'jardineiro', 'diarista', 'faxineira', 'casas bahia', 'magazine luiza',
                    'ponto frio', 'extra', 'americanas', 'submarino', 'mercado livre',
                    'construção', 'material construção', 'cimento', 'tinta', 'ferragem'
                ],
                'patterns': [
                    r'loja\s+de\s+\w+',
                    r'\w+\s+(casa|lar)',
                    r'construção\s+\w+'
                ]
            },
            'Vestuário e Beleza': {
                'keywords': [
                    'loja', 'roupa', 'calçado', 'sapato', 'tênis', 'camisa', 'calça', 'vestido',
                    'shopping', 'moda', 'acessório', 'bolsa', 'carteira', 'cinto', 'óculos',
                    'joia', 'bijuteria', 'relógio', 'perfume', 'cosméticos', 'maquiagem',
                    'shampoo', 'condicionador', 'creme', 'loção', 'c&a', 'renner', 'riachuelo',
                    'zara', 'h&m', 'adidas', 'nike', 'puma', 'havaianas', 'melissa'
                ],
                'patterns': [
                    r'\w+\s+(moda|fashion)',
                    r'loja\s+\w+',
                    r'shopping\s+\w+'
                ]
            },
            'Tecnologia e Digital': {
                'keywords': [
                    'apple', 'samsung', 'google', 'microsoft', 'amazon', 'netflix', 'spotify',
                    'disney', 'prime', 'youtube', 'software', 'app', 'aplicativo', 'celular',
                    'notebook', 'computador', 'tablet', 'fone', 'cabo', 'carregador', 'capinha',
                    'instagram', 'facebook', 'whatsapp', 'telegram', 'zoom', 'skype', 'discord',
                    'steam', 'playstation', 'xbox', 'nintendo', 'game', 'jogo', 'assinatura digital'
                ],
                'patterns': [
                    r'\w+\s+(tech|tecnologia)',
                    r'loja\s+de\s+informatica',
                    r'assistencia\s+tecnica'
                ]
            },
            'Lazer e Entretenimento': {
                'keywords': [
                    'cinema', 'teatro', 'show', 'festa', 'bar', 'balada', 'viagem', 'hotel',
                    'pousada', 'turismo', 'diversão', 'entretenimento', 'parque', 'zoológico',
                    'museu', 'exposição', 'evento', 'ingresso', 'ticket', 'booking', 'airbnb',
                    'decolar', 'latam', 'gol', 'azul', 'tam', 'smiles', 'multiplus', 'praia',
                    'montanha', 'campo', 'sitio', 'fazenda', 'clube', 'resort', 'cruzeiro'
                ],
                'patterns': [
                    r'hotel\s+\w+',
                    r'pousada\s+\w+',
                    r'cinema\s+\w+'
                ]
            },
            'Serviços Financeiros': {
                'keywords': [
                    'banco', 'taxa', 'tarifa', 'anuidade', 'juros', 'iof', 'cpmf', 'empréstimo',
                    'financiamento', 'cartão', 'crédito', 'mastercard', 'visa', 'elo', 'fatura',
                    'investimento', 'poupança', 'aplicação', 'cdb', 'tesouro', 'ações', 'bolsa',
                    'corretora', 'seguro', 'previdência', 'consórcio', 'financeira', 'cooperativa'
                ],
                'patterns': [
                    r'banco\s+\w+',
                    r'cartao\s+\w+',
                    r'seguro\s+\w+'
                ]
            },
            'PIX e Transferências': {
                'keywords': [
                    'pix', 'transferência', 'ted', 'doc', 'pagamento', 'recebimento', 'envio',
                    'qr code', 'chave pix', 'pix parcelado', 'pix agendado', 'pix cobrança'
                ],
                'patterns': [
                    r'pix\s+(recebido|enviado|para|de)',
                    r'transferencia\s+\w+',
                    r'ted\s+\w+'
                ]
            },
            'Impostos e Governo': {
                'keywords': [
                    'imposto', 'iptu', 'ipva', 'ir', 'inss', 'fgts', 'pis', 'cofins', 'icms',
                    'iss', 'receita federal', 'prefeitura', 'detran', 'cartorio', 'certidão',
                    'multa', 'tributo', 'contribuição', 'taxa municipal', 'licenciamento'
                ],
                'patterns': [
                    r'imposto\s+\w+',
                    r'taxa\s+\w+',
                    r'multa\s+\w+'
                ]
            },
            'Pets e Animais': {
                'keywords': [
                    'veterinário', 'pet shop', 'ração', 'medicamento animal', 'vacina animal',
                    'tosa', 'banho animal', 'hotel pet', 'creche pet', 'adestramento',
                    'pet taxi', 'cemitério pet', 'cirurgia animal', 'castração'
                ],
                'patterns': [
                    r'pet\s+\w+',
                    r'veterinaria\s+\w+',
                    r'clinica\s+veterinaria'
                ]
            },
            'Doações e Caridade': {
                'keywords': [
                    'doação', 'caridade', 'ong', 'instituto', 'fundação', 'igreja', 'templo',
                    'dizimo', 'oferta', 'contribuição social', 'solidariedade', 'beneficência'
                ],
                'patterns': [
                    r'igreja\s+\w+',
                    r'ong\s+\w+',
                    r'instituto\s+\w+'
                ]
            }
        }

    def process_transactions_with_intelligence(self, raw_transactions: List[Dict], user_id: str, context: str) -> Dict:
        """
        MÉTODO PRINCIPAL: Processar transações com inteligência anti-duplicidade
        """
        try:
            if not raw_transactions or not user_id:
                return {
                    'success': False,
                    'error': 'Dados insuficientes para processamento',
                    'transactions': []
                }

            # Pré-processamento: normalizar e enriquecer transações
            enriched_transactions = self._enrich_raw_transactions(raw_transactions, user_id)
            
            # Processamento principal: aplicar lógica de reconciliação
            processed_transactions = []
            reconciliation_stats = {
                'total_processed': 0,
                'new_transactions': 0,
                'ignored_duplicates': 0,
                'reconciled_with_orders': 0,
                'potential_matches': 0,
                'errors': 0
            }
            
            for transaction in enriched_transactions:
                try:
                    result = self._process_single_transaction(transaction, user_id, context)
                    processed_transactions.append(result['transaction'])
                    
                    # Atualizar estatísticas
                    status = result['transaction'].get('reconciliation_status', 'error')
                    if status == 'new_transaction':
                        reconciliation_stats['new_transactions'] += 1
                    elif status == 'ignored_duplicate':
                        reconciliation_stats['ignored_duplicates'] += 1
                    elif status == 'reconciled_with_order':
                        reconciliation_stats['reconciled_with_orders'] += 1
                    elif status == 'potential_match':
                        reconciliation_stats['potential_matches'] += 1
                    else:
                        reconciliation_stats['errors'] += 1
                    
                    reconciliation_stats['total_processed'] += 1
                    
                except Exception as e:
                    print(f"Erro ao processar transação individual: {e}")
                    # Incluir transação com erro para não perder dados
                    transaction['reconciliation_status'] = 'processing_error'
                    transaction['reconciliation_reason'] = f'Erro no processamento: {str(e)}'
                    processed_transactions.append(transaction)
                    reconciliation_stats['errors'] += 1

            # Pós-processamento: análises adicionais
            final_transactions = self._post_process_reconciled_transactions(processed_transactions, user_id)
            
            return {
                'success': True,
                'transactions': final_transactions,
                'reconciliation_summary': reconciliation_stats,
                'reconciliation_report': self._generate_detailed_report(reconciliation_stats, final_transactions),
                'recommendations': self._generate_intelligent_recommendations(final_transactions, reconciliation_stats)
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'Erro na reconciliação inteligente: {str(e)}',
                'transactions': []
            }

    def _enrich_raw_transactions(self, raw_transactions: List[Dict], user_id: str) -> List[Dict]:
        """
        Enriquecer transações brutas com dados normalizados e metadados
        """
        enriched = []
        
        for i, transaction in enumerate(raw_transactions):
            try:
                # Clonar transação para não modificar original
                enriched_transaction = transaction.copy()
                
                # Adicionar ID único para rastreamento
                enriched_transaction['temp_id'] = self._generate_temp_id(transaction, i)
                
                # Normalizar timestamp com fuso horário
                enriched_transaction['normalized_datetime'] = self._normalize_timestamp(
                    transaction.get('raw_timestamp') or transaction.get('date')
                )
                
                # Extrair informações de PIX se aplicável
                if self._is_pix_transaction(transaction):
                    pix_info = self._extract_pix_info(transaction)
                    enriched_transaction.update(pix_info)
                
                # Gerar hash para detecção de duplicatas
                enriched_transaction['content_hash'] = self._generate_content_hash(enriched_transaction)
                
                # Aplicar categorização inteligente avançada
                enriched_transaction['category'] = self._suggest_advanced_category(transaction)
                
                # Adicionar score de confiança se não existir
                if 'confidence_score' not in enriched_transaction:
                    enriched_transaction['confidence_score'] = self._estimate_confidence(enriched_transaction)
                
                enriched.append(enriched_transaction)
                
            except Exception as e:
                print(f"Erro ao enriquecer transação {i}: {e}")
                # Incluir transação original em caso de erro
                transaction['enrichment_error'] = str(e)
                enriched.append(transaction)
        
        return enriched

    def _suggest_advanced_category(self, transaction: Dict) -> str:
        """
        Sistema avançado de categorização com análise multi-camada
        """
        description = transaction.get('description', '').lower()
        amount = transaction.get('amount', 0)
        transaction_type = transaction.get('type', 'expense')
        
        if not description:
            return self._categorize_by_amount_and_type(amount, transaction_type)
        
        # Primeiro: verificar categorias específicas
        for category_name, category_data in self.advanced_categories.items():
            # Verificar keywords
            for keyword in category_data['keywords']:
                if keyword.lower() in description:
                    return category_name
            
            # Verificar patterns regex
            if 'patterns' in category_data:
                for pattern in category_data['patterns']:
                    if re.search(pattern, description, re.IGNORECASE):
                        return category_name
        
        # Segundo: análise contextual baseada no tipo de transação
        if transaction_type == 'income':
            if any(word in description for word in ['pix recebido', 'recebimento', 'venda', 'cliente']):
                return 'Vendas E-commerce'
            elif any(word in description for word in ['salário', 'ordenado', 'pagamento']):
                return 'Renda e Salário'
            else:
                return 'PIX e Transferências'
        
        # Terceiro: análise por valor
        return self._categorize_by_amount_and_type(amount, transaction_type)

    def _categorize_by_amount_and_type(self, amount: float, transaction_type: str) -> str:
        """
        Categorização baseada no valor e tipo da transação
        """
        if transaction_type == 'income':
            if amount > 5000:
                return 'Renda Principal'
            elif amount > 1000:
                return 'Renda Extra'
            else:
                return 'PIX e Transferências'
        else:  # expense
            if amount > 2000:
                return 'Grandes Gastos'
            elif amount > 500:
                return 'Gastos Médios'
            elif amount > 100:
                return 'Gastos Pequenos'
            else:
                return 'Outros'

    def _process_single_transaction(self, transaction: Dict, user_id: str, context: str) -> Dict:
        """
        Processar uma única transação com toda a lógica de reconciliação
        """
        # NÍVEL 1: Verificação de duplicata exata
        duplicate_check = self._check_exact_duplicate(transaction, user_id)
        if duplicate_check['is_duplicate']:
            return {
                'transaction': {
                    **transaction,
                    'reconciliation_status': 'ignored_duplicate',
                    'reconciliation_reason': duplicate_check['reason'],
                    'duplicate_transaction_id': duplicate_check.get('duplicate_id'),
                    'processing_action': 'ignored'
                }
            }
        
        # NÍVEL 2: Verificação de match com pedidos (apenas para receitas PIX)
        if transaction.get('type') == 'income' and self._is_pix_transaction(transaction):
            order_match = self._check_order_reconciliation(transaction, user_id)
            if order_match['found_match']:
                return {
                    'transaction': {
                        **transaction,
                        'reconciliation_status': 'reconciled_with_order',
                        'reconciliation_reason': order_match['reason'],
                        'matched_order_id': order_match['order_id'],
                        'processing_action': 'reconciled',
                        'auto_confirmed_order': order_match.get('auto_confirmed', False)
                    }
                }
        
        # NÍVEL 3: Verificação de similaridade (potencial duplicata)
        similarity_check = self._check_potential_duplicate(transaction, user_id)
        if similarity_check['is_potential']:
            return {
                'transaction': {
                    **transaction,
                    'reconciliation_status': 'potential_match',
                    'reconciliation_reason': similarity_check['reason'],
                    'similar_transaction_id': similarity_check.get('similar_id'),
                    'similarity_score': similarity_check.get('score'),
                    'processing_action': 'flagged_for_review'
                }
            }
        
        # NÍVEL 4: Nova transação
        return {
            'transaction': {
                **transaction,
                'reconciliation_status': 'new_transaction',
                'reconciliation_reason': 'Nova operação financeira identificada',
                'processing_action': 'ready_to_save'
            }
        }

    def _check_exact_duplicate(self, transaction: Dict, user_id: str) -> Dict:
        """
        NÍVEL 1: Verificar duplicata exata com múltiplos critérios
        """
        try:
            from models.transaction_mongo import Transaction
            
            # Critério 1: Hash exato (mais rápido)
            content_hash = transaction.get('content_hash')
            if content_hash:
                hash_matches = Transaction.find_all({
                    'user_id': user_id,
                    'content_hash': content_hash
                })
                
                if hash_matches:
                    return {
                        'is_duplicate': True,
                        'reason': f'Duplicata exata encontrada (hash match)',
                        'duplicate_id': str(hash_matches[0]._id)
                    }
            
            # Critério 2: Valor + Data + Descrição similar
            search_criteria = {
                'user_id': user_id,
                'amount': transaction['amount']
            }
            
            # Aplicar filtro de data com tolerância
            if transaction.get('normalized_datetime'):
                target_time = transaction['normalized_datetime']
                tolerance = timedelta(minutes=self.tolerance_config['time_tolerance_minutes'])
                
                search_criteria['date'] = {
                    '$gte': target_time - tolerance,
                    '$lte': target_time + tolerance
                }
            elif transaction.get('date'):
                # Usar apenas data se não tiver horário
                search_criteria['date'] = {
                    '$gte': datetime.strptime(transaction['date'], '%Y-%m-%d'),
                    '$lte': datetime.strptime(transaction['date'], '%Y-%m-%d') + timedelta(days=1)
                }
            
            potential_duplicates = Transaction.find_all(search_criteria)
            
            # Verificar similaridade de descrição
            transaction_desc = transaction.get('description', '').lower()
            
            for existing in potential_duplicates:
                existing_desc = existing.description.lower() if existing.description else ''
                
                if self._calculate_text_similarity(transaction_desc, existing_desc) >= self.tolerance_config['description_similarity_threshold']:
                    return {
                        'is_duplicate': True,
                        'reason': f'Duplicata encontrada - valor, data e descrição similares',
                        'duplicate_id': str(existing._id)
                    }
            
            return {'is_duplicate': False}
            
        except Exception as e:
            print(f"Erro na verificação de duplicata: {e}")
            return {'is_duplicate': False}

    def _check_order_reconciliation(self, transaction: Dict, user_id: str) -> Dict:
        """
        NÍVEL 2: Verificar reconciliação com pedidos do e-commerce
        """
        try:
            from models.order_mongo import Order
            
            # Buscar pedidos pendentes com valor similar
            amount_tolerance = transaction['amount'] * self.tolerance_config['amount_tolerance_percent']
            
            search_criteria = {
                'user_id': user_id,
                'status': 'pending',
                'total_amount': {
                    '$gte': transaction['amount'] - amount_tolerance,
                    '$lte': transaction['amount'] + amount_tolerance
                }
            }
            
            pending_orders = Order.find_all(search_criteria)
            
            if not pending_orders:
                return {'found_match': False}
            
            # Extrair nome do cliente da transação PIX
            client_name_from_pix = self._extract_client_name_from_pix(transaction)
            
            if not client_name_from_pix:
                return {'found_match': False}
            
            # Buscar correspondência com nomes de clientes
            for order in pending_orders:
                customer_name = order.customer_info.get('name', '').lower() if hasattr(order, 'customer_info') else ''
                
                if self._match_client_names(client_name_from_pix, customer_name):
                    # Confirmar pedido automaticamente
                    try:
                        order.status = 'confirmed'
                        order.payment_confirmation_date = datetime.now()
                        order.payment_method = 'pix'
                        order.save()
                        
                        print(f"TransactionReconciler: Pedido {order._id} confirmado automaticamente via PIX")
                        
                        return {
                            'found_match': True,
                            'reason': f'Reconciliado com Pedido #{str(order._id)[-6:]} - Cliente: {customer_name}',
                            'order_id': str(order._id),
                            'customer_name': customer_name,
                            'auto_confirmed': True
                        }
                    except Exception as e:
                        print(f"Erro ao confirmar pedido {order._id}: {e}")
                        
                        return {
                            'found_match': True,
                            'reason': f'Match encontrado com Pedido #{str(order._id)[-6:]} (erro na confirmação)',
                            'order_id': str(order._id),
                            'customer_name': customer_name,
                            'auto_confirmed': False
                        }
            
            return {'found_match': False}
            
        except Exception as e:
            print(f"Erro na verificação de reconciliação com pedidos: {e}")
            return {'found_match': False}

    def _check_potential_duplicate(self, transaction: Dict, user_id: str) -> Dict:
        """
        NÍVEL 3: Verificar potenciais duplicatas com menor precisão
        """
        try:
            from models.transaction_mongo import Transaction
            
            # Busca mais ampla por transações similares
            search_criteria = {
                'user_id': user_id,
                'type': transaction.get('type', 'expense')
            }
            
            # Tolerância maior para valores
            amount_tolerance = transaction['amount'] * 0.05  # 5% de tolerância
            search_criteria['amount'] = {
                '$gte': transaction['amount'] - amount_tolerance,
                '$lte': transaction['amount'] + amount_tolerance
            }
            
            # Tolerância maior para datas (3 dias)
            if transaction.get('date'):
                base_date = datetime.strptime(transaction['date'], '%Y-%m-%d')
                search_criteria['date'] = {
                    '$gte': base_date - timedelta(days=3),
                    '$lte': base_date + timedelta(days=3)
                }
            
            similar_transactions = Transaction.find_all(search_criteria)
            
            transaction_desc = transaction.get('description', '').lower()
            
            for existing in similar_transactions:
                existing_desc = existing.description.lower() if existing.description else ''
                
                similarity_score = self._calculate_text_similarity(transaction_desc, existing_desc)
                
                # Limiar menor para potenciais duplicatas
                if similarity_score >= 0.6:  # 60% de similaridade
                    return {
                        'is_potential': True,
                        'reason': f'Potencial duplicata - similaridade de {similarity_score:.0%}',
                        'similar_id': str(existing._id),
                        'score': similarity_score
                    }
            
            return {'is_potential': False}
            
        except Exception as e:
            print(f"Erro na verificação de potencial duplicata: {e}")
            return {'is_potential': False}

    def _post_process_reconciled_transactions(self, transactions: List[Dict], user_id: str) -> List[Dict]:
        """
        Pós-processamento das transações reconciliadas
        """
        processed = []
        
        for transaction in transactions:
            try:
                # Aplicar melhorias finais na categorização
                transaction = self._refine_categorization(transaction)
                
                # Adicionar metadados de processamento
                transaction['processed_at'] = datetime.now().isoformat()
                transaction['processor_version'] = '2.0_advanced'
                
                # Calcular score final de qualidade
                transaction['final_quality_score'] = self._calculate_final_quality_score(transaction)
                
                processed.append(transaction)
                
            except Exception as e:
                print(f"Erro no pós-processamento da transação: {e}")
                processed.append(transaction)
        
        return processed

    def _refine_categorization(self, transaction: Dict) -> Dict:
        """
        Refinamento final da categorização baseado em contexto adicional
        """
        # Se já foi categorizada adequadamente, manter
        current_category = transaction.get('category', 'Outros')
        if current_category != 'Outros' and current_category in [cat for cat in self.advanced_categories.keys()]:
            return transaction
        
        # Análise contextual adicional para categorias não identificadas
        description = transaction.get('description', '').lower()
        amount = transaction.get('amount', 0)
        transaction_type = transaction.get('type', 'expense')
        
        # Regras especiais para valores altos
        if amount > 3000:
            if transaction_type == 'expense':
                if any(word in description for word in ['aluguel', 'financiamento', 'empréstimo']):
                    transaction['category'] = 'Casa e Moradia'
                elif any(word in description for word in ['carro', 'veículo', 'auto']):
                    transaction['category'] = 'Transporte e Combustível'
                else:
                    transaction['category'] = 'Grandes Gastos'
            else:  # income
                transaction['category'] = 'Renda Principal'
        
        # Análise de padrões temporais (transações recorrentes)
        if self._is_recurring_pattern(transaction, description):
            if any(word in description for word in ['mensalidade', 'assinatura', 'plano']):
                transaction['category'] = 'Serviços Recorrentes'
        
        return transaction

    def _is_recurring_pattern(self, transaction: Dict, description: str) -> bool:
        """
        Detectar se a transação faz parte de um padrão recorrente
        """
        # Lógica simples - seria expandida com histórico de transações
        recurring_keywords = ['mensalidade', 'assinatura', 'plano', 'parcela', 'prestação']
        return any(keyword in description for keyword in recurring_keywords)

    def _calculate_final_quality_score(self, transaction: Dict) -> float:
        """
        Calcular score final de qualidade da transação processada
        """
        score = transaction.get('confidence_score', 0.5)
        
        # Bonus por reconciliação bem-sucedida
        if transaction.get('reconciliation_status') == 'reconciled_with_order':
            score += 0.2
        elif transaction.get('reconciliation_status') == 'new_transaction':
            score += 0.1
        
        # Bonus por categorização precisa
        category = transaction.get('category', 'Outros')
        if category != 'Outros':
            score += 0.15
        
        # Penalidade por potenciais problemas
        if transaction.get('reconciliation_status') == 'potential_match':
            score -= 0.1
        
        return min(score, 1.0)

    # MÉTODOS AUXILIARES AVANÇADOS
    
    def _generate_temp_id(self, transaction: Dict, index: int) -> str:
        """Gerar ID temporário único para rastreamento"""
        base_string = f"{transaction.get('amount', '')}{transaction.get('description', '')}{index}{datetime.now().microsecond}"
        return hashlib.md5(base_string.encode()).hexdigest()[:12]

    def _normalize_timestamp(self, timestamp_str: str) -> Optional[datetime]:
        """Normalizar timestamp com correção de fuso horário"""
        if not timestamp_str:
            return None
        
        try:
            formats = [
                '%d/%m/%Y %H:%M:%S',
                '%d/%m/%Y %H:%M',
                '%d-%m-%Y %H:%M:%S', 
                '%d-%m-%Y %H:%M',
                '%Y-%m-%d %H:%M:%S',
                '%Y-%m-%d %H:%M',
                '%d/%m/%Y',
                '%Y-%m-%d'
            ]
            
            timestamp_obj = None
            for fmt in formats:
                try:
                    timestamp_obj = datetime.strptime(timestamp_str.strip(), fmt)
                    break
                except ValueError:
                    continue
            
            if timestamp_obj:
                # Aplicar correção de fuso horário
                timezone_offset = getattr(Config, 'TIMEZONE_OFFSET_HOURS', -3.0)
                corrected_timestamp = timestamp_obj - timedelta(hours=timezone_offset)
                return corrected_timestamp
            
            return None
            
        except Exception as e:
            print(f"Erro ao normalizar timestamp {timestamp_str}: {e}")
            return None

    def _is_pix_transaction(self, transaction: Dict) -> bool:
        """Verificar se é uma transação PIX"""
        description = transaction.get('description', '').lower()
        return 'pix' in description or 'transferencia' in description

    def _extract_pix_info(self, transaction: Dict) -> Dict:
        """Extrair informações específicas de PIX"""
        description = transaction.get('description', '').lower()
        info = {'is_pix': True}
        
        # Detectar direção (recebido/enviado)
        if any(word in description for word in ['recebido', 'recebimento']):
            info['pix_direction'] = 'received'
            info['pix_type'] = 'income'
        else:
            info['pix_direction'] = 'sent'
            info['pix_type'] = 'expense'
        
        # Extrair nome do cliente/destinatário
        client_name = self._extract_client_name_from_pix(transaction)
        if client_name:
            info['pix_client_name'] = client_name
        
        return info

    def _extract_client_name_from_pix(self, transaction: Dict) -> Optional[str]:
        """Extrair nome do cliente de uma transação PIX"""
        description = transaction.get('description', '')
        
        if transaction.get('pix_direction') == 'received':
            patterns = self.pix_patterns['received']
        else:
            patterns = self.pix_patterns['sent']
        
        for pattern in patterns:
            match = re.search(pattern, description, re.IGNORECASE)
            if match:
                name = match.group(1).strip()
                # Limpar e normalizar nome
                name = re.sub(r'[^\w\s]', '', name)
                if len(name) > 2:
                    return name.title()
        
        return None

    def _generate_content_hash(self, transaction: Dict) -> str:
        """Gerar hash único baseado no conteúdo da transação"""
        content_parts = [
            str(transaction.get('amount', '')),
            transaction.get('description', '').lower().strip(),
            transaction.get('date', ''),
            transaction.get('type', '')
        ]
        
        content_string = '|'.join(content_parts)
        return hashlib.sha256(content_string.encode()).hexdigest()

    def _estimate_confidence(self, transaction: Dict) -> float:
        """Estimar nível de confiança da transação"""
        confidence = 0.5  # Base
        
        # Bonus por qualidade dos dados
        if transaction.get('amount') and transaction.get('amount') > 0:
            confidence += 0.2
        
        if transaction.get('description') and len(transaction.get('description', '')) > 5:
            confidence += 0.2
        
        if transaction.get('date'):
            confidence += 0.1
        
        if transaction.get('normalized_datetime'):
            confidence += 0.1
        
        return min(confidence, 1.0)

    def _calculate_text_similarity(self, text1: str, text2: str) -> float:
        """Calcular similaridade entre dois textos"""
        if not text1 or not text2:
            return 0.0
        
        # Normalizar textos
        text1 = re.sub(r'[^\w\s]', '', text1.lower())
        text2 = re.sub(r'[^\w\s]', '', text2.lower())
        
        # Comparação exata
        if text1 == text2:
            return 1.0
        
        # Verificar substring
        if text1 in text2 or text2 in text1:
            return 0.8
        
        # Comparação por palavras
        words1 = set(text1.split())
        words2 = set(text2.split())
        
        if len(words1) == 0 or len(words2) == 0:
            return 0.0
        
        intersection = words1.intersection(words2)
        union = words1.union(words2)
        
        return len(intersection) / len(union) if len(union) > 0 else 0.0

    def _match_client_names(self, pix_name: str, customer_name: str) -> bool:
        """Verificar se nomes de cliente são compatíveis"""
        if not pix_name or not customer_name:
            return False
        
        # Normalizar nomes
        pix_words = set(pix_name.lower().split())
        customer_words = set(customer_name.lower().split())
        
        # Remover palavras muito comuns
        common_words = {'de', 'da', 'do', 'dos', 'das', 'e', 'silva', 'santos', 'oliveira'}
        pix_words = pix_words - common_words
        customer_words = customer_words - common_words
        
        if len(pix_words) == 0 or len(customer_words) == 0:
            return False
        
        # Verificar se pelo menos uma palavra coincide
        intersection = pix_words.intersection(customer_words)
        return len(intersection) >= 1

    def _generate_detailed_report(self, stats: Dict, transactions: List[Dict]) -> Dict:
        """Gerar relatório detalhado da reconciliação"""
        report = {
            'processing_statistics': stats,
            'transaction_breakdown': {
                'by_status': self._count_by_status(transactions),
                'by_category': self._count_by_category(transactions),
                'by_amount_range': self._count_by_amount_range(transactions)
            },
            'quality_metrics': {
                'average_confidence': self._calculate_average_confidence(transactions),
                'high_quality_transactions': len([t for t in transactions if t.get('final_quality_score', 0) > 0.8]),
                'flagged_for_review': len([t for t in transactions if t.get('reconciliation_status') == 'potential_match'])
            },
            'reconciliation_efficiency': {
                'success_rate': (stats.get('new_transactions', 0) + stats.get('reconciled_with_orders', 0)) / max(stats.get('total_processed', 1), 1) * 100,
                'duplicate_prevention_rate': stats.get('ignored_duplicates', 0) / max(stats.get('total_processed', 1), 1) * 100,
                'order_reconciliation_rate': stats.get('reconciled_with_orders', 0) / max(stats.get('total_processed', 1), 1) * 100
            }
        }
        
        return report

    def _count_by_status(self, transactions: List[Dict]) -> Dict:
        """Contar transações por status de reconciliação"""
        status_count = {}
        for transaction in transactions:
            status = transaction.get('reconciliation_status', 'unknown')
            status_count[status] = status_count.get(status, 0) + 1
        return status_count

    def _count_by_category(self, transactions: List[Dict]) -> Dict:
        """Contar transações por categoria"""
        category_count = {}
        for transaction in transactions:
            category = transaction.get('category', 'Outros')
            category_count[category] = category_count.get(category, 0) + 1
        return category_count

    def _count_by_amount_range(self, transactions: List[Dict]) -> Dict:
        """Contar transações por faixa de valor"""
        ranges = {
            '0-50': 0,
            '51-200': 0,
            '201-500': 0,
            '501-1000': 0,
            '1001-5000': 0,
            '5000+': 0
        }
        
        for transaction in transactions:
            amount = transaction.get('amount', 0)
            if amount <= 50:
                ranges['0-50'] += 1
            elif amount <= 200:
                ranges['51-200'] += 1
            elif amount <= 500:
                ranges['201-500'] += 1
            elif amount <= 1000:
                ranges['501-1000'] += 1
            elif amount <= 5000:
                ranges['1001-5000'] += 1
            else:
                ranges['5000+'] += 1
        
        return ranges

    def _calculate_average_confidence(self, transactions: List[Dict]) -> float:
        """Calcular confiança média das transações"""
        if not transactions:
            return 0.0
        
        total_confidence = sum(t.get('final_quality_score', 0.5) for t in transactions)
        return total_confidence / len(transactions)

    def _generate_intelligent_recommendations(self, transactions: List[Dict], stats: Dict) -> List[Dict]:
        """Gerar recomendações inteligentes baseadas no processamento"""
        recommendations = []
        
        # Recomendação sobre duplicatas
        if stats.get('ignored_duplicates', 0) > 0:
            recommendations.append({
                'type': 'duplicate_prevention',
                'priority': 'medium',
                'message': f'{stats["ignored_duplicates"]} transações duplicadas foram automaticamente ignoradas.',
                'action': 'review_duplicate_policy',
                'details': 'Sistema de anti-duplicidade funcionando corretamente.'
            })
        
        # Recomendação sobre reconciliação
        if stats.get('reconciled_with_orders', 0) > 0:
            recommendations.append({
                'type': 'order_reconciliation',
                'priority': 'high',
                'message': f'{stats["reconciled_with_orders"]} transações foram automaticamente reconciliadas com pedidos.',
                'action': 'confirm_auto_reconciliation',
                'details': 'Pedidos foram automaticamente confirmados. Verifique se está correto.'
            })
        
        # Recomendação sobre categorização
        uncategorized = len([t for t in transactions if t.get('category') == 'Outros'])
        if uncategorized > 0:
            recommendations.append({
                'type': 'categorization_improvement',
                'priority': 'low',
                'message': f'{uncategorized} transações ficaram na categoria "Outros".',
                'action': 'improve_categorization_rules',
                'details': 'Considere adicionar novas regras de categorização.'
            })
        
        # Recomendação sobre qualidade
        low_quality = len([t for t in transactions if t.get('final_quality_score', 0) < 0.6])
        if low_quality > len(transactions) * 0.2:  # Mais de 20% com baixa qualidade
            recommendations.append({
                'type': 'data_quality',
                'priority': 'medium',
                'message': f'{low_quality} transações têm baixa qualidade de dados.',
                'action': 'review_extraction_quality',
                'details': 'Verifique a qualidade do documento original ou ajuste parâmetros de extração.'
            })
        
        return recommendations

    def get_reconciliation_statistics(self, user_id: Optional[str] = None) -> Dict:
        """Obter estatísticas gerais de reconciliação para um usuário"""
        try:
            from models.transaction_mongo import Transaction
            
            if not user_id:
                return {'error': 'user_id é obrigatório'}
            
            # Estatísticas dos últimos 30 dias
            thirty_days_ago = datetime.now() - timedelta(days=30)
            
            recent_transactions = Transaction.find_all({
                'user_id': user_id,
                'date': {'$gte': thirty_days_ago}
            })
            
            stats = {
                'period': '30_days',
                'total_transactions': len(recent_transactions),
                'by_reconciliation_status': {},
                'by_category': {},
                'quality_metrics': {
                    'average_confidence': 0,
                    'high_quality_count': 0
                }
            }
            
            # Contar por status
            for transaction in recent_transactions:
                status = getattr(transaction, 'reconciliation_status', 'unknown')
                stats['by_reconciliation_status'][status] = stats['by_reconciliation_status'].get(status, 0) + 1
                
                category = getattr(transaction, 'category', 'Outros')
                stats['by_category'][category] = stats['by_category'].get(category, 0) + 1
            
            # Calcular qualidade média
            if recent_transactions:
                confidence_scores = [getattr(t, 'final_quality_score', 0.5) for t in recent_transactions]
                stats['quality_metrics']['average_confidence'] = sum(confidence_scores) / len(confidence_scores)
                stats['quality_metrics']['high_quality_count'] = len([s for s in confidence_scores if s > 0.8])
            
            return stats
            
        except Exception as e:
            return {'error': f'Erro ao obter estatísticas: {str(e)}'}

    def cleanup_cache(self):
        """Limpar cache de usuário"""
        current_time = datetime.now().timestamp()
        
        # Remover entradas antigas do cache
        expired_keys = []
        for user_id, cache_data in self._user_cache.items():
            if current_time - cache_data.get('timestamp', 0) > self._cache_ttl:
                expired_keys.append(user_id)
        
        for key in expired_keys:
            del self._user_cache[key]
        
        print(f"TransactionReconciler: Cache limpo - {len(expired_keys)} entradas removidas")
