# ARQUIVO NOVO: src/services/voice_nlp_processor.py

import re
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class VoiceNLPProcessor:
    """
    Tradução e aprimoramento da lógica de NLP do frontend JSX para Python.
    Esta classe é responsável por pegar uma string de texto (transcrita de um áudio)
    e extrair entidades estruturadas como tipo, valor, descrição e data.
    """
    def __init__(self, categories=[]):
        self.categories = categories
        self._setup_patterns()
        self._setup_number_maps()
        logger.info("✅ VoiceNLPProcessor (Python) inicializado.")

    def _setup_number_maps(self):
        self.numbers_map = {
            'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'três': 3, 'tres': 3,
            'quatro': 4, 'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9,
            'dez': 10, 'onze': 11, 'doze': 12, 'treze': 13, 'catorze': 14, 'quatorze': 14,
            'quinze': 15, 'dezesseis': 16, 'dezessete': 17, 'dezoito': 18, 'dezenove': 19,
            'vinte': 20, 'trinta': 30, 'quarenta': 40, 'cinquenta': 50,
            'sessenta': 60, 'setenta': 70, 'oitenta': 80, 'noventa': 90,
            'cem': 100, 'cento': 100, 'duzentos': 200, 'trezentos': 300,
            'quatrocentos': 400, 'quinhentos': 500, 'seiscentos': 600,
            'setecentos': 700, 'oitocentos': 800, 'novecentos': 900
        }
        self.multipliers = {
            'mil': 1000,
            'milhão': 1000000, 'milhao': 1000000,
            'milhões': 1000000, 'milhoes': 1000000,
            'bilhão': 1000000000, 'bilhao': 1000000000,
            'bilhões': 1000000000, 'bilhoes': 1000000000,
        }

    def _setup_patterns(self):
        # Padrões de intenção
        self.intent_patterns = {
            'schedule_transaction': re.compile(r'\b(agendar|agende|programar|todo (dia|mês)|mensal|recorrente|repetir|fixo)\b', re.IGNORECASE),
            'create_transaction': re.compile(r'\b(pagar|paguei|despesa|gasto|receita|receber|recebi|lançar|lançamento)\b', re.IGNORECASE)
        }
        # Padrões de tipo de transação
        self.type_patterns = {
            'expense': re.compile(r'\b(despesa|gasto|pagar|paguei|saída|débito|conta|comprar|comprei|gastei)\b', re.IGNORECASE),
            'income': re.compile(r'\b(receita|entrada|receber|recebi|crédito|ganho|salário|vendi|lucro)\b', re.IGNORECASE)
        }
        # Padrões de data
        self.date_patterns = {
            'hoje': re.compile(r'\bhoje\b', re.IGNORECASE),
            'ontem': re.compile(r'\bontem\b', re.IGNORECASE),
            'amanha': re.compile(r'\b(amanhã|amanha)\b', re.IGNORECASE)
        }
        # Padrões de valor
        self.amount_patterns = [
            re.compile(r'(?:r\$?\s*)?(\d{1,3}(?:\.\d{3})*,\d{2})'), # 1.234,56
            re.compile(r'(?:r\$?\s*)?(\d+,\d{2})'), # 123,45
            re.compile(r'(\d+)\s*(?:reais|real)'), # 100 reais
            re.compile(r'(?:r\$?\s*)?(\d+\.?\d+)'), # 123.45 ou 123
        ]

    def process_command(self, command: str) -> dict:
        normalized_command = self._normalize(command)
        
        intent = self._extract_intent(normalized_command)
        trans_type = self._extract_type(normalized_command)
        amount = self._extract_amount(normalized_command)
        date = self._extract_date(normalized_command)
        description = self._extract_description(normalized_command, amount)

        entities = {
            'type': trans_type,
            'amount': amount,
            'description': description,
            'date': date.isoformat() if date else datetime.now().isoformat(),
        }
        
        missing_fields = self._identify_missing(entities)

        return {
            'original_command': command,
            'entities': entities,
            'missing_fields': missing_fields,
            'intent': intent
        }

    def _normalize(self, text: str) -> str:
        return text.lower().strip()

    def _extract_intent(self, text: str) -> str:
        if self.intent_patterns['schedule_transaction'].search(text):
            return 'schedule_transaction'
        return 'create_transaction'

    def _extract_type(self, text: str) -> str:
        if self.type_patterns['income'].search(text):
            return 'income'
        return 'expense'

    def _extract_amount(self, text: str) -> float | None:
        for pattern in self.amount_patterns:
            match = pattern.search(text)
            if match:
                amount_str = match.group(1).replace('.', '').replace(',', '.')
                return float(amount_str)
        return self._extract_amount_from_words(text)

    def _extract_amount_from_words(self, text: str) -> float | None:
        words = text.split()
        total = 0.0
        current_chunk = 0.0

        for word in words:
            if word in self.numbers_map:
                current_chunk += self.numbers_map[word]
            elif word in self.multipliers:
                if current_chunk == 0: current_chunk = 1.0
                total += current_chunk * self.multipliers[word]
                current_chunk = 0.0
            elif word == 'e':
                continue
        
        total += current_chunk
        return total if total > 0 else None

    def _extract_date(self, text: str) -> datetime:
        if self.date_patterns['ontem'].search(text):
            return datetime.now() - timedelta(days=1)
        if self.date_patterns['amanha'].search(text):
            return datetime.now() + timedelta(days=1)
        return datetime.now()

    def _extract_description(self, text: str, amount: float | None) -> str:
        # Remove palavras-chave de intenção e tipo
        clean_text = self.intent_patterns['create_transaction'].sub('', text)
        clean_text = self.intent_patterns['schedule_transaction'].sub('', clean_text)
        clean_text = self.type_patterns['expense'].sub('', clean_text)
        clean_text = self.type_patterns['income'].sub('', clean_text)
        
        # Remove o valor numérico se foi encontrado
        if amount:
            clean_text = clean_text.replace(str(amount).replace('.',','), '')
            clean_text = clean_text.replace(str(int(amount)), '')

        # Remove palavras de valor por extenso
        for word in list(self.numbers_map.keys()) + list(self.multipliers.keys()):
            clean_text = re.sub(r'\b' + word + r'\b', '', clean_text)
        
        # Remove "reais" e "real"
        clean_text = re.sub(r'\b(reais|real)\b', '', clean_text)
        
        # Limpa espaços extras
        description = ' '.join(clean_text.split()).strip()
        
        return description.capitalize() if description else "Lançamento por voz"

    def _identify_missing(self, entities: dict) -> list:
        missing = []
        if not entities.get('amount'):
            missing.append('amount')
        if not entities.get('description'):
            missing.append('description')
        return missing
