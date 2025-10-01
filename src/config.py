# src/config.py (VERSÃO COMPLETA - Com processamento de voz)
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # --- CONFIGURAÇÕES BÁSICAS ---
    SECRET_KEY = os.getenv('SECRET_KEY')

    # --- BANCO DE DADOS E SERVIÇOS ---
    MONGO_URI = os.getenv('MONGO_URI')
    REDIS_URL = os.getenv('REDIS_URL')
    CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME')
    CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY')
    CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET')
    FIREBASE_CREDENTIALS_BASE64 = os.getenv('FIREBASE_CREDENTIALS_BASE64')
    FIREBASE_WEB_API_KEY = os.getenv('FIREBASE_WEB_API_KEY')

    # =================================================================
    # ===== JWT CONFIGURAÇÕES ========================================
    # =================================================================
    # Chave secreta para JWT "hardcoded" para ignorar problemas com .env
    JWT_SECRET_KEY = 'LUCASMHYDERDEJAVU123030_ESTA_CHAVE_TEM_MAIS_DE_32_CARACTERES'
    
    # Algoritmo de assinatura JWT
    JWT_ALGORITHM = 'HS256'

    # Tempo de expiração do token (em horas)
    JWT_EXPIRATION_HOURS = 24

    # Tempo para refresh token (em horas) - 7 dias
    JWT_REFRESH_HOURS = 168

    # =================================================================
    # ===== CONFIGURAÇÕES DE SENHA ===================================
    # =================================================================
    PASSWORD_MIN_LENGTH = 6
    PASSWORD_HASH_ROUNDS = 12

    # Configurações de segurança
    MAX_LOGIN_ATTEMPTS = 5
    LOGIN_TIMEOUT_MINUTES = 15

    # =================================================================
    # ===== CONFIGURAÇÕES GERAIS =====================================
    # =================================================================
    # Configuração de fuso horário
    TIMEZONE_OFFSET_HOURS = float(os.getenv('TIMEZONE_OFFSET_HOURS', '-3.0'))

    # Configurações de processamento de documentos
    DOCUMENT_MAX_FILE_SIZE_MB = 10
    DOCUMENT_ALLOWED_EXTENSIONS = ['pdf', 'jpg', 'jpeg', 'png', 'csv', 'xlsx', 'xls']

    # Configurações de OCR
    OCR_LANGUAGE = 'por'

    # Configurações de conciliação
    RECONCILIATION_TIME_TOLERANCE_MINUTES = 5
    RECONCILIATION_SIMILARITY_THRESHOLD = 0.7

    # =================================================================
    # ===== CONFIGURAÇÕES DE PROCESSAMENTO DE VOZ ====================
    # =================================================================
    # Ambiente de execução
    ENVIRONMENT = os.getenv('ENVIRONMENT', 'production')  # 'development' para localhost, 'production' para Render
    
    # URL do Hugging Face Space (usado apenas em desenvolvimento/localhost)
    HUGGINGFACE_VOICE_URL = os.getenv('HUGGINGFACE_VOICE_URL', 'https://seu-space-name.hf.space')
    
    # Configurações de arquivos de áudio
    VOICE_MAX_FILE_SIZE_MB = 25  # Máximo 25MB para arquivos de áudio
    VOICE_ALLOWED_EXTENSIONS = ['wav', 'mp3', 'm4a', 'ogg', 'flac', 'aac', 'webm']
    
    # Timeout para processamento de voz (em segundos)
    VOICE_PROCESSING_TIMEOUT = 300  # 5 minutos
    
    # Configurações de qualidade de áudio
    VOICE_MIN_DURATION_SECONDS = 1  # Mínimo 1 segundo
    VOICE_MAX_DURATION_SECONDS = 300  # Máximo 5 minutos
    
    # Configurações de confiança para NLP
    VOICE_MIN_CONFIDENCE = 0.3  # Confiança mínima para aceitar resultado
    VOICE_HIGH_CONFIDENCE = 0.8  # Confiança alta para processamento automático
    
    # Configurações de cache para modelos de IA
    VOICE_CACHE_DIR = os.getenv('VOICE_CACHE_DIR', '/tmp/voice_cache')
    
    # Fallback para processamento local (quando HF não disponível)
    VOICE_LOCAL_FALLBACK_ENABLED = True
    
    # =================================================================
    # ===== CONFIGURAÇÕES DE LOGGING =================================
    # =================================================================
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    # =================================================================
    # ===== CONFIGURAÇÕES DE PERFORMANCE =============================
    # =================================================================
    # Configurações para processamento assíncrono
    MAX_CONCURRENT_VOICE_REQUESTS = 3
    VOICE_REQUEST_QUEUE_SIZE = 10
    
    # Configurações de retry para APIs externas
    API_RETRY_ATTEMPTS = 3
    API_RETRY_DELAY_SECONDS = 2
    
    # =================================================================
    # ===== MÉTODOS AUXILIARES =======================================
    # =================================================================
    
    @classmethod
    def is_development(cls):
        """Verifica se está rodando em ambiente de desenvolvimento."""
        return cls.ENVIRONMENT == 'development'
    
    @classmethod
    def is_production(cls):
        """Verifica se está rodando em ambiente de produção."""
        return cls.ENVIRONMENT == 'production'
    
    @classmethod
    def get_voice_endpoint_url(cls):
        """Retorna a URL correta para processamento de voz baseada no ambiente."""
        if cls.is_development():
            return f"{cls.HUGGINGFACE_VOICE_URL}/process_voice"
        else:
            return None  # Processamento local no Render
    
    @classmethod
    def is_voice_file_valid(cls, filename, file_size_bytes):
        """Valida se um arquivo de voz atende aos critérios."""
        if not filename:
            return False, "Nome do arquivo não fornecido"
        
        # Verificar extensão
        file_extension = filename.split('.')[-1].lower()
        if file_extension not in cls.VOICE_ALLOWED_EXTENSIONS:
            return False, f"Extensão não suportada. Permitidas: {', '.join(cls.VOICE_ALLOWED_EXTENSIONS)}"
        
        # Verificar tamanho
        max_size = cls.VOICE_MAX_FILE_SIZE_MB * 1024 * 1024
        if file_size_bytes > max_size:
            return False, f"Arquivo muito grande. Máximo: {cls.VOICE_MAX_FILE_SIZE_MB}MB"
        
        # Verificar tamanho mínimo (1KB)
        if file_size_bytes < 1024:
            return False, "Arquivo muito pequeno ou corrompido"
        
        return True, "Arquivo válido"
    
    @classmethod
    def get_debug_info(cls):
        """Retorna informações de debug sobre a configuração."""
        return {
            "environment": cls.ENVIRONMENT,
            "voice_processing_enabled": bool(cls.HUGGINGFACE_VOICE_URL),
            "voice_endpoint": cls.get_voice_endpoint_url(),
            "max_file_size_mb": cls.VOICE_MAX_FILE_SIZE_MB,
            "allowed_extensions": cls.VOICE_ALLOWED_EXTENSIONS,
            "timeout_seconds": cls.VOICE_PROCESSING_TIMEOUT,
            "local_fallback": cls.VOICE_LOCAL_FALLBACK_ENABLED
        }
