import os
import sys
from flask import Flask, send_from_directory, jsonify, request, Response
from flask_cors import CORS
import requests
import threading
import subprocess
import time
from datetime import datetime

# Ajuste para que o Python encontre os módulos dentro de 'src'
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from config import Config
from database.mongodb import mongodb

# --- Blueprints da API ---
from routes.auth import auth_bp
from routes.categories_mongo import categories_bp
from routes.transactions_mongo import transactions_bp
from routes.document_processing import document_processing_bp
from routes.recurring import recurring_bp
from routes.reports_export import reports_export_bp
from routes.products_mongo import products_bp
from routes.orders_mongo import orders_bp
from routes.settings_mongo import settings_bp
from routes.upload import upload_bp

# --- Verificação da variável de ambiente MONGO_URI ---
if not os.getenv('MONGO_URI'):
    try:
        from dotenv import load_dotenv
        load_dotenv()
        print("📁 Arquivo .env carregado para desenvolvimento local")
    except ImportError:
        print("⚠️ python-dotenv não encontrado. Usando variáveis do sistema.")

# --- Flask App ---
app = Flask(
    __name__,
    static_folder=os.path.join(os.path.dirname(__file__), "../static"),
    static_url_path=""
)
app.config.from_object(Config)

# --- CORS - CONFIGURAÇÃO ROBUSTA ---
CORS(
    app,
    resources={r"/api/*": {"origins": "*"}},
    supports_credentials=True,
    allow_headers=["Authorization", "Content-Type"],
    methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"]
)

# =======================================================================
# CONFIGURAÇÕES DO DEBUG SERVER - SEMPRE HABILITADO
# =======================================================================
DEBUG_SERVER_PORT = 8081
DEBUG_SERVER_HOST = "127.0.0.1"

# --- ROTAS QUE DEVEM IR PARA O DEBUG SERVER ---
@app.route('/login', methods=['GET', 'POST'])
@app.route('/logout')
@app.route('/debug-panel', defaults={'path': ''})
@app.route('/debug-panel/<path:path>')
@app.route('/api/debug/<path:path>')
def debug_proxy(path=''):
    """Proxy para o servidor de debug interno"""
    internal_path = request.full_path
    debug_url = f'http://{DEBUG_SERVER_HOST}:{DEBUG_SERVER_PORT}{internal_path}'
        
    print(f"🔧 Proxying request to debug server: {debug_url}")
    
    try:
        resp = requests.request(
            method=request.method,
            url=debug_url,
            headers={key: value for (key, value) in request.headers if key.lower() != 'host'},
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False,
            stream=True,
            timeout=30.0
        )

        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        headers = [(name, value) for (name, value) in resp.raw.headers.items()
                   if name.lower() not in excluded_headers]

        response = Response(resp.iter_content(chunk_size=1024), resp.status_code, headers)
        return response
        
    except requests.exceptions.ConnectionError:
        print(f"❌ Debug server não respondendo em {DEBUG_SERVER_HOST}:{DEBUG_SERVER_PORT}")
        return "Servidor de debug não está rodando.", 503
    except Exception as e:
        print(f"❌ Erro no proxy do debug: {e}")
        return f"Erro interno no proxy: {e}", 500

# --- Registro dos Blueprints da API ---
app.register_blueprint(auth_bp)
app.register_blueprint(categories_bp)
app.register_blueprint(transactions_bp)
app.register_blueprint(document_processing_bp)
app.register_blueprint(recurring_bp)
app.register_blueprint(reports_export_bp)
app.register_blueprint(products_bp)
app.register_blueprint(orders_bp)
app.register_blueprint(settings_bp)
app.register_blueprint(upload_bp)

# --- Servir arquivos estáticos ---
@app.route('/static/<path:filename>')
def serve_static_with_prefix(filename):
    print(f"📁 Servindo /static/{filename}")
    try:
        return send_from_directory(app.static_folder, filename)
    except FileNotFoundError:
        print(f"❌ Arquivo não encontrado: /static/{filename}")
        return jsonify({'error': f'File not found: {filename}'}), 404

@app.route('/<path:filename>')
def serve_static_files(filename):
    """Serve arquivos estáticos do Flutter Web"""
    
    if filename.startswith('api/'):
        return jsonify({'error': 'API endpoint not found'}), 404
    
    static_extensions = {
        '.js': 'application/javascript',
        '.wasm': 'application/wasm',
        '.css': 'text/css',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.ico': 'image/x-icon',
        '.svg': 'image/svg+xml',
        '.ttf': 'font/ttf',
        '.otf': 'font/otf',
        '.woff': 'font/woff',
        '.woff2': 'font/woff2',
        '.bin': 'application/octet-stream',
        '.frag': 'text/plain'
    }
    
    file_ext = '.' + filename.split('.')[-1].lower() if '.' in filename else ''
    
    try:
        print(f"📁 Servindo: {filename}")
        response = send_from_directory(app.static_folder, filename)
        
        if file_ext in static_extensions:
            response.headers['Content-Type'] = static_extensions[file_ext]
        
        if file_ext == '.js':
            response.headers['Cross-Origin-Embedder-Policy'] = 'require-corp'
            response.headers['Cross-Origin-Opener-Policy'] = 'same-origin'
        
        return response
        
    except FileNotFoundError:
        return serve_flutter_spa()

@app.route('/')
def serve_flutter_spa():
    """Serve o index.html do Flutter"""
    try:
        print("📱 Servindo Flutter SPA")
        response = send_from_directory(app.static_folder, 'index.html')
        response.headers['Content-Type'] = 'text/html; charset=utf-8'
        response.headers['Cross-Origin-Embedder-Policy'] = 'require-corp'
        response.headers['Cross-Origin-Opener-Policy'] = 'same-origin'
        return response
    except FileNotFoundError:
        print("❌ index.html não encontrado")
        return jsonify({
            'error': 'Flutter Web não encontrado',
            'static_folder': app.static_folder
        }), 500

# --- Fallback para 404s ---
@app.errorhandler(404)
def not_found(error):
    # Esta verificação agora é redundante por causa das rotas explícitas, mas é segura de manter.
    if request.path.startswith('/debug-panel') or request.path.startswith('/api/debug'):
        return debug_proxy(path=request.path.lstrip('/'))
    
    if request.path.startswith('/api/'):
        return jsonify({'error': 'API endpoint not found'}), 404
    
    return serve_flutter_spa()

# =======================================================================
# CORREÇÃO APLICADA: ROTA /health OTIMIZADA
# =======================================================================
@app.route('/health')
def health_check():
    """
    Verificação de saúde rápida e eficiente.
    Verifica apenas a conexão com o MongoDB e a existência do index.html.
    """
    mongo_ok = False
    try:
        # Faz um ping rápido no MongoDB que não deve demorar mais que 1 segundo
        mongodb.client.admin.command('ping')
        mongo_ok = True
    except Exception as e:
        print(f"AVISO no Health Check: Falha no ping do MongoDB: {e}")

    index_exists = os.path.exists(os.path.join(app.static_folder, 'index.html'))
    
    status_code = 200 if mongo_ok and index_exists else 503
    
    return jsonify({
        'status': 'OK' if status_code == 200 else 'UNHEALTHY',
        'dependencies': {
            'mongodb_connection': 'OK' if mongo_ok else 'FAIL',
            'flutter_index_found': 'OK' if index_exists else 'FAIL'
        }
    }), status_code

# --- Debug Cloudinary ---
@app.route('/api/debug/cloudinary-test')
def test_cloudinary_config():
    try:
        cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
        api_key = os.getenv('CLOUDINARY_API_KEY')
        api_secret = os.getenv('CLOUDINARY_API_SECRET')
        
        cloudinary_status = {}
        try:
            import cloudinary
            cloudinary_status['imported'] = True
            try:
                cloudinary_status['version'] = getattr(cloudinary, '__version__', 'N/A')
            except:
                cloudinary_status['version'] = 'N/A'
        except ImportError:
            cloudinary_status['imported'] = False
        
        return jsonify({
            'status': 'OK',
            'cloudinary': cloudinary_status,
            'config': {
                'complete': bool(cloud_name and api_key and api_secret),
                'cloud_name': cloud_name or 'MISSING',
                'api_key_present': bool(api_key),
                'api_secret_present': bool(api_secret),
            }
        })
        
    except Exception as e:
        return jsonify({'status': 'ERROR', 'error': str(e)}), 500

# --- Debug Files ---
@app.route('/debug/files')
def list_static_files():
    static_folder = app.static_folder
    
    if not os.path.exists(static_folder):
        return jsonify({'error': 'Static folder não existe'}), 404
    
    all_files = []
    for root, dirs, files in os.walk(static_folder):
        for file in files:
            rel_path = os.path.relpath(os.path.join(root, file), static_folder)
            all_files.append(rel_path.replace('\\', '/'))
    
    return jsonify({
        'static_folder': static_folder,
        'total_files': len(all_files),
        'files': sorted(all_files)[:20]
    })

# --- MongoDB Initialization ---
with app.app_context():
    try:
        mongo_uri = os.getenv('MONGO_URI')
        if mongo_uri:
            result = mongodb.client.admin.command('ping')
            print("✅ MongoDB conectado")
        else:
            print("⚠️ MONGO_URI não configurada")
    except Exception as e:
        print(f"❌ MongoDB falhou: {e}")

# --- Error Handler ---
@app.errorhandler(Exception)
def handle_exception(e):
    print(f"❌ Erro: {e}")
    return jsonify({"error": str(e)}), 500

# =======================================================================
# DEBUG SERVER INITIALIZATION COM DEBUG APRIMORADO
# =======================================================================
def start_debug_server():
    """Inicia o debug server com captura imediata de erros"""
    print(f"🚀 Iniciando debug server na porta {DEBUG_SERVER_PORT}")
    try:
        # CAMINHO CORRETO PARA A RAIZ
        debug_server_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "debug_server_enhanced.py")
        print(f"🔍 Procurando debug server em: {debug_server_path}")
        
        if not os.path.exists(debug_server_path):
            print(f"❌ debug_server_enhanced.py não encontrado em: {debug_server_path}")
            print("🔍 Tentando listar arquivos na raiz do projeto:")
            try:
                root_dir = os.path.dirname(os.path.dirname(__file__))
                files = [f for f in os.listdir(root_dir) if f.endswith('.py')]
                print(f"   Arquivos .py na raiz: {files}")
            except Exception as e:
                print(f"Erro ao listar arquivos da raiz: {e}")
            return
        
        print(f"✅ Debug server encontrado em: {debug_server_path}")
        
        # VERIFICA E INSTALA DEPENDÊNCIAS
        missing_deps = []
        try:
            import psutil
        except ImportError:
            missing_deps.append('psutil')
        
        try:
            import requests
        except ImportError:
            missing_deps.append('requests')
        
        if missing_deps:
            print(f"❌ Dependências faltando: {missing_deps}")
            print("📦 Instalando dependências automaticamente...")
            try:
                for dep in missing_deps:
                    result = subprocess.run([
                        sys.executable, "-m", "pip", "install", dep
                    ], capture_output=True, text=True, timeout=60)
                    
                    if result.returncode == 0:
                        print(f"✅ {dep} instalado com sucesso")
                    else:
                        print(f"❌ Falha ao instalar {dep}:")
                        print(f"STDERR: {result.stderr}")
                        return
            except Exception as install_error:
                print(f"❌ Erro ao instalar dependências: {install_error}")
                return
        else:
            print("✅ Todas as dependências estão disponíveis")
        
        # COMANDO PARA EXECUTAR O DEBUG SERVER
        cmd = [
            sys.executable, 
            debug_server_path, 
            "--port", str(DEBUG_SERVER_PORT), 
            "--host", DEBUG_SERVER_HOST
        ]
        
        print(f"🔧 Executando comando: {' '.join(cmd)}")
        
        # INICIA O PROCESSO
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True,
            bufsize=0,
            universal_newlines=True
        )
        
        print("⏳ Aguardando 3 segundos para verificar se o processo iniciou...")
        time.sleep(3)
        
        # VERIFICA STATUS
        poll_result = process.poll()
        
        if poll_result is None:
            print("✅ Debug server iniciado com sucesso e rodando")
        else:
            print(f"❌ Debug server falhou IMEDIATAMENTE com código: {poll_result}")
            
            # CAPTURA SAÍDA IMEDIATA
            try:
                stdout, stderr = process.communicate(timeout=2)
                
                print("=" * 60)
                print("DEBUG SERVER OUTPUT (IMMEDIATE FAILURE):")
                print("=" * 60)
                
                if stdout and stdout.strip():
                    print("📤 STDOUT:")
                    print(stdout)
                    print("-" * 30)
                else:
                    print("📤 STDOUT: (vazio)")
                
                if stderr and stderr.strip():
                    print("📤 STDERR:")
                    print(stderr)
                    print("-" * 30)
                else:
                    print("📤 STDERR: (vazio)")
                
                # DIAGNÓSTICO ADICIONAL
                print("🔧 DIAGNÓSTICO:")
                print(f"   - Python executable: {sys.executable}")
                print(f"   - Debug server path: {debug_server_path}")
                print(f"   - File exists: {os.path.exists(debug_server_path)}")
                print(f"   - File size: {os.path.getsize(debug_server_path) if os.path.exists(debug_server_path) else 'N/A'} bytes")
                print(f"   - Working directory: {os.getcwd()}")
                
                # TESTA SINTAXE DO ARQUIVO
                try:
                    with open(debug_server_path, 'r') as f:
                        content = f.read()
                    compile(content, debug_server_path, 'exec')
                    print("   - Sintaxe do arquivo: OK")
                except SyntaxError as syntax_error:
                    print(f"   - ERRO DE SINTAXE: {syntax_error}")
                except Exception as file_error:
                    print(f"   - Erro ao verificar arquivo: {file_error}")
                
                print("=" * 60)
                
            except subprocess.TimeoutExpired:
                print("❌ Timeout ao capturar saída do debug server")
                process.kill()
            except Exception as comm_error:
                print(f"❌ Erro ao capturar saída: {comm_error}")
            
    except Exception as e:
        print(f"❌ Erro crítico ao iniciar debug server: {e}")
        import traceback
        print("🔧 Stack trace completo:")
        traceback.print_exc()

# =======================================================================
# MIGRAÇÃO FIREBASE → JWT (EXECUTAR UMA VEZ)
# =======================================================================
def run_firebase_migration():
    """
    Executa a migração dos usuários Firebase para JWT
    Execute UMA VEZ definindo RUN_MIGRATION=true no Render
    """
    print("=" * 60)
    print("🚀 MIGRAÇÃO FIREBASE → JWT")
    print("   Definindo senhas originais para usuários antigos")
    print("=" * 60)
    
    try:
        from models.user_mongo import User
        from utils.password_utils import password_manager
        
        # Mapeamento dos usuários conhecidos e suas senhas originais
        USERS_TO_MIGRATE = {
            'MaykonRodas': {
                'password': 'maykondejavularanja12',
                'role': 'owner',
                'expected_uid': 'gPEIkoBLszgs0ZKYzf3NEYojEpE2'
            },
            'daianaM': {
                'password': 'luhday10',
                'role': 'client',
                'expected_uid': '1SyYGeimEbau2QfK3Z4y29LTNww1'
            }
        }

        def migrate_user_password(username, user_data):
            """Migra um usuário específico definindo sua senha original"""
            try:
                print(f"\n🔍 Processando usuário: {username}")
                
                # Buscar usuário no banco
                user = User.find_by_username(username)
                if not user:
                    print(f"❌ Usuário {username} não encontrado no banco")
                    return False
                
                print(f"✅ Usuário encontrado: {user.username} (UID: {user.uid})")
                
                # Verificar UID se fornecido
                expected_uid = user_data.get('expected_uid')
                if expected_uid and user.uid != expected_uid:
                    print(f"⚠️  UID diferente do esperado!")
                    print(f"   Esperado: {expected_uid}")
                    print(f"   Encontrado: {user.uid}")
                    print("   Continuando mesmo assim...")
                
                # Verificar se já tem password_hash
                if user.password_hash and len(user.password_hash) > 10:
                    print(f"✅ Usuário {username} já tem password_hash válido")
                    print(f"   Hash: {user.password_hash[:20]}...")
                    return True
                
                # Gerar hash da senha original
                original_password = user_data['password']
                print(f"🔐 Gerando hash para senha original...")
                print(f"   Senha: {original_password[:5]}... (len: {len(original_password)})")
                
                new_hash = password_manager.hash_password(original_password)
                print(f"   Hash gerado: {new_hash[:30]}...")
                
                # Testar hash imediatamente
                test_result = password_manager.verify_password(original_password, new_hash)
                print(f"   Teste imediato: {test_result}")
                
                if not test_result:
                    print(f"❌ Falha crítica no teste de hash para {username}")
                    return False
                
                # Atualizar usuário
                user.password_hash = new_hash
                user.role = user_data.get('role', user.role)
                user.updated_at = datetime.utcnow()
                
                # Salvar
                print(f"💾 Salvando usuário com password_hash...")
                user.save()
                
                print(f"✅ Usuário {username} migrado com sucesso!")
                print(f"   Role: {user.role}")
                print(f"   Hash salvo: {len(user.password_hash)} caracteres")
                
                return True
                
            except Exception as e:
                print(f"❌ Erro ao migrar {username}: {e}")
                import traceback
                print(f"Stack trace: {traceback.format_exc()}")
                return False

        def verify_migration():
            """Verifica se a migração foi bem-sucedida testando login"""
            print("\n" + "=" * 60)
            print("🔍 VERIFICANDO MIGRAÇÃO")
            print("=" * 60)
            
            success_count = 0
            
            for username, user_data in USERS_TO_MIGRATE.items():
                try:
                    print(f"\n🧪 Testando login: {username}")
                    
                    # Buscar usuário migrado
                    user = User.find_by_username(username)
                    if not user:
                        print(f"❌ Usuário {username} não encontrado após migração")
                        continue
                    
                    # Testar senha
                    password = user_data['password']
                    password_valid = password_manager.verify_password(password, user.password_hash)
                    
                    if password_valid:
                        print(f"✅ Login OK para {username}")
                        print(f"   Role: {user.role}")
                        print(f"   UID: {user.uid}")
                        success_count += 1
                    else:
                        print(f"❌ Login FALHOU para {username}")
                        print(f"   Hash no banco: {user.password_hash[:20]}...")
                        
                except Exception as e:
                    print(f"❌ Erro ao verificar {username}: {e}")
            
            print(f"\n📊 Resultado: {success_count}/{len(USERS_TO_MIGRATE)} usuários migrados com sucesso")
            return success_count == len(USERS_TO_MIGRATE)

        # Verificar conexão com MongoDB
        try:
            mongodb.client.admin.command('ping')
            total_users = mongodb.db.users.count_documents({})
            print(f"✅ MongoDB conectado - Total usuários: {total_users}")
        except Exception as e:
            print(f"❌ Erro de conexão MongoDB: {e}")
            return
        
        # Listar usuários a migrar
        print(f"\n📋 Usuários para migração:")
        for username, data in USERS_TO_MIGRATE.items():
            print(f"   - {username} → {data['role']} (senha: {len(data['password'])} chars)")
        
        # Executar migração
        print(f"\n🔄 Iniciando migração...")
        migrated_count = 0
        
        for username, user_data in USERS_TO_MIGRATE.items():
            if migrate_user_password(username, user_data):
                migrated_count += 1
        
        # Verificar resultado
        print(f"\n📊 Migração concluída: {migrated_count}/{len(USERS_TO_MIGRATE)} usuários")
        
        if migrated_count > 0:
            verify_migration()
        
        # Instruções finais
        print("\n" + "=" * 60)
        print("🎉 MIGRAÇÃO FINALIZADA")
        print("=" * 60)
        print("📝 PRÓXIMOS PASSOS:")
        print("   1. Teste os logins no app:")
        print("      - MaykonRodas / maykondejavularanja12")
        print("      - daianaM / luhday10")
        print("   2. REMOVA a variável RUN_MIGRATION do Render")
        print("   3. Os usuários já podem acessar suas contas!")
        print("=" * 60)
        
    except Exception as e:
        print(f"❌ Erro crítico na migração: {e}")
        import traceback
        print(traceback.format_exc())

# =======================================================================
# COMPATIBILIDADE GUNICORN
# =======================================================================
# Alias para Gunicorn
application = app

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    debug_mode = os.environ.get("FLASK_ENV") == "development"
    
    print("=" * 50)
    print(f"🚀 Iniciando aplicação")
    print(f"🚀 Porta: {port}")
    print(f"🚀 Debug: {debug_mode}")
    print(f"🚀 Static: {app.static_folder}")
    print("=" * 50)
    
    # MIGRAÇÃO FIREBASE (executa apenas se RUN_MIGRATION=true)
    if os.getenv('RUN_MIGRATION', '').lower() == 'true':
        print("🔥 Executando migração Firebase → JWT")
        try:
            run_firebase_migration()
        except Exception as e:
            print(f"❌ Erro na migração: {e}")
        print("🔥 Migração finalizada")
    
    # DEBUG SERVER SEMPRE HABILITADO
    debug_thread = threading.Thread(target=start_debug_server, daemon=True)
    debug_thread.start()
    
    app.run(host='0.0.0.0', port=port, debug=debug_mode)
else:
    # Quando importado pelo Gunicorn, também inicia o debug server e verifica migração
    print("📡 Aplicação importada pelo Gunicorn - iniciando debug server")
    
    # MIGRAÇÃO FIREBASE (executa apenas se RUN_MIGRATION=true)
    if os.getenv('RUN_MIGRATION', '').lower() == 'true':
        print("🔥 Executando migração Firebase → JWT (Gunicorn)")
        try:
            run_firebase_migration()
        except Exception as e:
            print(f"❌ Erro na migração: {e}")
        print("🔥 Migração finalizada")
    
    debug_thread = threading.Thread(target=start_debug_server, daemon=True)
    debug_thread.start()
