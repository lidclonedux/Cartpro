import unittest
from unittest.mock import patch, MagicMock
import os
import json

# Ajustar o sys.path para que as importações internas funcionem
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

# Importar a aplicação Flask e a rota para testar
from src.main import app # Assumindo que 'app' é a instância do Flask em src/main.py
from routes.upload import upload_bp # Importar o Blueprint

class TestUploadProductImageOffline(unittest.TestCase):

    def setUp(self):
        self.app = app
        # O blueprint já é registrado em src/main.py, não registrar novamente aqui.
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

        # Criar um arquivo dummy para simular o upload
        self.dummy_image_content = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0cIDATx\xda\xed\xc1\x01\x01\x00\x00\x00\xc2\xa0\xf7Om\x00\x00\x00\x00IEND\xaeB`\x82'
        self.dummy_image_filename = 'test_image.png'

        # Mockar o CloudinaryService
        self.cloudinary_patcher = patch('src.routes.upload.CloudinaryService')
        self.mock_cloudinary_service = self.cloudinary_patcher.start()

        # Mockar o decorador verify_token e is_admin
        self.verify_token_patcher = patch('src.routes.upload.verify_token', side_effect=lambda f: lambda *args, **kwargs: f('test_uid', {'role': 'owner'}, *args, **kwargs))
        self.mock_verify_token = self.verify_token_patcher.start()

        self.is_admin_patcher = patch('src.routes.upload.is_admin', side_effect=lambda f: lambda *args, **kwargs: f(*args, **kwargs))
        self.mock_is_admin = self.is_admin_patcher.start()

        # Patch mongodb no seu local de origem (src.database.mongodb)
        # Quando mongodb é importado localmente dentro de uma função, o patch deve ser feito no módulo onde a função está definida
        # e o alvo do patch é o nome que o módulo importado recebe dentro da função.
        # No caso de 'from src.database.mongodb import mongodb', o alvo é 'src.routes.upload.mongodb'
        # No entanto, se o patch for global para o módulo 'src.database.mongodb', ele afetará todas as importações.
        # A forma mais robusta é mockar o módulo 'src.database.mongodb' em si.
        self.mongodb_patcher = patch('src.database.mongodb.mongodb')
        self.mock_mongodb = self.mongodb_patcher.start()
        self.mock_mongodb.db.payment_proofs.insert_one.return_value = MagicMock(inserted_id='mock_proof_id')
        self.mock_mongodb.db.documents.insert_one.return_value = MagicMock(inserted_id='mock_document_id')

    def tearDown(self):
        self.cloudinary_patcher.stop()
        self.verify_token_patcher.stop()
        self.is_admin_patcher.stop()
        self.mongodb_patcher.stop()

    def test_upload_product_image_success(self):
        self.mock_cloudinary_service.upload_file.return_value = {
            'success': True,
            'url': 'https://res.cloudinary.com/test/image/upload/v1/test_public_id.png',
            'public_id': 'test_public_id',
            'format': 'png',
            'bytes': len(self.dummy_image_content)
        }

        response = self.client.post(
            '/upload/product-image',
            headers={'Authorization': 'Bearer test_token'},
            data={
                'file': (self.dummy_image_content, self.dummy_image_filename, 'image/png'),
                'product_name': 'Produto de Teste',
                'context': 'ecommerce',
                'type': 'product_image'
            },
            content_type='multipart/form-data'
        )

        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertTrue(data['success'])
        self.assertIn('url', data)
        self.assertEqual(data['url'], 'https://res.cloudinary.com/test/image/upload/v1/test_public_id.png')
        self.mock_cloudinary_service.upload_file.assert_called_once()

    def test_upload_product_image_no_file(self):
        response = self.client.post(
            '/upload/product-image',
            headers={'Authorization': 'Bearer test_token'},
            data={
                'product_name': 'Produto de Teste',
                'context': 'ecommerce',
                'type': 'product_image'
            },
            content_type='multipart/form-data'
        )

        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertFalse(data['success'])
        self.assertIn('Nenhum arquivo enviado', data['error'])
        self.mock_cloudinary_service.upload_file.assert_not_called()

    def test_upload_product_image_file_too_large(self):
        large_dummy_content = b'a' * (11 * 1024 * 1024) # 11MB
        response = self.client.post(
            '/upload/product-image',
            headers={'Authorization': 'Bearer test_token'},
            data={
                'file': (large_dummy_content, self.dummy_image_filename, 'image/png'),
                'product_name': 'Produto de Teste',
                'context': 'ecommerce',
                'type': 'product_image'
            },
            content_type='multipart/form-data'
        )

        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertFalse(data['success'])
        self.assertIn('Arquivo muito grande', data['error'])
        self.mock_cloudinary_service.upload_file.assert_not_called()

    def test_upload_product_image_cloudinary_failure(self):
        self.mock_cloudinary_service.upload_file.return_value = {
            'success': False,
            'error': 'Cloudinary error message'
        }

        response = self.client.post(
            '/upload/product-image',
            headers={'Authorization': 'Bearer test_token'},
            data={
                'file': (self.dummy_image_content, self.dummy_image_filename, 'image/png'),
                'product_name': 'Produto de Teste',
                'context': 'ecommerce',
                'type': 'product_image'
            },
            content_type='multipart/form-data'
        )

        self.assertEqual(response.status_code, 500)
        data = json.loads(response.data)
        self.assertFalse(data['success'])
        self.assertIn('Cloudinary error message', data['error'])
        self.mock_cloudinary_service.upload_file.assert_called_once()

    def test_upload_document_success(self):
        self.mock_cloudinary_service.upload_file.return_value = {
            'success': True,
            'url': 'https://res.cloudinary.com/test/document/upload/v1/test_public_id.pdf',
            'public_id': 'test_public_id',
            'format': 'pdf',
            'bytes': len(self.dummy_image_content)
        }

        response = self.client.post(
            '/upload/document',
            headers={'Authorization': 'Bearer test_token'},
            data={
                'file': (self.dummy_image_content, 'test_document.pdf', 'application/pdf'),
                'context': 'business',
                'description': 'Fatura mensal',
                'type': 'invoice'
            },
            content_type='multipart/form-data'
        )

        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertTrue(data['success'])
        self.assertIn('url', data)
        self.assertEqual(data['url'], 'https://res.cloudinary.com/test/document/upload/v1/test_public_id.pdf')
        self.mock_cloudinary_service.upload_file.assert_called_once()
        self.mock_mongodb.db.documents.insert_one.assert_called_once()

if __name__ == '__main__':
    unittest.main()


