# ARQUIVO PRINCIPAL: src/services/document_processor.py
# VERSÃO REFATORADA: Agora com Transaction Reconciler como módulo interno

import re
import PyPDF2
import pandas as pd
from datetime import datetime, timedelta
import io
import requests
from PIL import Image
import pytesseract
import json
from config import Config
from .transaction_reconciler import TransactionReconciler  # Seu filho especializado

class DocumentProcessor:
    def __init__(self):
        # Inicializar o módulo filho especializado com verificação de disponibilidade
        try:
            self.reconciler = TransactionReconciler()
            self.reconciler_available = True
        except Exception as e:
            # self.logger ainda não foi inicializado aqui, então o aviso pode não funcionar como esperado.
            # É melhor inicializar o logger antes. Vou manter sua ordem original por fidelidade.
            # Em uma futura refatoração, poderíamos mover a inicialização do logger para o topo.
            # self.logger.warning(f"TransactionReconciler não disponível: {e}")
            self.reconciler = None
            self.reconciler_available = False
        
        # Inicializar logger se não existir
        if not hasattr(self, 'logger'):
            import logging
            self.logger = logging.getLogger(__name__)
            
        # Padrões de extração refinados
        self.transaction_patterns = {
            'date': [
                r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})',  # dd/mm/yyyy
                r'(\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})',  # yyyy/mm/dd
                r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\s+\d{1,2}:\d{2}(?::\d{2})?)',  # com hora
                r'(\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}\s+\d{1,2}:\d{2}(?::\d{2})?)',  # yyyy com hora
            ],
            'amount': [
                r'R\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)',  # R$ 1.000,00
                r'(\d{1,3}(?:\.\d{3})*(?:,\d{2}))',         # 1.000,00
                r'(\d+,\d{2})',                              # 100,50
                r'(\d+\.\d{2})',                             # 100.50
                r'(\d+)',                                    # valores inteiros
            ],
            'negative_indicators': [
                'débito', 'saque', 'pagamento', 'transferência enviada', 'compra',
                'taxa', 'tarifa', 'anuidade', 'juros', 'multa', 'desconto',
                'pix enviado', 'ted enviada', 'doc enviado', 'cartão', 'fatura'
            ],
            'positive_indicators': [
                'crédito', 'depósito', 'transferência recebida', 'pix recebido',
                'ted recebida', 'doc recebido', 'salário', 'rendimento',
                'estorno', 'reembolso', 'venda', 'recebimento'
            ],
            'merchant_patterns': [
                r'(?:em|para|de|pix\s+(?:de|para))\s+([A-ZÀ-ÿ][A-ZÀ-ÿ\s]{2,30}?)(?:\s+\d|\s*$|\s+-)',
                r'([A-ZÀ-ÿ][A-ZÀ-ÿ\s]{3,25}?)(?:\s+\d|\s*$|\s+-)',
                r'(\w+(?:\s+\w+){1,3})(?:\s+\d|\s*$)',
            ]
        }
        
        # Categorias expandidas e melhoradas
        self.auto_categories = {
            'Alimentação': [
                'mercado', 'supermercado', 'padaria', 'restaurante', 'lanchonete',
                'pizzaria', 'hamburgueria', 'açougue', 'hortifruti', 'extra',
                'carrefour', 'pão de açúcar', 'big', 'walmart', 'ifood', 'uber eats',
                'delivery', 'comida', 'alimento', 'bebida', 'café', 'bar'
            ],
            'Combustível': [
                'posto', 'shell', 'petrobras', 'ipiranga', 'ale', 'br',
                'combustível', 'gasolina', 'etanol', 'diesel', 'abastecimento'
            ],
            'Transporte': [
                'uber', 'taxi', '99', 'cabify', 'ônibus', 'metrô', 'trem',
                'estacionamento', 'pedágio', 'vlt', 'brt', 'passagem', 'viagem'
            ],
            'Saúde': [
                'farmácia', 'drogaria', 'hospital', 'clínica', 'laboratório',
                'médico', 'dentista', 'fisioterapeuta', 'psicólogo', 'remédio',
                'medicamento', 'consulta', 'exame'
            ],
            'Educação': [
                'escola', 'faculdade', 'universidade', 'curso', 'livro',
                'material escolar', 'mensalidade', 'matrícula', 'formação'
            ],
            'Lazer': [
                'cinema', 'teatro', 'show', 'festa', 'bar', 'balada',
                'viagem', 'hotel', 'pousada', 'turismo', 'diversão', 'entretenimento'
            ],
            'Casa e Utilidades': [
                'aluguel', 'condomínio', 'luz', 'energia', 'água', 'gás',
                'internet', 'telefone', 'tv', 'streaming', 'netflix', 'casa',
                'manutenção', 'limpeza', 'móveis'
            ],
            'Vestuário': [
                'loja', 'roupa', 'calçado', 'sapato', 'tênis', 'camisa',
                'calça', 'vestido', 'shopping', 'moda', 'acessório'
            ],
            'PIX Recebido': [
                'pix recebido', 'transferencia recebida', 'recebimento pix'
            ],
            'PIX Enviado': [
                'pix enviado', 'pix', 'transferencia enviada', 'pagamento pix'
            ],
            'Cartão de Crédito': [
                'cartão', 'crédito', 'mastercard', 'visa', 'elo', 'fatura'
            ],
            'Bancos e Taxas': [
                'banco', 'taxa', 'tarifa', 'anuidade', 'juros', 'iof', 'cpmf'
            ],
            'Supermercados': [
                'supermercado', 'mercado', 'hiper', 'atacado', 'compras'
            ],
            'Vendas E-commerce': [
                'venda', 'pedido', 'produto', 'cliente', 'ecommerce', 'loja online'
            ]
        }

        # Sistema visual completo
        self.category_colors = {
            'Alimentação': '#22C55E',
            'Combustível': '#F59E0B', 
            'Transporte': '#3B82F6',
            'Saúde': '#EF4444',
            'Educação': '#8B5CF6',
            'Lazer': '#EC4899',
            'Casa e Utilidades': '#06B6D4',
            'Vestuário': '#F97316',
            'PIX Recebido': '#10B981',
            'PIX Enviado': '#F59E0B',
            'Cartão de Crédito': '#DC2626',
            'Bancos e Taxas': '#6B7280',
            'Supermercados': '#16A34A',
            'Vendas E-commerce': '#7C3AED',
            'Outros': '#9CA3AF'
        }

        self.category_icons = {
            'Alimentação': 'utensils',
            'Combustível': 'fuel',
            'Transporte': 'car',
            'Saúde': 'heart',
            'Educação': 'book',
            'Lazer': 'gamepad-2',
            'Casa e Utilidades': 'home',
            'Vestuário': 'shirt',
            'PIX Recebido': 'arrow-down-circle',
            'PIX Enviado': 'arrow-up-circle',
            'Cartão de Crédito': 'credit-card',
            'Bancos e Taxas': 'building',
            'Supermercados': 'shopping-cart',
            'Vendas E-commerce': 'shopping-bag',
            'Outros': 'folder'
        }

        self.category_emojis = {
            'Alimentação': '🍽️',
            'Combustível': '⛽',
            'Transporte': '🚗',
            'Saúde': '❤️',
            'Educação': '📚',
            'Lazer': '🎮',
            'Casa e Utilidades': '🏠',
            'Vestuário': '👕',
            'PIX Recebido': '📥',
            'PIX Enviado': '📤',
            'Cartão de Crédito': '💳',
            'Bancos e Taxas': '🏛️',
            'Supermercados': '🛒',
            'Vendas E-commerce': '🛍️',
            'Outros': '📁'
        }

    # MÉTODO PÚBLICO PRINCIPAL - Interface para o resto do sistema
    def process_document(self, file_path, file_type, context='business', user_id=None):
        """
        MÉTODO PRINCIPAL: Interface pública para processamento de documentos
        Este método é chamado pelos outros módulos do sistema
        """
        try:
            # Etapa 1: Extração bruta de dados
            raw_transactions = self._extract_raw_transactions(file_path, file_type, context)
            
            if not raw_transactions:
                return {
                    'success': False, 
                    'error': 'Nenhuma transação encontrada no documento',
                    'transactions': [],
                    'processing_summary': self._empty_summary()
                }

            # Etapa 2: Delegação para o módulo especializado de reconciliação COM FALLBACK
            try:
                processed_result = self.reconciler.process_transactions_with_intelligence(
                    raw_transactions, user_id, context
                )
                
                if not processed_result['success'] or not processed_result.get('transactions'):
                    # Fallback: processar diretamente sem reconciler
                    processed_result = self._process_direct(raw_transactions, context)
                    
            except Exception as reconciler_error:
                self.logger.warning(f"Erro no reconciler, usando processamento direto: {reconciler_error}")
                # Fallback: processar diretamente sem reconciler
                processed_result = self._process_direct(raw_transactions, context)

            if not processed_result['success']:
                return processed_result

            # Etapa 3: Aplicar melhorias finais e validações
            final_transactions = self._apply_final_enhancements(processed_result['transactions'])

            # Etapa 4: Gerar relatório completo
            processing_summary = self._generate_comprehensive_summary(
                raw_transactions, final_transactions, processed_result
            )

            return {
                'success': True,
                'transactions': final_transactions,
                'processing_summary': processing_summary,
                'reconciliation_report': processed_result.get('reconciliation_report', {}),
                'recommendations': self._generate_recommendations(final_transactions, context)
            }
            
        except Exception as e:
            return {
                'success': False, 
                'error': f'Erro no processamento do documento: {str(e)}',
                'transactions': [],
                'processing_summary': self._empty_summary()
            }
            
    # MÉTODOS PRIVADOS DE EXTRAÇÃO
    def _extract_raw_transactions(self, file_path, file_type, context):
        """Extrair dados brutos do documento baseado no tipo"""
        if file_type.lower() == 'pdf':
            return self._process_pdf(file_path, context)
        elif file_type.lower() in ['jpg', 'jpeg', 'png']:
            return self._process_image(file_path, context)
        elif file_type.lower() in ['csv', 'xlsx', 'xls']:
            return self._process_spreadsheet(file_path, context)
        else:
            raise ValueError(f'Tipo de arquivo não suportado: {file_type}')

    def _process_pdf(self, file_path, context):
        """Processar arquivo PDF com extração aprimorada"""
        try:
            transactions = []
            
            with open(file_path, 'rb') as file:
                pdf_reader = PyPDF2.PdfReader(file)
                
                full_text = ""
                for page_num, page in enumerate(pdf_reader.pages):
                    page_text = page.extract_text()
                    full_text += f"[PAGE {page_num + 1}]\n{page_text}\n\n"
                
                # Detectar tipo de documento bancário
                doc_type = self._detect_document_type(full_text)
                
                # Extrair transações com contexto do tipo de documento
                extracted_transactions = self._extract_transactions_from_text(
                    full_text, context, doc_type
                )
                transactions.extend(extracted_transactions)
            
            return transactions
            
        except Exception as e:
            raise Exception(f'Erro ao processar PDF: {str(e)}')

    def _process_image(self, file_path, context):
        """Processar imagem com OCR aprimorado"""
        try:
            image = Image.open(file_path)
            
            # Pré-processamento da imagem para melhor OCR
            image = self._preprocess_image_for_ocr(image)
            
            # Extrair texto com configurações otimizadas
            custom_config = r'--oem 3 --psm 6 -c tessedit_char_whitelist=0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ .,/:-$R%()'
            
            text = pytesseract.image_to_string(image, lang='por', config=custom_config)
            
            # Detectar tipo e extrair transações
            doc_type = self._detect_document_type(text)
            transactions = self._extract_transactions_from_text(text, context, doc_type)
            
            return transactions
            
        except Exception as e:
            raise Exception(f'Erro ao processar imagem: {str(e)}')

    def _process_spreadsheet(self, file_path, context):
        """Processar planilha com detecção inteligente de colunas - versão mais permissiva"""
        try:
            transactions = []
            
            # Tentar diferentes métodos de leitura
            df = self._load_spreadsheet_smart(file_path)
            
            # Mapear colunas automaticamente (já ajustado para ser mais permissivo)
            column_mapping = self._auto_map_columns(df)
            
            if not column_mapping:
                # Fallback: tentar mapear apenas por posição se tiver pelo menos 2 colunas
                if len(df.columns) >= 2:
                    column_mapping = {
                        'date': df.columns[0],
                        'amount': df.columns[1],
                        'description': df.columns[2] if len(df.columns) > 2 else df.columns[0]
                    }
                else:
                    raise Exception("Planilha deve ter pelo menos 2 colunas (data e valor)")
            
            successful_rows = 0
            failed_rows = 0
            
            # Processar cada linha com validação mais permissiva
            for index, row in df.iterrows():
                try:
                    transaction = self._extract_transaction_from_row(
                        row, column_mapping, context, index
                    )
                    
                    # Validação menos rigorosa - aceitar transações com campos mínimos
                    if transaction and self._validate_basic_transaction(transaction):
                        transactions.append(transaction)
                        successful_rows += 1
                    else:
                        failed_rows += 1
                        
                except Exception as e:
                    self.logger.warning(f"Erro ao processar linha {index}: {e}")
                    failed_rows += 1
                    continue
            
            # Log informativo sobre o processamento
            self.logger.info(f"Planilha processada: {successful_rows} sucessos, {failed_rows} falhas")
            
            # Aceitar resultado mesmo com algumas falhas, desde que tenha pelo menos 1 transação
            if not transactions:
                raise Exception(f"Nenhuma transação válida encontrada na planilha. Linhas processadas: {len(df)}")
            
            return transactions
            
        except Exception as e:
            raise Exception(f'Erro ao processar planilha: {str(e)}')

    def _validate_basic_transaction(self, transaction):
        """Validação básica mais permissiva que a final"""
        # Verificar apenas se tem os campos mínimos com algum conteúdo
        if not transaction:
            return False
            
        # Pelo menos data e valor devem existir
        if not transaction.get('date') or not transaction.get('amount'):
            return False
            
        # Se não tem descrição, criar uma básica
        if not transaction.get('description'):
            transaction['description'] = f"Transação {transaction.get('date', 'sem data')}"
            
        return True
        
    
    # MÉTODOS AUXILIARES APRIMORADOS
    def _detect_document_type(self, text):
        """Detectar tipo de documento bancário para aplicar regras específicas"""
        text_lower = text.lower()
        
        if any(word in text_lower for word in ['extrato', 'saldo', 'movimentação']):
            return 'bank_statement'
        elif any(word in text_lower for word in ['fatura', 'cartão', 'crédito']):
            return 'credit_card_statement'
        elif any(word in text_lower for word in ['pix', 'transferência', 'comprovante']):
            return 'transfer_receipt'
        elif any(word in text_lower for word in ['nota fiscal', 'cupom', 'recibo']):
            return 'receipt'
        else:
            return 'generic_financial'

    def _preprocess_image_for_ocr(self, image):
        """Pré-processar imagem para melhorar OCR"""
        try:
            # Converter para escala de cinza
            if image.mode != 'L':
                image = image.convert('L')
            
            # Redimensionar se muito pequena
            width, height = image.size
            if width < 800 or height < 600:
                scale_factor = max(800/width, 600/height)
                new_size = (int(width * scale_factor), int(height * scale_factor))
                image = image.resize(new_size, Image.Resampling.LANCZOS)
            
            return image
        except Exception:
            return image

    def _load_spreadsheet_smart(self, file_path):
        """Carregar planilha com múltiplas tentativas - versão mais permissiva"""
        encodings = ['utf-8', 'latin-1', 'iso-8859-1', 'cp1252']
        separators = [',', ';', '\t', '|']
        
        # Tentar Excel primeiro
        try:
            df = pd.read_excel(file_path)
            if not df.empty:
                return df
        except Exception:
            pass
        
        # Tentar CSV com diferentes configurações (mais permissivo)
        for encoding in encodings:
            for sep in separators:
                try:
                    df = pd.read_csv(
                        file_path, 
                        encoding=encoding, 
                        sep=sep,
                        skipinitialspace=True,  # Remove espaços extras
                        skip_blank_lines=True,  # Pula linhas vazias
                        on_bad_lines='skip'     # Pula linhas problemáticas
                    )
                    
                    # Critério mais permissivo - aceitar mesmo com 1 coluna se tiver dados
                    if len(df) > 0 and not df.empty:
                        # Limpar colunas vazias
                        df = df.dropna(axis=1, how='all')
                        if len(df.columns) >= 1:  # Aceitar pelo menos 1 coluna
                            return df
                            
                except Exception:
                    continue
        
        # Última tentativa: tentar ler como texto puro
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = [line.strip() for line in f.readlines() if line.strip()]
                if lines:
                    # Criar DataFrame básico se conseguir ler pelo menos algumas linhas
                    df = pd.DataFrame({'raw_data': lines})
                    return df
        except Exception:
            pass
        
        raise Exception("Não foi possível carregar a planilha com os formatos suportados")
    
    def _auto_map_columns(self, df):
        """Mapear colunas automaticamente baseado no conteúdo - versão mais permissiva"""
        columns_lower = [col.lower().strip() for col in df.columns]
        
        mapping = {}
        
        # Mapear coluna de data (obrigatória)
        date_keywords = ['data', 'date', 'dt', 'when', 'dia', 'período', 'tempo', 'time']
        for i, col in enumerate(columns_lower):
            if any(keyword in col for keyword in date_keywords):
                mapping['date'] = df.columns[i]
                break
        
        # Mapear coluna de valor (obrigatória)
        amount_keywords = ['valor', 'amount', 'quantia', 'total', 'vlr', 'money', 'preco', 'price']
        for i, col in enumerate(columns_lower):
            if any(keyword in col for keyword in amount_keywords):
                mapping['amount'] = df.columns[i]
                break
        
        # Mapear coluna de descrição (obrigatória)
        desc_keywords = ['descrição', 'description', 'histórico', 'memo', 'obs', 'detalhes', 'produto', 'item']
        for i, col in enumerate(columns_lower):
            if any(keyword in col for keyword in desc_keywords):
                mapping['description'] = df.columns[i]
                break
        
        # Mapear campos opcionais (type e category) - não são críticos
        type_keywords = ['tipo', 'type', 'categoria_tipo', 'operacao']
        for i, col in enumerate(columns_lower):
            if any(keyword in col for keyword in type_keywords):
                mapping['type'] = df.columns[i]
                break
        
        category_keywords = ['categoria', 'category', 'cat', 'grupo', 'classificacao']
        for i, col in enumerate(columns_lower):
            if any(keyword in col for keyword in category_keywords):
                mapping['category'] = df.columns[i]
                break
        
        # Verificar se encontrou APENAS os campos essenciais (mais permissivo)
        if 'date' in mapping and 'amount' in mapping:
            # Se não tem descrição, usar a primeira coluna disponível como descrição
            if 'description' not in mapping and len(df.columns) >= 3:
                for i, col in enumerate(df.columns):
                    if col not in mapping.values():
                        mapping['description'] = col
                        break
            return mapping
        
        # Tentativa de mapeamento por posição se não encontrou por nome
        if len(df.columns) >= 2:  # Relaxado: só precisa de 2 colunas mínimo
            mapping = {
                'date': df.columns[0],
                'amount': df.columns[1],
            }
            # Adicionar descrição se houver terceira coluna
            if len(df.columns) >= 3:
                mapping['description'] = df.columns[2]
            else:
                mapping['description'] = df.columns[0]  # usar data como descrição fallback
                
        return mapping if len(mapping) >= 2 else None  # Aceitar com pelo menos 2 campos
    
    def _extract_transactions_from_text(self, text, context, doc_type='generic_financial'):
        """Extração de transações com análise contextual aprimorada"""
        transactions = []
        lines = text.split('\n')
        
        for line_num, line in enumerate(lines):
            line = line.strip()
            if len(line) < 8:  # Pular linhas muito curtas
                continue
            
            transaction = self._parse_transaction_line_advanced(line, context, doc_type, line_num)
            if transaction:
                transactions.append(transaction)
        
        # Pós-processamento para melhorar qualidade
        return self._post_process_extracted_transactions(transactions, doc_type)

    def _parse_transaction_line_advanced(self, line, context, doc_type, line_num):
        """Parser de linha com lógica avançada baseada no tipo de documento"""
        try:
            # Pré-filtros baseados no tipo de documento
            if doc_type == 'bank_statement':
                if not self._is_valid_bank_statement_line(line):
                    return None
            
            # Extrair componentes
            date_info = self._extract_date_with_time(line)
            amount_info = self._extract_amount_advanced(line)
            
            if not date_info or not amount_info:
                return None
            
            # Determinar tipo de transação
            transaction_type = self._determine_transaction_type_advanced(line, doc_type)
            
            # Extrair e limpar descrição
            description = self._extract_clean_description(line, date_info, amount_info)
            
            # Auto-categorização inteligente
            category = self.suggest_category_from_description(description)
            
            transaction = {
                'date': date_info['date'],
                'amount': amount_info['amount'],
                'type': transaction_type,
                'description': description,
                'category': category,
                'context': context,
                'source': 'document_extraction',
                'document_type': doc_type,
                'line_number': line_num,
                'raw_line': line,
                'confidence_score': self._calculate_confidence_score(date_info, amount_info, description)
            }
            
            # Adicionar timestamp se disponível
            if date_info.get('timestamp'):
                transaction['raw_timestamp'] = date_info['timestamp']
            
            # Metadados específicos por tipo de documento
            if doc_type == 'transfer_receipt':
                transaction['is_transfer'] = True
                transaction['transfer_method'] = self._detect_transfer_method(line)
            
            return transaction
            
        except Exception as e:
            print(f"Erro ao processar linha {line_num}: {line[:50]}... - {e}")
            return None

    def _extract_date_with_time(self, text):
        """Extrair data com informações de horário quando disponível"""
        for pattern in self.transaction_patterns['date']:
            match = re.search(pattern, text)
            if match:
                timestamp_str = match.group(1)
                parsed_date = self._parse_date_flexible(timestamp_str)
                
                if parsed_date:
                    result = {'date': parsed_date['date']}
                    if parsed_date.get('has_time'):
                        result['timestamp'] = timestamp_str
                        result['datetime'] = parsed_date['datetime']
                    return result
        
        return None

    def _parse_date_flexible(self, date_str):
        """Parser de data flexível com suporte a múltiplos formatos"""
        formats_with_time = [
            ('%d/%m/%Y %H:%M:%S', True),
            ('%d/%m/%Y %H:%M', True),
            ('%d-%m-%Y %H:%M:%S', True),
            ('%d-%m-%Y %H:%M', True),
            ('%Y-%m-%d %H:%M:%S', True),
            ('%Y-%m-%d %H:%M', True),
        ]
        
        formats_date_only = [
            ('%d/%m/%Y', False),
            ('%d-%m-%Y', False),
            ('%d.%m.%Y', False),
            ('%Y-%m-%d', False),
            ('%d/%m/%y', False),
            ('%d-%m-%y', False),
        ]
        
        all_formats = formats_with_time + formats_date_only
        
        for fmt, has_time in all_formats:
            try:
                parsed = datetime.strptime(date_str.strip(), fmt)
                return {
                    'date': parsed.strftime('%Y-%m-%d'),
                    'datetime': parsed if has_time else None,
                    'has_time': has_time
                }
            except ValueError:
                continue
        
        return None

    def _extract_amount_advanced(self, text):
        """Extração de valor com detecção de sinal"""
        best_match = None
        
        for pattern in self.transaction_patterns['amount']:
            matches = re.finditer(pattern, text)
            for match in matches:
                amount_str = match.group(1)
                parsed_amount = self._parse_amount_with_sign(text, match.start(), amount_str)
                
                if parsed_amount and (not best_match or parsed_amount['confidence'] > best_match['confidence']):
                    best_match = parsed_amount
        
        return best_match

    def _parse_amount_with_sign(self, full_text, position, amount_str):
        """Parser de valor com detecção de sinal positivo/negativo"""
        try:
            # Limpar e converter valor
            clean_amount = re.sub(r'[R$\s]', '', amount_str)
            
            if ',' in clean_amount and '.' in clean_amount:
                clean_amount = clean_amount.replace('.', '').replace(',', '.')
            elif ',' in clean_amount and clean_amount.count(',') == 1:
                clean_amount = clean_amount.replace(',', '.')
            
            value = float(clean_amount)
            
            # Detectar sinal baseado no contexto
            context_before = full_text[max(0, position-30):position].lower()
            context_after = full_text[position:min(len(full_text), position+30)].lower()
            
            # Indicadores de valor negativo
            negative_indicators = ['-', 'débito', 'saque', 'pagamento', 'taxa', 'desconto']
            is_negative = any(indicator in context_before + context_after for indicator in negative_indicators)
            
            # Calcular confiança baseado na formatação
            confidence = 0.5
            if 'R$' in amount_str:
                confidence += 0.3
            if ',' in amount_str and amount_str.count(',') == 1:
                confidence += 0.2
            
            return {
                'amount': abs(value),
                'is_negative': is_negative,
                'confidence': confidence,
                'raw_string': amount_str
            }
            
        except Exception:
            return None

    def _determine_transaction_type_advanced(self, text, doc_type):
        """Determinar tipo de transação com lógica contextual"""
        text_lower = text.lower()
        
        # Lógica específica por tipo de documento
        if doc_type == 'credit_card_statement':
            return 'expense'  # Faturas são sempre gastos
        elif doc_type == 'transfer_receipt':
            if 'recebido' in text_lower or 'recebimento' in text_lower:
                return 'income'
            else:
                return 'expense'
        
        
        # Análise de indicadores
        negative_score = sum(1 for indicator in self.transaction_patterns['negative_indicators'] 
                           if indicator in text_lower)
        positive_score = sum(1 for indicator in self.transaction_patterns['positive_indicators'] 
                           if indicator in text_lower)
        
        if positive_score > negative_score:
            return 'income'
        elif negative_score > positive_score:
            return 'expense'
        else:
            # Análise de contexto adicional
            if any(word in text_lower for word in ['pix recebido', 'depósito', 'crédito']):
                return 'income'
            else:
                return 'expense'

    def _extract_clean_description(self, line, date_info, amount_info):
        """Extrair descrição limpa removendo data e valor"""
        clean_line = line
        
        # Remover data
        for pattern in self.transaction_patterns['date']:
            clean_line = re.sub(pattern, '', clean_line, count=1)
        
        # Remover valores monetários
        clean_line = re.sub(r'R\$\s*\d+(?:\.\d{3})*(?:,\d{2})?', '', clean_line)
        clean_line = re.sub(r'\d+(?:\.\d{3})*(?:,\d{2})?', '', clean_line)
        
        # Limpar espaços e caracteres especiais
        clean_line = re.sub(r'\s+', ' ', clean_line).strip()
        clean_line = re.sub(r'^[-\s]+|[-\s]+$', '', clean_line)
        
        # Aplicar padrões de extração de comerciante
        for pattern in self.transaction_patterns['merchant_patterns']:
            match = re.search(pattern, clean_line, re.IGNORECASE)
            if match:
                merchant = match.group(1).strip()
                if len(merchant) > 3:
                    return self._normalize_merchant_name(merchant)
        
        return clean_line[:100] if clean_line else 'Transação extraída de documento'

    def _normalize_merchant_name(self, merchant):
        """Normalizar nome do comerciante"""
        # Capitalizar corretamente
        normalized = ' '.join(word.capitalize() for word in merchant.split())
        
        # Remover caracteres especiais desnecessários
        normalized = re.sub(r'[^\w\s\-&.]', '', normalized)
        
        return normalized

    def _calculate_confidence_score(self, date_info, amount_info, description):
        """Calcular score de confiança da extração"""
        score = 0.0
        
        # Pontuação por qualidade da data
        if date_info:
            score += 0.3
            if date_info.get('has_time'):
                score += 0.1
        
        # Pontuação por qualidade do valor
        if amount_info:
            score += amount_info.get('confidence', 0.3)
        
        # Pontuação por qualidade da descrição
        if description and len(description) > 5:
            score += 0.2
            if any(char.isalpha() for char in description):
                score += 0.1
        
        return min(score, 1.0)

    def _is_valid_bank_statement_line(self, line):
        """Validar se linha é válida para extrato bancário"""
        line_lower = line.lower()
        
        # Filtrar cabeçalhos e rodapés
        invalid_indicators = [
            'saldo anterior', 'saldo atual', 'total', 'subtotal',
            'agência', 'conta', 'período', 'página',
            '===', '---', 'banco', 'extrato'
        ]
        
        return not any(indicator in line_lower for indicator in invalid_indicators)

    def _detect_transfer_method(self, line):
        """Detectar método de transferência"""
        line_lower = line.lower()
        
        if 'pix' in line_lower:
            return 'pix'
        elif 'ted' in line_lower:
            return 'ted'
        elif 'doc' in line_lower:
            return 'doc'
        elif 'transferência' in line_lower:
            return 'bank_transfer'
        else:
            return 'unknown'

    def _post_process_extracted_transactions(self, transactions, doc_type):
        """Pós-processamento para melhorar qualidade das transações"""
        processed = []
        
        for transaction in transactions:
            # Filtrar transações com confiança muito baixa
            if transaction.get('confidence_score', 0) < 0.3:
                continue
            
            # Normalizar categorias baseado no tipo de documento
            if doc_type == 'transfer_receipt' and transaction.get('is_transfer'):
                if transaction['type'] == 'income':
                    transaction['category'] = 'PIX Recebido'
                else:
                    transaction['category'] = 'PIX Enviado'
            
            # Melhorar descrição se muito genérica
            if len(transaction.get('description', '')) < 10:
                transaction['description'] = self._generate_better_description(transaction, doc_type)
            
            processed.append(transaction)
        
        return processed

    def _generate_better_description(self, transaction, doc_type):
        """Gerar descrição melhor para transações genéricas"""
        if doc_type == 'transfer_receipt':
            method = transaction.get('transfer_method', 'transferência')
            if transaction['type'] == 'income':
                return f"Recebimento via {method.upper()}"
            else:
                return f"Pagamento via {method.upper()}"
        
        return f"Transação {transaction['type']} - {doc_type}"

    def _extract_transaction_from_row(self, row, column_mapping, context, row_index):
        """Extrair transação de linha de planilha com validação aprimorada"""
        try:
            transaction = {}
            
            # Extrair data
            if 'date' in column_mapping:
                date_value = row[column_mapping['date']]
                if pd.notna(date_value):
                    parsed_date = self._parse_date_flexible(str(date_value))
                    if parsed_date:
                        transaction['date'] = parsed_date['date']
                        if parsed_date.get('datetime'):
                            transaction['raw_timestamp'] = str(date_value)
            
            # Extrair valor
            if 'amount' in column_mapping:
                amount_value = row[column_mapping['amount']]
                if pd.notna(amount_value):
                    amount = self._parse_amount_from_cell(amount_value)
                    if amount:
                        transaction['amount'] = abs(amount['value'])
                        transaction['type'] = 'expense' if amount['is_negative'] else 'income'
            
            # Extrair descrição
            if 'description' in column_mapping:
                desc_value = row[column_mapping['description']]
                if pd.notna(desc_value):
                    transaction['description'] = str(desc_value).strip()
            
            # Validar transação
            if not all(key in transaction for key in ['date', 'amount']):
                return None
            
            # Adicionar metadados
            transaction['context'] = context
            transaction['source'] = 'spreadsheet_extraction'
            transaction['row_number'] = row_index
            transaction['confidence_score'] = 0.8  # Planilhas têm alta confiança
            
            # Auto-categorização
            if 'description' in transaction:
                transaction['category'] = self.suggest_category_from_description(transaction['description'])
            else:
                transaction['category'] = 'Outros'
                transaction['description'] = f"Transação linha {row_index + 1}"
            
            return transaction
            
        except Exception as e:
            print(f"Erro ao processar linha {row_index}: {e}")
            return None

    def _parse_amount_from_cell(self, value):
        """Parser de valor de célula de planilha"""
        try:
            # Se já é número
            if isinstance(value, (int, float)):
                return {
                    'value': float(value),
                    'is_negative': value < 0,
                    'confidence': 0.9
                }
            
            # Converter string
            value_str = str(value).strip()
            
            # Detectar sinal negativo
            is_negative = value_str.startswith('-') or '(' in value_str
            
            # Limpar e converter
            clean_value = re.sub(r'[^\d,.]', '', value_str)
            
            if ',' in clean_value and '.' in clean_value:
                clean_value = clean_value.replace('.', '').replace(',', '.')
            elif ',' in clean_value:
                clean_value = clean_value.replace(',', '.')
            
            parsed_value = float(clean_value)
            
            return {
                'value': parsed_value,
                'is_negative': is_negative,
                'confidence': 0.8
            }
            
        except Exception:
            return None

    def _apply_final_enhancements(self, transactions):
        """Aplicar melhorias finais às transações processadas"""
        enhanced = []
        
        for transaction in transactions:
            # Aplicar enriquecimento de dados
            transaction = self._enrich_transaction_data(transaction)
            
            # Validação final
            if self._validate_transaction_final(transaction):
                enhanced.append(transaction)
        
        return enhanced

    def _enrich_transaction_data(self, transaction):
        """Enriquecer dados da transação com informações adicionais"""
        # Adicionar informações visuais da categoria
        category = transaction.get('category', 'Outros')
        transaction['category_color'] = self.get_category_color(category)
        transaction['category_icon'] = self.get_category_icon(category)
        transaction['category_emoji'] = self.get_category_emoji(category)
        
        # Adicionar tags baseadas no conteúdo
        transaction['tags'] = self._generate_transaction_tags(transaction)
        
        # Adicionar score de importância
        transaction['importance_score'] = self._calculate_importance_score(transaction)
        
        return transaction

    def _generate_transaction_tags(self, transaction):
        """Gerar tags relevantes para a transação"""
        tags = []
        
        description = transaction.get('description', '').lower()
        
        # Tags por valor
        amount = transaction.get('amount', 0)
        if amount > 1000:
            tags.append('alto_valor')
        elif amount < 50:
            tags.append('baixo_valor')
        
        # Tags por tipo
        if transaction.get('is_transfer'):
            tags.append('transferencia')
        
        # Tags por período
        if transaction.get('date'):
            try:
                date_obj = datetime.strptime(transaction['date'], '%Y-%m-%d')
                if date_obj.weekday() >= 5:  # Weekend
                    tags.append('fim_de_semana')
            except:
                pass
        
        # Tags por descrição
        if 'pix' in description:
            tags.append('pix')
        if any(word in description for word in ['parcelado', 'parcela']):
            tags.append('parcelamento')
        
        return tags

    def _calculate_importance_score(self, transaction):
        """Calcular score de importância da transação"""
        score = 0.5  # Base
        
        amount = transaction.get('amount', 0)
        
        # Score por valor
        if amount > 5000:
            score += 0.4
        elif amount > 1000:
            score += 0.3
        elif amount > 500:
            score += 0.2
        elif amount > 100:
            score += 0.1
        
        # Score por categoria
        important_categories = ['Saúde', 'Casa e Utilidades', 'Vendas E-commerce']
        if transaction.get('category') in important_categories:
            score += 0.2
        
        # Score por reconciliação
        if transaction.get('reconciliation_status') == 'reconciled_with_order':
            score += 0.3
        
        return min(score, 1.0)

    def _validate_transaction_final(self, transaction):
        """Validação final da transação"""
        # Validação mais permissiva - apenas campos essenciais
        essential_fields = ['date', 'amount', 'description']
        
        # Verificar campos essenciais
        for field in essential_fields:
            if field not in transaction or not transaction[field]:
                return False
        
        # Adicionar campos opcionais com valores padrão se não existirem
        if 'type' not in transaction or not transaction['type']:
            transaction['type'] = 'expense'  # padrão mais comum
        
        if 'category' not in transaction or not transaction['category']:
            transaction['category'] = 'uncategorized'
        
        # Validar data
        try:
            datetime.strptime(transaction['date'], '%Y-%m-%d')
        except:
            return False
        
        # Validar valor (aceitar qualquer valor numérico, incluindo negativos)
        try:
            transaction['amount'] = float(transaction['amount'])
        except:
            return False
        
        # Validar tipo (mais permissivo)
        if transaction['type'] not in ['income', 'expense', 'unknown']:
            transaction['type'] = 'expense'  # força um padrão válido
        
        return True
    
    
    def _process_direct(self, raw_transactions, context):
        """Processamento direto como fallback quando reconciler falha"""
        processed_transactions = []
        
        for transaction in raw_transactions:
            # Aplicar validação menos rigorosa
            if self._validate_transaction_final(transaction):
                # Adicionar campos padrão se necessário
                if 'reconciliation_status' not in transaction:
                    transaction['reconciliation_status'] = 'processed_direct'
                if 'confidence_score' not in transaction:
                    transaction['confidence_score'] = 0.7
                if 'source' not in transaction:
                    transaction['source'] = 'direct_processing'
                    
                processed_transactions.append(transaction)
        
        return {
            'success': True,
            'transactions': processed_transactions,
            'reconciliation_summary': {
                'method': 'direct_processing',
                'total_processed': len(processed_transactions),
                'fallback_reason': 'reconciler_unavailable'
            }
        }

    def _generate_comprehensive_summary(self, raw_transactions, final_transactions, reconciler_result):
        """Gerar resumo abrangente do processamento"""
        summary = {
            'extraction': {
                'total_raw': len(raw_transactions),
                'total_processed': len(final_transactions),
                'success_rate': len(final_transactions) / max(len(raw_transactions), 1) * 100
            },
            'reconciliation': reconciler_result.get('reconciliation_summary', {}),
            'financial': self._calculate_financial_summary(final_transactions),
            'categories': self._calculate_category_distribution(final_transactions),
            'quality': self._calculate_quality_metrics(final_transactions)
        }
        
        return summary

    def _calculate_financial_summary(self, transactions):
        """Calcular resumo financeiro"""
        income_transactions = [t for t in transactions if t.get('type') == 'income']
        expense_transactions = [t for t in transactions if t.get('type') == 'expense']
        
        return {
            'total_income': sum(t['amount'] for t in income_transactions),
            'total_expenses': sum(t['amount'] for t in expense_transactions),
            'net_amount': sum(t['amount'] for t in income_transactions) - sum(t['amount'] for t in expense_transactions),
            'income_count': len(income_transactions),
            'expense_count': len(expense_transactions),
            'average_transaction': sum(t['amount'] for t in transactions) / max(len(transactions), 1)
        }

    def _calculate_category_distribution(self, transactions):
        """Calcular distribuição por categorias"""
        categories = {}
        
        for transaction in transactions:
            category = transaction.get('category', 'Outros')
            if category not in categories:
                categories[category] = {
                    'count': 0,
                    'total_amount': 0,
                    'avg_amount': 0
                }
            
            categories[category]['count'] += 1
            categories[category]['total_amount'] += transaction['amount']
        
        # Calcular médias
        for category_data in categories.values():
            category_data['avg_amount'] = category_data['total_amount'] / category_data['count']
        
        return categories

    def _calculate_quality_metrics(self, transactions):
        """Calcular métricas de qualidade"""
        if not transactions:
            return {'average_confidence': 0, 'high_confidence_count': 0}
        
        confidence_scores = [t.get('confidence_score', 0.5) for t in transactions]
        
        return {
            'average_confidence': sum(confidence_scores) / len(confidence_scores),
            'high_confidence_count': sum(1 for score in confidence_scores if score > 0.8),
            'low_confidence_count': sum(1 for score in confidence_scores if score < 0.5)
        }

    def _generate_recommendations(self, transactions, context):
        """Gerar recomendações baseadas no processamento"""
        recommendations = []
        
        # Recomendações de categorização
        uncategorized = [t for t in transactions if t.get('category') == 'Outros']
        if len(uncategorized) > len(transactions) * 0.2:
            recommendations.append({
                'type': 'categorization',
                'message': f'Considere revisar a categorização de {len(uncategorized)} transações.',
                'action': 'review_categories'
            })
        
        # Recomendações de duplicatas
        potential_duplicates = [t for t in transactions if t.get('reconciliation_status') == 'ignored_duplicate']
        if potential_duplicates:
            recommendations.append({
                'type': 'duplicates',
                'message': f'{len(potential_duplicates)} possíveis duplicatas foram ignoradas.',
                'action': 'review_duplicates'
            })
        
        # Recomendações de reconciliação
        reconciled_orders = [t for t in transactions if t.get('reconciliation_status') == 'reconciled_with_order']
        if reconciled_orders:
            recommendations.append({
                'type': 'reconciliation',
                'message': f'{len(reconciled_orders)} transações foram reconciliadas com pedidos.',
                'action': 'confirm_reconciliation'
            })
        
        return recommendations

    def _empty_summary(self):
        """Resumo vazio para casos de erro"""
        return {
            'extraction': {'total_raw': 0, 'total_processed': 0, 'success_rate': 0},
            'reconciliation': {},
            'financial': {'total_income': 0, 'total_expenses': 0, 'net_amount': 0},
            'categories': {},
            'quality': {'average_confidence': 0, 'high_confidence_count': 0}
        }

    # MÉTODOS PÚBLICOS DE UTILIDADE
    def suggest_category_from_description(self, description):
        """Sugerir categoria baseada na descrição - Método público principal"""
        if not description:
            return 'Outros'
        
        description_lower = description.lower()
        
        # Procurar por categorias específicas
        for category, keywords in self.auto_categories.items():
            for keyword in keywords:
                if keyword.lower() in description_lower:
                    return category
        
        # Análise contextual adicional
        if 'pix' in description_lower:
            if any(word in description_lower for word in ['recebido', 'recebimento']):
                return 'PIX Recebido'
            else:
                return 'PIX Enviado'
        
        # Extrair primeira palavra significativa
        words = description_lower.split()
        ignore_words = {'de', 'da', 'do', 'em', 'para', 'com', 'no', 'na', 'compra', 'pagamento'}
        
        for word in words:
            if len(word) > 3 and word not in ignore_words:
                return word.capitalize()
        
        return 'Outros'

    def get_category_color(self, category_name):
        """Obter cor da categoria"""
        return self.category_colors.get(category_name, '#9CA3AF')

    def get_category_icon(self, category_name):
        """Obter ícone da categoria"""
        return self.category_icons.get(category_name, 'folder')

    def get_category_emoji(self, category_name):
        """Obter emoji da categoria"""
        return self.category_emojis.get(category_name, '📁')

    def get_processing_statistics(self, user_id=None):
        """Obter estatísticas de processamento"""
        return self.reconciler.get_reconciliation_statistics(user_id)
