from flask import Blueprint, request, jsonify
from src.models.user_mongo import User
from src.auth import verify_token
from src.middleware.auth_middleware import is_admin

settings_bp = Blueprint("settings", __name__)

@settings_bp.route("/api/settings/contact-info", methods=["PUT"])
@verify_token
@is_admin
def update_contact_info(current_user_uid, current_user):
    """Atualiza as informações de contato do admin."""
    try:
        data = request.get_json()
        phone_number = data.get("phone_number")

        if not phone_number:
            return jsonify({"error": "Número de telefone é obrigatório"}), 400

        user = User.find_by_uid(current_user_uid)
        if not user:
            return jsonify({"error": "Usuário não encontrado"}), 404

        user.phone_number = phone_number
        user.save()

        return jsonify({"success": True, "message": "Informações de contato atualizadas com sucesso!", "user": user.to_dict()}), 200
    except Exception as e:
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500

@settings_bp.route("/api/settings/pix-info", methods=["PUT"])
@verify_token
@is_admin
def update_pix_info(current_user_uid, current_user):
    """Atualiza as informações de PIX do admin."""
    try:
        data = request.get_json()
        pix_key = data.get("pix_key")
        pix_qr_code_url = data.get("pix_qr_code_url")

        if not pix_key:
            return jsonify({"error": "Chave PIX é obrigatória"}), 400

        user = User.find_by_uid(current_user_uid)
        if not user:
            return jsonify({"error": "Usuário não encontrado"}), 404

        user.pix_key = pix_key
        user.pix_qr_code_url = pix_qr_code_url
        user.save()

        return jsonify({"success": True, "message": "Informações de PIX atualizadas com sucesso!", "user": user.to_dict()}), 200
    except Exception as e:
        return jsonify({"error": f"Erro interno no servidor: {e}"}), 500


