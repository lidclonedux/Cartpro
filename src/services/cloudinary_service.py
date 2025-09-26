import cloudinary
import cloudinary.uploader
from src.config import Config

# Configurar Cloudinary
cloudinary.config(
    cloud_name=Config.CLOUDINARY_CLOUD_NAME,
    api_key=Config.CLOUDINARY_API_KEY,
    api_secret=Config.CLOUDINARY_API_SECRET
)

class CloudinaryService:
    @staticmethod
    def upload_file(file, folder="documents", resource_type="auto"):
        """
        Upload de arquivo para o Cloudinary
        
        Args:
            file: Arquivo a ser enviado
            folder: Pasta no Cloudinary
            resource_type: Tipo do recurso (auto, image, video, raw)
        
        Returns:
            dict: Informações do arquivo enviado
        """
        try:
            result = cloudinary.uploader.upload(
                file,
                folder=folder,
                resource_type=resource_type,
                use_filename=True,
                unique_filename=True
            )
            
            return {
                'success': True,
                'url': result.get('secure_url'),
                'public_id': result.get('public_id'),
                'format': result.get('format'),
                'resource_type': result.get('resource_type'),
                'bytes': result.get('bytes'),
                'created_at': result.get('created_at')
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    @staticmethod
    def delete_file(public_id, resource_type="auto"):
        """
        Remove arquivo do Cloudinary
        
        Args:
            public_id: ID público do arquivo
            resource_type: Tipo do recurso
        
        Returns:
            dict: Resultado da operação
        """
        try:
            result = cloudinary.uploader.destroy(public_id, resource_type=resource_type)
            return {
                'success': True,
                'result': result
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    @staticmethod
    def get_file_info(public_id):
        """
        Obtém informações de um arquivo
        
        Args:
            public_id: ID público do arquivo
        
        Returns:
            dict: Informações do arquivo
        """
        try:
            result = cloudinary.api.resource(public_id)
            return {
                'success': True,
                'info': result
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }

