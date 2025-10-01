# ARQUIVO NOVO: src/routes/voice_processing.py

from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
import os
import tempfile
import traceback
import logging

from src.auth import verify_token
from src.services.voice_service import VoiceService

logger = logging.getLogger(__name__)

voice_processing_bp = Blueprint('voice_processing', __name__)

ALLOWED_AUDIO_EXTENSIONS = {'wav', 'mp3', 'm4a', 'ogg', 'flac', 'aac'}

def _allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_AUDIO_EXTENSIONS

@voice_processing_bp.route('/api/voice/process', methods=['POST'])
@verify_token
def process_voice_command(current_user_uid, current_user_data):
    logger.info(f"🎤 [VOICE] Requisição recebida para processar comando de voz do usuário: {current_user_uid}")
    
    if 'audio' not in request.files:
        logger.warning("❌ [VOICE] Requisição sem o campo 'audio'.")
        return jsonify({'success': False, 'error': 'Nenhum arquivo de áudio enviado. Use o campo "audio".'}), 400

    file = request.files['audio']
    if file.filename == '':
        logger.warning("❌ [VOICE] Nome do arquivo de áudio está vazio.")
        return jsonify({'success': False, 'error': 'Nenhum arquivo selecionado.'}), 400

    if not _allowed_file(file.filename):
        logger.warning(f"❌ [VOICE] Tipo de arquivo não suportado: {file.filename}")
        return jsonify({'success': False, 'error': 'Tipo de arquivo de áudio não suportado.'}), 400

    filename = secure_filename(file.filename)
    file_extension = filename.rsplit('.', 1)[1].lower()
    temp_file_path = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_extension}') as temp_file:
            file.save(temp_file.name)
            temp_file_path = temp_file.name
        
        logger.info(f"💾 [VOICE] Arquivo de áudio salvo temporariamente em: {temp_file_path}")

        voice_service = VoiceService()
        result = voice_service.process_voice_command(temp_file_path)

        if not result.get('success', False):
            logger.error(f"❌ [VOICE] Erro no processamento do VoiceService: {result.get('error')}")
            return jsonify({'success': False, 'error': result.get('error', 'Erro no processamento do comando de voz')}), 500

        logger.info("✅ [VOICE] Comando de voz processado com sucesso.")
        logger.debug(f"📊 [VOICE] Entidades retornadas: {result.get('entities')}")
        
        return jsonify(result), 200

    except Exception as e:
        logger.critical(f"💥 [VOICE] Erro crítico e inesperado na rota /api/voice/process: {e}")
        logger.critical(traceback.format_exc())
        return jsonify({'success': False, 'error': f'Erro interno no servidor: {str(e)}'}), 500

    finally:
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
                logger.info(f"🗑️ [VOICE] Arquivo temporário deletado: {temp_file_path}")
            except Exception as e:
                logger.error(f"⚠️ [VOICE] Falha ao deletar arquivo temporário {temp_file_path}: {e}")
