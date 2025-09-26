# src/utils/password_utils.py (VERSÃO MODIFICADA PARA DELEGAÇÃO)

# A linha 'import bcrypt' foi REMOVIDA.
import secrets
import string
import re
from typing import Optional, Tuple
from src.config import Config

# ADICIONADO: Importa o HybridProcessor para ser nosso "interruptor".
from src.services.hybrid_processor import HybridProcessor

# Cria uma instância do nosso orquestrador.
hybrid_proc = HybridProcessor()

class PasswordManager:
    """
    Gerenciador de senhas que DELEGA as operações pesadas (hash e verificação).
    """

    def __init__(self):
        self.min_length = Config.PASSWORD_MIN_LENGTH
        self.hash_rounds = Config.PASSWORD_HASH_ROUNDS

    # =================================================================
    # ===== MODIFICAÇÃO 1: DELEGAÇÃO DA CRIAÇÃO DE HASH ==============
    # =================================================================
    def hash_password(self, password: str) -> str:
        """
        Gera hash seguro da senha, DELEGANDO para o processador híbrido.
        """
        if not password:
            raise ValueError("Senha não pode ser vazia")
        
        # Delega a criação do hash para o HybridProcessor.
        return hybrid_proc.create_hash(password)

    # =================================================================
    # ===== MODIFICAÇÃO 2: DELEGAÇÃO DA VERIFICAÇÃO DE SENHA ==========
    # =================================================================
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """
        Verifica se senha confere com hash, DELEGANDO para o processador híbrido.
        """
        if not plain_password or not hashed_password:
            return False
        
        # Delega a verificação para o HybridProcessor.
        return hybrid_proc.verify_password(plain_password, hashed_password)

    # =================================================================
    # ===== MÉTODOS LOCAIS (LEVES) - SEM ALTERAÇÃO ====================
    # =================================================================

    def validate_password_strength(self, password: str) -> Tuple[bool, Optional[str]]:
        """
        Valida força da senha (operação leve, continua local).
        """
        if not password:
            return False, "Senha não pode ser vazia"
        if len(password) < self.min_length:
            return False, f"Senha deve ter pelo menos {self.min_length} caracteres"
        if len(password) > 128:
            return False, "Senha muito longa (máximo 128 caracteres)"
        if not re.search(r'[a-zA-Z]', password):
            return False, "Senha deve conter pelo menos uma letra"
        if password != password.strip():
            return False, "Senha não pode ter espaços no início ou fim"
        return True, None

    def generate_random_password(self, length: int = 12, include_special: bool = True) -> str:
        """
        Gera senha aleatória segura (operação leve, continua local).
        """
        if length < 6: length = 6
        if length > 64: length = 64
        letters = string.ascii_letters
        digits = string.digits
        special_chars = "!@#$%^&*-_=+"
        alphabet = letters + digits
        if include_special: alphabet += special_chars
        password_parts = [
            secrets.choice(string.ascii_lowercase),
            secrets.choice(string.ascii_uppercase),
            secrets.choice(digits),
        ]
        if include_special: password_parts.append(secrets.choice(special_chars))
        remaining_length = length - len(password_parts)
        for _ in range(remaining_length):
            password_parts.append(secrets.choice(alphabet))
        secrets.SystemRandom().shuffle(password_parts)
        return ''.join(password_parts)

    def is_password_pwned(self, password: str) -> bool:
        """
        Verifica se senha está em lista de senhas vazadas (operação leve, continua local).
        """
        common_passwords = {
            '123456', 'password', '123456789', '12345678', '12345',
            '1234567', '1234567890', 'qwerty', 'abc123', 'million2',
            '000000', '1234', 'iloveyou', 'aaron431', 'password1',
            'qqww1122', '123', 'omgpop', '123321', '654321'
        }
        return password.lower() in common_passwords

    def generate_secure_password_for_user(self, username: str = None) -> str:
        """
        Gera senha segura personalizada (operação leve, continua local).
        """
        password = self.generate_random_password(length=12, include_special=True)
        attempts = 0
        while self.is_password_pwned(password) and attempts < 10:
            password = self.generate_random_password(length=12, include_special=True)
            attempts += 1
        return password

    def update_password_security(self, current_hash: str) -> bool:
        """
        Verifica se hash atual precisa ser atualizado. DELEGA para o worker.
        """
        # Esta verificação também depende do bcrypt, então delegamos.
        return hybrid_proc.needs_rehash(current_hash)

# Instância global para uso em todo o projeto
password_manager = PasswordManager()

# Funções de conveniência que agora usarão a lógica delegada
def hash_password(password: str) -> str:
    return password_manager.hash_password(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return password_manager.verify_password(plain_password, hashed_password)

def validate_password(password: str) -> Tuple[bool, Optional[str]]:
    return password_manager.validate_password_strength(password)
