#!/usr/bin/env python3
# create_admin.py - Script para criar usuário admin com JWT

import sys
import os

# Adicionar src ao path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

# Importações necessárias
from src.auth import create_user_with_password
from src.models.user_mongo import User
from src.database.mongodb import mongodb

def create_admin():
    print("=== Criação do Usuário Admin (JWT) ===")
    
    try:
        # Ler username do admin_config.txt
        admin_config_path = os.path.join(os.path.dirname(__file__), 'admin_config.txt')
        
        if os.path.exists(admin_config_path):
            with open(admin_config_path, 'r') as f:
                username = f.read().strip()
            print(f"Username do admin (do admin_config.txt): {username}")
        else:
            username = input("Digite o username do admin: ")
        
        # Verificar se já existe
        existing_user = User.find_by_username(username)
        if existing_user:
            print(f"AVISO: Admin '{username}' já existe!")
            print(f"Role atual: {existing_user.role}")
            response = input("Deseja continuar mesmo assim? (s/N): ")
            if response.lower() != 's':
                return
        
        # Pedir senha
        password = input(f"Digite a senha para '{username}': ")
        if len(password) < 6:
            print("ERRO: Senha deve ter pelo menos 6 caracteres")
            return
        
        # Criar admin usando o sistema JWT
        result = create_user_with_password(
            username=username,
            password=password,
            display_name="Administrador da Loja",
            role='owner'  # Role mais alta
        )
        
        if result['success']:
            print(f"✅ Admin '{username}' criado com sucesso!")
            print(f"UID: {result['user']['uid']}")
            print(f"Role: {result['user']['role']}")
            print("\nVocê pode fazer login no aplicativo agora.")
        else:
            print(f"❌ Erro ao criar admin: {result['error']}")
            
    except KeyboardInterrupt:
        print("\nOperação cancelada.")
    except Exception as e:
        print(f"❌ Erro inesperado: {e}")
    finally:
        # Fechar conexão MongoDB
        try:
            mongodb.client.close()
            print("Conexão com MongoDB fechada.")
        except:
            pass

if __name__ == "__main__":
    create_admin()
