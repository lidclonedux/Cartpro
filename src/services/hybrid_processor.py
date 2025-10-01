# backen/src/services/hybrid_processor.py (v4.0 - Final com Relatórios)
import os
import requests
import logging
import base64
from typing import List, Dict

# --- Configuração Centralizada ---
USE_HF_WORKER = os.getenv('USE_HF_WORKER', 'false').lower() == 'true'
HF_BASE_URL = "https://lucasidcloned-borracham.hf.space"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("HybridProcessor")

class HybridProcessor:
    """
    Orquestrador que decide se executa tarefas pesadas localmente ou as delega
    para um worker na nuvem.
    """
    def __init__(self):
        if USE_HF_WORKER:
            logger.info(f"✅ [MODO HÍBRIDO ATIVADO] Delegando para: {HF_BASE_URL}")
        else:
            logger.info("✅ [MODO PRODUÇÃO ATIVADO] Executando localmente.")

    def _delegate_to_worker(self, endpoint: str, json_data: dict = None, files: dict = None) -> dict:
        # ... (código deste método permanece o mesmo) ...
        url = f"{HF_BASE_URL}{endpoint}"
        try:
            logger.info(f"🚀 Delegando tarefa para o endpoint: {endpoint}")
            response = requests.post(url, json=json_data, files=files, timeout=180)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            error_content = e.response.text
            logger.error(f"❌ Erro HTTP do Worker: {e.response.status_code} - {error_content}")
            return {"success": False, "error": f"Erro no serviço externo ({e.response.status_code}): {error_content}"}
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Erro de Conexão com o Worker: {e}")
            return {"success": False, "error": f"Não foi possível conectar ao serviço de processamento: {e}"}

    # --- MÉTODOS DE DELEGAÇÃO ---

    def process_document(self, file_path: str, file_extension: str, context: str) -> dict:
        if USE_HF_WORKER:
            with open(file_path, 'rb') as f:
                files = {'file': (os.path.basename(file_path), f)}
                return self._delegate_to_worker("/process_document", files=files)
        else:
            from services.document_processor import DocumentProcessor
            return DocumentProcessor().process_document(file_path, file_extension, context)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        if USE_HF_WORKER:
            payload = {"plain_password": plain_password, "hashed_password": hashed_password}
            result = self._delegate_to_worker("/auth/verify_password", json_data=payload)
            return result.get("is_valid", False) if result else False
        else:
            from utils.password_utils import password_manager as local_pm
            return local_pm.verify_password(plain_password, hashed_password)

    # (Outros métodos de delegação como authenticate_user, create_user, etc.)

    # =================================================================
    # ===== NOVO MÉTODO PARA DELEGAR A GERAÇÃO DE PDF ===============
    # =================================================================
    def generate_pdf_report(self, transactions: List[Dict], category_map: Dict, context: str) -> dict:
        """
        Gera um relatório PDF, delegando para o worker se estiver no modo híbrido.
        """
        if USE_HF_WORKER:
            payload = {
                "transactions": transactions,
                "category_map": category_map,
                "context": context
            }
            return self._delegate_to_worker("/reports/export_pdf", json_data=payload)
        else:
            # Em produção, a lógica original seria chamada aqui.
            # No modo local, retornamos um erro pois não temos reportlab.
            return {"success": False, "error": "Geração de PDF local desativada no modo híbrido."}
