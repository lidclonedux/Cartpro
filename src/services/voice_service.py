# ARQUIVO NOVO: src/services/voice_service.py

import os
import logging
from datetime import datetime

# Importando os outros serviços que este orquestrador irá usar
from src.config import Config
from src.services.document_processor import DocumentProcessor
from src.services.voice_nlp_processor import VoiceNLPProcessor

logger = logging.getLogger(__name__)

# Lendo a variável de ambiente para decidir a estratégia de transcrição
# Esta é a sua lógica de "Build Adaptativo"
USE_HF_WORKER = os.getenv('USE_HF_WORKER', 'false').lower() == 'true'

class VoiceService:
    """
    Serviço orquestrador para o fluxo de comando de voz.
    1. Decide qual serviço de transcrição usar (local ou remoto).
    2. Converte o áudio em texto.
    3. Usa o VoiceNLPProcessor para extrair entidades do texto.
    4. Reutiliza a inteligência do DocumentProcessor para enriquecer os dados.
    5. Monta a resposta final para a API.
    """
    def __init__(self):
        self.env = 'development' if USE_HF_WORKER else 'production'
        self.document_processor = DocumentProcessor()
        self.nlp_processor = VoiceNLPProcessor()
        self.transcriber = None

        logger.info(f"VoiceService inicializado em modo: '{self.env}'")

        if self.env == 'production':
            # Em produção (Render), carrega o modelo Whisper localmente.
            try:
                from src.services.whisper_service_local import WhisperServiceLocal
                self.transcriber = WhisperServiceLocal()
                logger.info("✅ Transcritor local (Whisper) configurado para produção.")
            except Exception as e:
                logger.critical(f"❌ FALHA CRÍTICA ao carregar modelo de IA local: {e}")
        else:
            # Em desenvolvimento (localhost), usa a API externa do Hugging Face.
            try:
                from src.services.huggingface_api_service import HuggingFaceApiService
                self.transcriber = HuggingFaceApiService()
                logger.info("✅ Transcritor remoto (Hugging Face API) configurado para desenvolvimento.")
            except Exception as e:
                logger.critical(f"❌ FALHA CRÍTICA ao configurar API do Hugging Face: {e}")

    def process_voice_command(self, audio_file_path: str) -> dict:
        """
        Método principal que executa o fluxo completo de processamento de voz.
        """
        if not self.transcriber:
            raise RuntimeError("Serviço de transcrição de voz não está disponível.")

        # ETAPA 1: Áudio para Texto
        command_text = self.transcriber.transcribe(audio_file_path)

        if not command_text or not command_text.strip():
            return {"success": False, "error": "Não foi possível entender o áudio."}

        # ETAPA 2: Texto para Entidades (usando o NLP que traduzimos)
        nlp_result = self.nlp_processor.process_command(command_text)
        entities = nlp_result.get('entities', {})
        
        # ETAPA 3: Enriquecimento (reutilizando a inteligência do DocumentProcessor)
        # Sugere uma categoria mais precisa usando a lógica avançada que já existe.
        if entities.get('description'):
            suggested_category = self.document_processor.suggest_category_from_description(entities['description'])
            if suggested_category != 'Outros':
                entities['category_name'] = suggested_category
                # Aqui, você buscaria o ID da categoria no banco de dados.
                # Ex: category_obj = Category.find_by_name(suggested_category)
                # entities['category_id'] = category_obj.id if category_obj else None

        # ETAPA 4: Montar a resposta final para o Flutter
        # A estrutura deve ser idêntica à que o VoiceProvider no Flutter espera.
        response = {
            "success": True,
            "entities": entities,
            "missing_fields": nlp_result.get('missing_fields', []),
            "original_command": command_text
        }
        
        logger.info(f"Comando de voz processado. Entidades: {response['entities']}")
        return response
