from pymongo import MongoClient
from src.config import Config
import os

class MongoDB:
    _instance = None
    _client = None
    _db = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MongoDB, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if self._client is None:
            self._client = MongoClient(Config.MONGO_URI)
            # Especificar o nome do banco de dados
            self._db = self._client['contabilidade_rezende']
    
    @property
    def db(self):
        return self._db
    
    @property
    def client(self):
        return self._client

# Instância global
mongodb = MongoDB()

