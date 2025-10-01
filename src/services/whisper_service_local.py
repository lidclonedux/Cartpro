# ARQUIVO NOVO: src/services/whisper_service_local.py

import torch
from transformers import pipeline
import logging

logger = logging.getLogger(__name__)

class WhisperServiceLocal:
    _instance = None
    _pipe = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(WhisperServiceLocal, cls).__new__(cls)
            cls._instance._initialize_model()
        return cls._instance

    def _initialize_model(self):
        if self._pipe is not None:
            return
        try:
            device = "cuda:0" if torch.cuda.is_available() else "cpu"
            self._pipe = pipeline(
                "automatic-speech-recognition",
                model="openai/whisper-small",
                device=device
            )
        except Exception as e:
            logger.critical(f"FALHA CRÍTICA AO CARREGAR MODELO WHISPER: {e}")
            self._pipe = None

    def transcribe(self, audio_file_path: str) -> str:
        if not self._pipe:
            raise RuntimeError("Modelo Whisper (local) não está disponível.")
        
        output = self._pipe(audio_file_path)
        transcribed_text = output.get("text", "").strip()
        return transcribed_text
