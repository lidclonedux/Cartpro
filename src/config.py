# src/config.py (VERSÃO DE DEBUG - Apenas JWT_SECRET_KEY Hardcoded)
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # --- ESTA LINHA CONTINUA LENDO DO .ENV, COMO VOCÊ PRECISA ---
    SECRET_KEY = os.getenv('SECRET_KEY') 
    
    # --- OUTRAS CONFIGURAÇÕES QUE USAM .ENV ---
    MONGO_URI = os.getenv('MONGO_URI')
    REDIS_URL = os.getenv('REDIS_URL')
    CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME')
    CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY')
    CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET')
    FIREBASE_CREDENTIALS_BASE64 = os.getenv('FIREBASE_CREDENTIALS_BASE64')
    FIREBASE_WEB_API_KEY = os.getenv('FIREBASE_WEB_API_KEY')

    # =================================================================
    # ===== A ÚNICA MUDANÇA PARA DEBUG ESTÁ AQUI ======================
    # =================================================================
    # Chave secreta para JWT "hardcoded" para ignorar problemas com .env
    JWT_SECRET_KEY = 'LUCASMHYDERDEJAVU123030_ESTA_CHAVE_TEM_MAIS_DE_32_CARACTERES'
    # =================================================================

    # Algoritmo de assinatura JWT
    JWT_ALGORITHM = 'HS256'

    # Tempo de expiração do token (em horas)
    JWT_EXPIRATION_HOURS = 24

    # Tempo para refresh token (em horas) - 7 dias
    JWT_REFRESH_HOURS = 168

    # Configurações de senha
    PASSWORD_MIN_LENGTH = 6
    PASSWORD_HASH_ROUNDS = 12

    # Configurações de segurança
    MAX_LOGIN_ATTEMPTS = 5
    LOGIN_TIMEOUT_MINUTES = 15

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
