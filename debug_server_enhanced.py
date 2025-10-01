#!/usr/bin/env python

import os
import sys
import json
import time
import subprocess
import threading
import inspect
import importlib
import pkgutil
from datetime import datetime
from flask import (
    Flask, request, jsonify, send_from_directory, render_template_string, 
    session, redirect, url_for
)
from werkzeug.serving import WSGIRequestHandler
import logging
from logging.handlers import RotatingFileHandler
import psutil
import requests
from pathlib import Path
from functools import wraps
from dotenv import load_dotenv

# --- Bloco de Configuração Inicial ---
# Garante que os módulos da aplicação principal sejam encontrados
sys.path.insert(0, os.path.abspath("."))
sys.path.insert(0, os.path.abspath("./src"))  # Adiciona src específicamente
load_dotenv() # Carrega variáveis de ambiente do .env

# =============================================================================
# LÓGICA DE AUTENTICAÇÃO E SESSÃO
# =============================================================================

def login_required(f):
    """
    Decorator que verifica se o usuário está logado na sessão.
    Se não estiver, redireciona para a página de login.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_role' not in session:
            # Para chamadas de API, retorna 401. Para páginas, redireciona.
            if request.path.startswith('/api/debug'):
                return jsonify({'error': 'Autenticação necessária.'}), 401
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

class EnhancedDebugServer:
    def __init__(self, flutter_build_path='static', main_app_path='src'):
        self.app = Flask(__name__)
        self.flutter_path = flutter_build_path
        self.main_app_path = main_app_path
        
        # Chave secreta para sessões seguras
        self.app.secret_key = os.environ.get('DEBUG_SECRET_KEY', 'super-secret-key-for-debug-panel-change-me')
        
        self.setup_logging()
        self.setup_routes()
        self.command_history = []
        self.active_processes = {}
        self.discovered_routes = {}
        self.discovered_models = {}
        self.api_tests_results = {}
        
    def setup_logging(self):
        """Configuração de logging otimizada"""
        logging.basicConfig(
            level=logging.DEBUG,
            format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
            datefmt='%H:%M:%S'
        )
        handler = RotatingFileHandler(
            'debug_enhanced.log', 
            maxBytes=2*1024*1024,  # 2MB máximo
            backupCount=5
        )
        handler.setLevel(logging.INFO)
        formatter = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(message)s'
        )
        handler.setFormatter(formatter)
        self.app.logger.addHandler(handler)
        
    def setup_routes(self):
        """Setup das rotas de debug aprimoradas com autenticação"""

        # --- ROTAS DE AUTENTICAÇÃO ---
        @self.app.route('/login', methods=['GET', 'POST'])
        def login():
            error = None
            if request.method == 'POST':
                username = request.form.get('username')
                password = request.form.get('password')

                # Importação dinâmica para evitar erro de contexto na inicialização
                try:
                    from models.user_mongo import User
                    from auth import verify_password_and_get_uid

                    user_mongo = User.find_by_username(username)
                    
                    if user_mongo and user_mongo.role in ['owner', 'admin']:
                        uid = verify_password_and_get_uid(user_mongo.email, password)
                        if uid and uid == user_mongo.uid:
                            session['logged_in'] = True
                            session['username'] = user_mongo.username
                            session['user_role'] = user_mongo.role
                            self.app.logger.info(f"Login bem-sucedido para '{username}'. Redirecionando para o painel.")
                            return redirect(url_for('debug_panel'))
                    
                    error = 'Credenciais inválidas ou permissão insuficiente.'
                    self.app.logger.warning(f"Falha no login para '{username}'. Motivo: {error}")
                except Exception as e:
                    self.app.logger.error(f"Erro durante o processo de login: {e}")
                    error = 'Erro interno no servidor de autenticação.'

            return render_template_string(LOGIN_PAGE_HTML, error=error)

        @self.app.route('/logout')
        def logout():
            self.app.logger.info(f"Usuário '{session.get('username', 'desconhecido')}' deslogado.")
            session.clear()
            return redirect(url_for('login'))

        # --- ROTAS PROTEGIDAS ---
        @self.app.route('/')
        @login_required
        def serve_flutter_redirect():
            return redirect(url_for('debug_panel'))

        @self.app.route('/debug-panel')
        @login_required
        def debug_panel():
            return render_template_string(ENHANCED_DEBUG_PANEL_HTML, username=session.get('username', 'Usuário'))

        @self.app.route('/<path:path>')
        @login_required
        def serve_static(path):
            if path.startswith('api/debug'):
                return jsonify({'error': 'Rota de API não encontrada ou não permitida.'}), 404
            
            try:
                return send_from_directory(self.flutter_path, path)
            except Exception as e:
                self.app.logger.error(f"Erro ao servir arquivo estático '{path}': {e}")
                return jsonify({'error': f'Arquivo estático não encontrado: {path}'}), 404
        
        # API de Debug Aprimorada (todas protegidas)
        @self.app.route('/api/debug/status')
        @login_required
        def debug_status():
            return jsonify({
                'status': 'running',
                'timestamp': datetime.now().isoformat(),
                'memory_info': self.get_memory_info(),
                'active_processes': len(self.active_processes),
                'discovered_routes': len(self.discovered_routes),
                'discovered_models': len(self.discovered_models),
                'uptime': self.get_uptime()
            })
        
        @self.app.route('/api/debug/routes')
        @login_required
        def get_routes():
            try:
                routes = self.discover_routes()
                return jsonify({
                    'success': True,
                    'routes': routes,
                    'total': len(routes)
                })
            except Exception as e:
                self.app.logger.error(f"Erro ao obter rotas: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/debug/models')
        @login_required
        def get_models():
            try:
                models = self.discover_models()
                return jsonify({
                    'success': True,
                    'models': models,
                    'total': len(models)
                })
            except Exception as e:
                self.app.logger.error(f"Erro ao obter modelos: {e}")
                return jsonify({'success': False, 'error': str(e)}), 500
        
        @self.app.route('/api/debug/logs')
        @login_required
        def get_logs():
            lines = request.args.get('lines', 100, type=int)
            try:
                with open('debug_enhanced.log', 'r') as f:
                    log_lines = f.readlines()[-lines:]
                return jsonify({'logs': log_lines})
            except FileNotFoundError:
                return jsonify({'logs': []})
        
        @self.app.route('/api/debug/execute', methods=['POST'])
        @login_required
        def execute_command():
            data = request.get_json()
            command = data.get('command', '')
            if not command:
                return jsonify({'error': 'Comando vazio'}), 400
            return self.execute_terminal_command(command)
        
        @self.app.route('/api/debug/test', methods=['POST'])
        @login_required
        def run_test():
            data = request.get_json()
            test_type = data.get('type', 'api')
            endpoint = data.get('endpoint', '/')
            if test_type == 'api':
                return self.run_api_test(endpoint)
            elif test_type == 'route':
                return self.test_specific_route(endpoint)
            elif test_type == 'memory':
                return self.run_memory_test()
            elif test_type == 'connectivity':
                return self.run_connectivity_test()
            elif test_type == 'all_routes':
                return self.test_all_routes()
            else:
                return jsonify({'error': 'Tipo de teste inválido'}), 400
                
        @self.app.route('/api/debug/metrics')
        @login_required
        def get_metrics():
            return jsonify(self.get_system_metrics())
        
        @self.app.route('/api/debug/health')
        @login_required
        def health_check():
            return jsonify(self.perform_health_check())

    def discover_routes(self):
        """Descobre automaticamente todas as rotas da aplicação principal"""
        routes = []
        
        try:
            # Tentar importar a aplicação principal de forma mais robusta
            try:
                from src.main import app as main_app
            except ImportError:
                try:
                    import main
                    main_app = main.app
                except ImportError:
                    self.app.logger.warning("Não foi possível importar a aplicação principal. Usando rotas predefinidas.")
                    return self.get_predefined_routes()
            
            with self.app.app_context():
                for rule in main_app.url_map.iter_rules():
                    route_info = {
                        'endpoint': rule.endpoint,
                        'rule': rule.rule,
                        'methods': list(rule.methods - {'HEAD', 'OPTIONS'}),
                        'subdomain': rule.subdomain or '',
                        'host': rule.host or '',
                        'defaults': rule.defaults or {},
                        'strict_slashes': rule.strict_slashes,
                        'source': 'main_app'
                    }
                    
                    # Tentar obter informações da função
                    try:
                        view_func = main_app.view_functions.get(rule.endpoint)
                        if view_func:
                            route_info['function_name'] = view_func.__name__
                            route_info['module'] = view_func.__module__
                            route_info['docstring'] = view_func.__doc__ or ''
                            
                            # Tentar obter parâmetros da função
                            try:
                                sig = inspect.signature(view_func)
                                route_info['parameters'] = [
                                    {
                                        'name': param.name,
                                        'default': str(param.default) if param.default != inspect.Parameter.empty else None,
                                        'annotation': str(param.annotation) if param.annotation != inspect.Parameter.empty else None
                                    }
                                    for param in sig.parameters.values()
                                ]
                            except Exception:
                                route_info['parameters'] = []
                    except Exception as e:
                        route_info['error'] = str(e)
                    
                    routes.append(route_info)
                    
        except Exception as e:
            self.app.logger.error(f"Erro ao descobrir rotas Flask: {e}")
            return self.get_predefined_routes()
        
        self.discovered_routes = {route['endpoint']: route for route in routes}
        return routes
    
    def get_predefined_routes(self):
        """Retorna rotas predefinidas quando a descoberta automática falha"""
        predefined = [
            # Auth routes
            {'endpoint': 'auth.register_with_username', 'rule': '/api/auth/register-with-username', 'methods': ['POST'], 'source': 'predefined'},
            {'endpoint': 'auth.username_login', 'rule': '/api/auth/username-login', 'methods': ['POST'], 'source': 'predefined'},
            {'endpoint': 'auth.get_profile', 'rule': '/api/auth/profile', 'methods': ['GET'], 'source': 'predefined'},
            
            # Categories routes
            {'endpoint': 'categories.get_categories', 'rule': '/api/categories', 'methods': ['GET'], 'source': 'predefined'},
            {'endpoint': 'categories.create_category', 'rule': '/api/categories', 'methods': ['POST'], 'source': 'predefined'},
            
            # Transactions routes
            {'endpoint': 'transactions.get_transactions', 'rule': '/api/transactions', 'methods': ['GET'], 'source': 'predefined'},
            {'endpoint': 'transactions.create_transaction', 'rule': '/api/transactions', 'methods': ['POST'], 'source': 'predefined'},
            
            # Products routes
            {'endpoint': 'products.get_products', 'rule': '/api/products', 'methods': ['GET'], 'source': 'predefined'},
            {'endpoint': 'products.create_product', 'rule': '/api/products', 'methods': ['POST'], 'source': 'predefined'},
            
            # Orders routes
            {'endpoint': 'orders.get_all_orders', 'rule': '/api/orders', 'methods': ['GET'], 'source': 'predefined'},
            {'endpoint': 'orders.create_order', 'rule': '/api/orders', 'methods': ['POST'], 'source': 'predefined'},
            
            # Upload routes
            {'endpoint': 'upload.upload_payment_proof', 'rule': '/api/upload/proof', 'methods': ['POST'], 'source': 'predefined'},
            {'endpoint': 'upload.upload_product_image', 'rule': '/api/upload/product-image', 'methods': ['POST'], 'source': 'predefined'},
            
            # Debug routes
            {'endpoint': 'health_check', 'rule': '/health', 'methods': ['GET'], 'source': 'predefined'}
        ]
        self.discovered_routes = {route['endpoint']: route for route in predefined}
        return predefined
    
    def discover_models(self):
        """Descobre automaticamente todos os modelos de dados"""
        models = []
        
        try:
            models_path = os.path.join(self.main_app_path, 'models')
            if os.path.exists(models_path):
                for filename in os.listdir(models_path):
                    if filename.endswith('.py') and not filename.startswith('__'):
                        module_name = filename[:-3]
                        try:
                            # Tentar importar o módulo de modelos
                            try:
                                module = importlib.import_module(f'src.models.{module_name}')
                            except ImportError:
                                module = importlib.import_module(f'models.{module_name}')
                            
                            # Procurar por classes no módulo
                            for attr_name in dir(module):
                                attr = getattr(module, attr_name)
                                if inspect.isclass(attr) and attr.__module__ == module.__name__:
                                    model_info = {
                                        'name': attr_name,
                                        'module': module_name,
                                        'file': filename,
                                        'docstring': attr.__doc__ or '',
                                        'methods': [],
                                        'attributes': []
                                    }
                                    
                                    # Descobrir métodos
                                    for method_name in dir(attr):
                                        if not method_name.startswith('_'):
                                            method = getattr(attr, method_name)
                                            if callable(method):
                                                model_info['methods'].append({
                                                    'name': method_name,
                                                    'docstring': method.__doc__ or ''
                                                })
                                    
                                    # Descobrir atributos (se possível)
                                    try:
                                        if hasattr(attr, '__init__'):
                                            sig = inspect.signature(attr.__init__)
                                            for param in sig.parameters.values():
                                                if param.name != 'self':
                                                    model_info['attributes'].append({
                                                        'name': param.name,
                                                        'default': str(param.default) if param.default != inspect.Parameter.empty else None,
                                                        'annotation': str(param.annotation) if param.annotation != inspect.Parameter.empty else None
                                                    })
                                    except Exception:
                                        pass
                                    
                                    models.append(model_info)
                                    
                        except Exception as e:
                            self.app.logger.error(f"Erro ao importar modelo {module_name}: {e}")
            
            self.discovered_models = {model['name']: model for model in models}
            
        except Exception as e:
            self.app.logger.error(f"Erro ao descobrir modelos: {e}")
        
        return models
    
    def get_memory_info(self):
        """Informações detalhadas de memória"""
        try:
            # Memória do sistema
            mem = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # Memória do processo atual
            process = psutil.Process()
            process_mem = process.memory_info()
            
            return {
                'system': {
                    'total': mem.total,
                    'available': mem.available,
                    'percent': mem.percent,
                    'used': mem.used,
                    'free': mem.free
                },
                'swap': {
                    'total': swap.total,
                    'used': swap.used,
                    'free': swap.free,
                    'percent': swap.percent
                },
                'process': {
                    'rss': process_mem.rss,
                    'vms': process_mem.vms,
                    'percent': process.memory_percent()
                }
            }
        except Exception as e:
            self.app.logger.error(f"Erro ao obter informações de memória: {e}")
            return {'error': str(e)}
    
    def get_uptime(self):
        """Tempo de atividade do sistema"""
        try:
            boot_time = psutil.boot_time()
            uptime_seconds = time.time() - boot_time
            
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            
            return f"{days}d {hours}h {minutes}m"
        except Exception as e:
            self.app.logger.error(f"Erro ao obter uptime: {e}")
            return "Unknown"
    
    def get_system_metrics(self):
        """Métricas completas do sistema"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            
            disk_usage = psutil.disk_usage('/')
            
            # Processos Python
            python_processes = []
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
                try:
                    if 'python' in proc.info['name'].lower():
                        python_processes.append(proc.info)
                except:
                    continue
            
            # Conexões de rede
            network_connections = len(psutil.net_connections())
            
            return {
                'cpu': {
                    'percent': cpu_percent,
                    'count': cpu_count
                },
                'memory': self.get_memory_info(),
                'disk': {
                    'total': disk_usage.total,
                    'used': disk_usage.used,
                    'free': disk_usage.free,
                    'percent': disk_usage.percent
                },
                'python_processes': python_processes,
                'network_connections': network_connections,
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            self.app.logger.error(f"Erro ao obter métricas do sistema: {e}")
            return {'error': str(e)}
    
    def perform_health_check(self):
        """Health check completo"""
        checks = []
        overall_status = 'healthy'

        # Check 1: Conectividade com a internet
        try:
            requests.get('https://www.google.com', timeout=5)
            checks.append({'name': 'Internet Connectivity', 'status': 'healthy', 'value': 'OK'})
        except requests.exceptions.RequestException as e:
            checks.append({'name': 'Internet Connectivity', 'status': 'critical', 'error': str(e)})
            overall_status = 'critical'

        # Check 2: Conectividade com a aplicação principal (porta 5000)
        try:
            response = requests.get(f"http://localhost:{os.environ.get('PORT', 10000)}/health", timeout=5)
            if response.status_code == 200:
                checks.append({'name': 'Main App API (localhost:5000)', 'status': 'healthy', 'value': 'OK'})
            else:
                checks.append({'name': 'Main App API (localhost:5000)', 'status': 'critical', 'value': f'HTTP {response.status_code}'})
                overall_status = 'critical'
        except requests.exceptions.RequestException as e:
            checks.append({'name': 'Main App API (localhost:5000)', 'status': 'critical', 'error': str(e)})
            overall_status = 'critical'

        # Check 3: Espaço em disco
        disk_usage = psutil.disk_usage('/')
        if disk_usage.percent > 90:
            checks.append({'name': 'Disk Usage', 'status': 'critical', 'value': f'{disk_usage.percent}%', 'details': 'Espaço em disco muito alto!'})
            overall_status = 'critical'
        elif disk_usage.percent > 75:
            checks.append({'name': 'Disk Usage', 'status': 'warning', 'value': f'{disk_usage.percent}%', 'details': 'Espaço em disco alto.'})
            if overall_status == 'healthy': 
                overall_status = 'warning'
        else:
            checks.append({'name': 'Disk Usage', 'status': 'healthy', 'value': f'{disk_usage.percent}%'})

        # Check 4: Memória RAM
        mem = psutil.virtual_memory()
        if mem.percent > 90:
            checks.append({'name': 'Memory Usage', 'status': 'critical', 'value': f'{mem.percent}%', 'details': 'Uso de memória muito alto!'})
            overall_status = 'critical'
        elif mem.percent > 75:
            checks.append({'name': 'Memory Usage', 'status': 'warning', 'value': f'{mem.percent}%', 'details': 'Uso de memória alto.'})
            if overall_status == 'healthy': 
                overall_status = 'warning'
        else:
            checks.append({'name': 'Memory Usage', 'status': 'healthy', 'value': f'{mem.percent}%'})

        # Check 5: Status do log
        log_file_path = 'debug_enhanced.log'
        if not os.path.exists(log_file_path):
            checks.append({'name': 'Log File Status', 'status': 'critical', 'error': f'Arquivo de log {log_file_path} não encontrado.'})
            overall_status = 'critical'
        else:
            try:
                with open(log_file_path, 'r') as f:
                    f.read(1)
                checks.append({'name': 'Log File Status', 'status': 'healthy', 'value': 'Acessível'})
            except Exception as e:
                checks.append({'name': 'Log File Status', 'status': 'critical', 'error': f'Erro de acesso ao log: {e}'})
                overall_status = 'critical'

        return {
            'overall_status': overall_status,
            'checks': checks,
            'timestamp': datetime.now().isoformat()
        }
    
    def execute_terminal_command(self, command):
        """Execução segura de comandos"""
        try:
            # Lista de comandos permitidos
            allowed_commands = [
                'ls', 'pwd', 'ps', 'df', 'free', 'uname', 'whoami',
                'curl', 'wget', 'ping', 'netstat', 'ss',
                'python', 'pip', 'flask', 'gunicorn',
                'git', 'cat', 'head', 'tail', 'grep',
                'find', 'which', 'echo', 'date', 'uptime',
                'tree'
            ]
            
            cmd_parts = command.split()
            if not cmd_parts or cmd_parts[0] not in allowed_commands:
                self.app.logger.warning(f"Tentativa de comando não permitido: {command}")
                return jsonify({
                    'success': False,
                    'error': f'Comando não permitido: {cmd_parts[0] if cmd_parts else "vazio"}'
                }), 403
            
            # Executa comando
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # Salva no histórico
            self.command_history.append({
                'command': command,
                'timestamp': datetime.now().isoformat(),
                'return_code': result.returncode,
                'stdout_lines': len(result.stdout.split('\n')) if result.stdout else 0,
                'stderr_lines': len(result.stderr.split('\n')) if result.stderr else 0
            })
            
            return jsonify({
                'success': True,
                'return_code': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'command': command,
                'timestamp': datetime.now().isoformat()
            })
            
        except subprocess.TimeoutExpired:
            self.app.logger.error(f"Comando '{command}' expirou.")
            return jsonify({
                'success': False,
                'error': 'Comando expirou (timeout de 30s)'
            }), 408
        except Exception as e:
            self.app.logger.error(f"Erro ao executar comando '{command}': {e}")
            return jsonify({
                'success': False,
                'error': str(e)
            }), 500
    
    def run_api_test(self, endpoint):
        """Teste de endpoint específico"""
        try:
            base_url = f"http://localhost:{os.environ.get('PORT', 10000)}"
            full_url = f"{base_url}{endpoint}"
            
            start_time = time.time()
            response = requests.get(full_url, timeout=10)
            end_time = time.time()
            
            result = {
                'success': True,
                'url': full_url,
                'status_code': response.status_code,
                'response_time_ms': round((end_time - start_time) * 1000, 2),
                'content_length': len(response.content),
                'headers': dict(response.headers),
                'timestamp': datetime.now().isoformat()
            }
            
            # Tentar parsear JSON
            try:
                result['json_response'] = response.json()
            except:
                result['text_response'] = response.text[:500] + '...' if len(response.text) > 500 else response.text
            
            return jsonify(result)
            
        except Exception as e:
            self.app.logger.error(f"Erro ao executar teste de API para '{endpoint}': {e}")
            return jsonify({
                'success': False,
                'error': str(e),
                'url': full_url if 'full_url' in locals() else endpoint
            }), 500
    
    def test_specific_route(self, endpoint):
        """Teste específico de uma rota descoberta"""
        if endpoint not in self.discovered_routes:
            return jsonify({
                'success': False,
                'error': f'Rota {endpoint} não encontrada nas rotas descobertas'
            }), 404
        
        route_info = self.discovered_routes[endpoint]
        results = []
        
        # Testar cada método HTTP suportado
        for method in route_info.get('methods', ['GET']):
            try:
                base_url = f"http://localhost:{os.environ.get('PORT', 10000)}"
                full_url = f"{base_url}{route_info['rule']}"
                
                start_time = time.time()
                
                if method == 'GET':
                    response = requests.get(full_url, timeout=10)
                elif method == 'POST':
                    response = requests.post(full_url, json={}, timeout=10)
                elif method == 'PUT':
                    response = requests.put(full_url, json={}, timeout=10)
                elif method == 'DELETE':
                    response = requests.delete(full_url, timeout=10)
                else:
                    continue
                
                end_time = time.time()
                
                results.append({
                    'method': method,
                    'status_code': response.status_code,
                    'response_time_ms': round((end_time - start_time) * 1000, 2),
                    'success': response.status_code < 400
                })
                
            except Exception as e:
                self.app.logger.error(f"Erro ao testar rota '{endpoint}' com método '{method}': {e}")
                results.append({
                    'method': method,
                    'error': str(e),
                    'success': False
                })
        
        return jsonify({
            'success': True,
            'endpoint': endpoint,
            'route_info': route_info,
            'test_results': results
        })
    
    def test_all_routes(self):
        """Testa todas as rotas descobertas"""
        if not self.discovered_routes:
            self.discover_routes()
        
        results = []
        for endpoint, route_info in self.discovered_routes.items():
            # Pular rotas que não são de API ou que são do próprio debug-panel
            if not route_info['rule'].startswith('/api') or route_info['rule'].startswith('/api/debug'):
                continue
            
            try:
                test_result = self.test_specific_route(endpoint)
                # test_specific_route já retorna um jsonify, precisamos extrair o JSON
                if test_result.status_code == 200:
                    results.append(json.loads(test_result.data))
                else:
                    results.append({
                        'endpoint': endpoint,
                        'error': f"Falha no teste da rota: {test_result.status_code}",
                        'success': False
                    })
            except Exception as e:
                self.app.logger.error(f"Erro ao testar todas as rotas para '{endpoint}': {e}")
                results.append({
                    'endpoint': endpoint,
                    'error': str(e),
                    'success': False
                })
        
        return jsonify({
            'success': True,
            'total_routes_tested': len(results),
            'results': results
        })
    
    def run_memory_test(self):
        """Teste de uso de memória"""
        import gc
        
        # Força garbage collection
        gc.collect()
        
        memory_info = self.get_memory_info()
        
        return jsonify({
            'success': True,
            'memory_info': memory_info,
            'python_objects': len(gc.get_objects()),
            'gc_counts': gc.get_counts()
        })
    
    def run_connectivity_test(self):
        """Teste de conectividade"""
        tests = []
        
        # Teste localhost
        try:
            response = requests.get(f"http://localhost:{os.environ.get('PORT', 10000)}/health", timeout=5)
            tests.append({
                'name': 'Main App API',
                'success': response.status_code == 200,
                'details': f'HTTP {response.status_code}',
                'response_time': response.elapsed.total_seconds() * 1000
            })
        except Exception as e:
            self.app.logger.error(f"Erro no teste de conectividade (Main App API): {e}")
            tests.append({
                'name': 'Main App API',
                'success': False,
                'details': str(e)
            })
        
        # Teste Internet
        try:
            response = requests.get('https://httpbin.org/status/200', timeout=5)
            tests.append({
                'name': 'Internet (httpbin.org)',
                'success': response.status_code == 200,
                'details': f'HTTP {response.status_code}',
                'response_time': response.elapsed.total_seconds() * 1000
            })
        except Exception as e:
            self.app.logger.error(f"Erro no teste de conectividade (Internet): {e}")
            tests.append({
                'name': 'Internet',
                'success': False,
                'details': str(e)
            })
        
        # Teste DNS
        try:
            import socket
            socket.gethostbyname('google.com')
            tests.append({
                'name': 'DNS Resolution',
                'success': True,
                'details': 'OK'
            })
        except Exception as e:
            self.app.logger.error(f"Erro no teste de conectividade (DNS): {e}")
            tests.append({
                'name': 'DNS Resolution',
                'success': False,
                'details': str(e)
            })
        
        return jsonify({
            'success': True,
            'tests': tests
        })
    
    def run(self, host='0.0.0.0', port=8080, debug=True):
        """Inicia o servidor aprimorado"""
        self.port = port
        
        print(f"🚀 Enhanced Debug Server (com login) iniciando...")
        print(f"🔒 Acesse o painel em: http://localhost:{port}/login")
        print(f"📱 Flutter App: http://localhost:{port}")
        print(f"📊 API Status: http://localhost:{port}/api/debug/status")
        print(f"🛣️  Routes Discovery: http://localhost:{port}/api/debug/routes")
        print(f"📋 Models Discovery: http://localhost:{port}/api/debug/models")
        print(f"💾 Logs salvos em: debug_enhanced.log")
        
        # Descobrir rotas e modelos na inicialização
        print("🔍 Descobrindo rotas...")
        routes = self.discover_routes()
        print(f"✅ {len(routes)} rotas descobertas")
        
        print("🔍 Descobrindo modelos...")
        models = self.discover_models()
        print(f"✅ {len(models)} modelos descobertos")
        
        # WSGIRequestHandler silencioso
        class QuietWSGIRequestHandler(WSGIRequestHandler):
            def log_request(self, code='-', size='-'):
                # Suprime logs para requisições de debug e estáticas do Flutter
                if self.path.startswith('/api/debug') or self.path.startswith('/static'):
                    return
                super().log_request(code, size)
        
        try:
            self.app.run(
                host=host,
                port=port,
                debug=debug,
                threaded=True,
                request_handler=QuietWSGIRequestHandler
            )
        except Exception as e:
            self.app.logger.error(f"Erro ao iniciar servidor: {e}")
            print(f"❌ Erro ao iniciar servidor: {e}")

# =============================================================================
# TEMPLATES HTML
# =============================================================================

LOGIN_PAGE_HTML = '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Login - Painel de Debug</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%); color: white; }
        .login-box { background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px); padding: 2.5rem; border-radius: 15px; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37); border: 1px solid rgba(255, 255, 255, 0.18); text-align: center; }
        h2 { background: linear-gradient(45deg, #00d4ff, #ff6b6b); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 1.5rem; }
        input { display: block; width: 100%; padding: 0.75rem; margin-bottom: 1rem; border: 1px solid rgba(255, 255, 255, 0.3); border-radius: 8px; background: rgba(0,0,0,0.2); color: white; }
        button { width: 100%; padding: 0.75rem; background: linear-gradient(45deg, #00d4ff, #4ecdc4); color: white; border: none; border-radius: 25px; cursor: pointer; font-weight: bold; transition: all 0.3s ease; }
        button:hover { transform: scale(1.05); box-shadow: 0 5px 15px rgba(0, 212, 255, 0.4); }
        .error { color: #ff6b6b; margin-top: 1rem; }
    </style>
</head>
<body>
    <div class="login-box">
        <h2>Acesso ao Painel de Debug</h2>
        <form method="post">
            <input type="text" name="username" placeholder="Usuário (Owner/Admin)" required>
            <input type="password" name="password" placeholder="Senha" required>
            <button type="submit">Entrar</button>
            {% if error %}<p class="error">{{ error }}</p>{% endif %}
        </form>
    </div>
</body>
</html>
'''

ENHANCED_DEBUG_PANEL_HTML = '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 Enhanced Debug Panel - Santo Graal Prodígio</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: #ffffff;
            min-height: 100vh;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 1rem 2rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header h1 {
            font-size: 2rem;
            background: linear-gradient(45deg, #00d4ff, #ff6b6b, #4ecdc4);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .header .user-info {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .header .btn-logout {
            background: linear-gradient(45deg, #ff6b6b, #ee5a52);
            border: none;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 25px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s ease;
            text-decoration: none;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 15px;
            padding: 1.5rem;
            transition: all 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0, 212, 255, 0.3);
        }
        
        .card h3 {
            color: #00d4ff;
            margin-bottom: 1rem;
            font-size: 1.2rem;
        }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 1rem;
        }
        
        .status-item {
            background: rgba(0, 0, 0, 0.3);
            padding: 1rem;
            border-radius: 10px;
            text-align: center;
        }
        
        .status-value {
            font-size: 1.5rem;
            font-weight: bold;
            color: #4ecdc4;
        }
        
        .status-label {
            font-size: 0.9rem;
            opacity: 0.8;
            margin-top: 0.5rem;
        }
        
        .btn {
            background: linear-gradient(45deg, #00d4ff, #4ecdc4);
            border: none;
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 25px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s ease;
            margin: 0.25rem;
            text-decoration: none;
            display: inline-block;
        }
        
        .btn:hover {
            transform: scale(1.05);
            box-shadow: 0 5px 15px rgba(0, 212, 255, 0.4);
        }
        
        .btn-danger {
            background: linear-gradient(45deg, #ff6b6b, #ee5a52);
        }
        
        .btn-warning {
            background: linear-gradient(45deg, #ffa726, #ff9800);
        }
        
        .btn-success {
            background: linear-gradient(45deg, #4caf50, #45a049);
        }
        
        input, textarea, select {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.3);
            color: white;
            padding: 0.75rem;
            border-radius: 10px;
            width: 100%;
            margin: 0.5rem 0;
        }
        
        input::placeholder, textarea::placeholder {
            color: rgba(255, 255, 255, 0.6);
        }
        
        .output {
            background: rgba(0, 0, 0, 0.5);
            padding: 1rem;
            border-radius: 10px;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
            max-height: 300px;
            overflow-y: auto;
            margin: 1rem 0;
            border-left: 4px solid #00d4ff;
        }
        
        .error {
            border-left-color: #ff6b6b;
            background: rgba(255, 107, 107, 0.1);
        }
        
        .success {
            border-left-color: #4caf50;
            background: rgba(76, 175, 80, 0.1);
        }
        
        .logs {
            height: 250px;
            overflow-y: auto;
            font-size: 0.8rem;
            line-height: 1.4;
        }
        
        .route-item, .model-item {
            background: rgba(0, 0, 0, 0.3);
            padding: 1rem;
            border-radius: 8px;
            margin: 0.5rem 0;
            border-left: 4px solid #4ecdc4;
        }
        
        .route-methods {
            display: flex;
            gap: 0.5rem;
            margin: 0.5rem 0;
            flex-wrap: wrap;
        }
        
        .method-badge {
            padding: 0.25rem 0.5rem;
            border-radius: 15px;
            font-size: 0.8rem;
            font-weight: bold;
        }
        
        .method-get { background: #4caf50; }
        .method-post { background: #2196f3; }
        .method-put { background: #ff9800; }
        .method-delete { background: #f44336; }
        
        .health-check {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }
        
        .health-item {
            padding: 1rem;
            border-radius: 10px;
            text-align: center;
        }
        
        .health-healthy { background: rgba(76, 175, 80, 0.2); border: 2px solid #4caf50; }
        .health-warning { background: rgba(255, 152, 0, 0.2); border: 2px solid #ff9800; }
        .health-critical { background: rgba(244, 67, 54, 0.2); border: 2px solid #f44336; }
        
        .tabs {
            display: flex;
            margin-bottom: 1rem;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 10px;
            padding: 0.5rem;
            flex-wrap: wrap;
        }
        
        .tab {
            flex: 1;
            min-width: 150px;
            padding: 0.75rem;
            text-align: center;
            cursor: pointer;
            border-radius: 8px;
            transition: all 0.3s ease;
        }
        
        .tab.active {
            background: linear-gradient(45deg, #00d4ff, #4ecdc4);
        }
        
        .tab-content {
            display: none;
        }
        
        .tab-content.active {
            display: block;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        
        .loading {
            animation: pulse 1.5s infinite;
        }
        
        .metric-chart {
            height: 100px;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 8px;
            margin: 1rem 0;
            display: flex;
            align-items: center;
            justify-content: center;
            color: rgba(255, 255, 255, 0.6);
        }

        @media (max-width: 768px) {
            .header {
                flex-direction: column;
                gap: 1rem;
                text-align: center;
            }
            
            .header h1 {
                font-size: 1.5rem;
            }
            
            .grid {
                grid-template-columns: 1fr;
            }
            
            .tabs {
                flex-direction: column;
            }
            
            .tab {
                margin: 0.25rem 0;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Enhanced Debug Panel - Santo Graal Prodígio</h1>
        <div class="user-info">
            <p>Bem-vindo, <strong>{{ username }}</strong>!</p>
            <a href="/logout" class="btn-logout">Sair</a>
        </div>
    </div>

    <div class="container">
        <!-- Status do Sistema -->
        <div class="card">
            <h3>📊 Status do Sistema</h3>
            <div class="status-grid" id="system-status">
                <div class="status-item loading">
                    <div class="status-value">...</div>
                    <div class="status-label">Carregando...</div>
                </div>
            </div>
        </div>

        <!-- Health Check -->
        <div class="card">
            <h3>🏥 Health Check</h3>
            <button class="btn" onclick="runHealthCheck()">Executar Health Check</button>
            <div class="health-check" id="health-results"></div>
        </div>

        <!-- Tabs para diferentes funcionalidades -->
        <div class="card">
            <div class="tabs">
                <div class="tab active" onclick="switchTab('routes')">🛣️ Rotas</div>
                <div class="tab" onclick="switchTab('models')">📋 Modelos</div>
                <div class="tab" onclick="switchTab('terminal')">💻 Terminal</div>
                <div class="tab" onclick="switchTab('tests')">🧪 Testes</div>
                <div class="tab" onclick="switchTab('logs')">📝 Logs</div>
            </div>

            <!-- Tab: Rotas -->
            <div class="tab-content active" id="routes-tab">
                <h3>🛣️ Auto-descoberta de Rotas</h3>
                <button class="btn" onclick="discoverRoutes()">Descobrir Rotas</button>
                <button class="btn btn-success" onclick="testAllRoutes()">Testar Todas as Rotas</button>
                <div id="routes-output"></div>
            </div>

            <!-- Tab: Modelos -->
            <div class="tab-content" id="models-tab">
                <h3>📋 Auto-descoberta de Modelos</h3>
                <button class="btn" onclick="discoverModels()">Descobrir Modelos</button>
                <div id="models-output"></div>
            </div>

            <!-- Tab: Terminal -->
            <div class="tab-content" id="terminal-tab">
                <h3>💻 Terminal Remoto</h3>
                <input type="text" id="command-input" placeholder="Digite um comando (ls, ps, curl, etc.)" onkeypress="handleCommandKeyPress(event)">
                <button class="btn" onclick="executeCommand()">Executar</button>
                <div id="command-output"></div>
            </div>

            <!-- Tab: Testes -->
            <div class="tab-content" id="tests-tab">
                <h3>🧪 Testes de API</h3>
                <div style="margin-bottom: 1rem;">
                    <input type="text" id="test-endpoint" placeholder="/api/endpoint" value="/health">
                    <select id="test-type">
                        <option value="api">Teste de API</option>
                        <option value="route">Teste de Rota Específica</option>
                        <option value="connectivity">Teste de Conectividade</option>
                        <option value="memory">Teste de Memória</option>
                        <option value="all_routes">Testar Todas as Rotas</option>
                    </select>
                    <button class="btn" onclick="runTest()">Executar Teste</button>
                </div>
                <div id="test-output"></div>
            </div>

            <!-- Tab: Logs -->
            <div class="tab-content" id="logs-tab">
                <h3>📝 Logs do Sistema</h3>
                <div style="margin-bottom: 1rem;">
                    <input type="number" id="log-lines" placeholder="Número de linhas" value="50" min="10" max="1000">
                    <button class="btn" onclick="loadLogs()">Atualizar Logs</button>
                    <button class="btn btn-warning" onclick="clearLogs()">Limpar Exibição</button>
                </div>
                <div id="logs" class="logs output">Carregando logs...</div>
            </div>
        </div>

        <!-- Métricas em Tempo Real -->
        <div class="card">
            <h3>📈 Métricas em Tempo Real</h3>
            <button class="btn" onclick="toggleMetricsMonitoring()" id="metrics-btn">Iniciar Monitoramento</button>
            <div class="metric-chart" id="cpu-chart">CPU Usage Chart</div>
            <div class="metric-chart" id="memory-chart">Memory Usage Chart</div>
        </div>
    </div>

    <script>
        let metricsInterval = null;
        let isMonitoring = false;

        // Inicialização
        document.addEventListener('DOMContentLoaded', function() {
            updateSystemStatus();
            loadLogs();
            
            // Auto-refresh status a cada 30 segundos
            setInterval(updateSystemStatus, 30000);
        });

        // Gerenciamento de Tabs
        function switchTab(tabName) {
            // Remover active de todas as tabs
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            
            // Ativar tab selecionada
            event.target.classList.add('active');
            document.getElementById(tabName + '-tab').classList.add('active');
        }

        // Status do Sistema
        async function updateSystemStatus() {
            try {
                const response = await fetch('/api/debug/status');
                if (response.status === 401) { window.location.href = '/login'; return; }
                const data = await response.json();
                
                const statusGrid = document.getElementById('system-status');
                statusGrid.innerHTML = `
                    <div class="status-item">
                        <div class="status-value">✅</div>
                        <div class="status-label">Status: ${data.status}</div>
                    </div>
                    <div class="status-item">
                        <div class="status-value">${data.discovered_routes || 0}</div>
                        <div class="status-label">Rotas Descobertas</div>
                    </div>
                    <div class="status-item">
                        <div class="status-value">${data.discovered_models || 0}</div>
                        <div class="status-label">Modelos Descobertos</div>
                    </div>
                    <div class="status-item">
                        <div class="status-value">${data.active_processes || 0}</div>
                        <div class="status-label">Processos Ativos</div>
                    </div>
                    <div class="status-item">
                        <div class="status-value">${data.uptime || 'N/A'}</div>
                        <div class="status-label">Uptime</div>
                    </div>
                `;
            } catch (error) {
                document.getElementById('system-status').innerHTML = `
                    <div class="status-item">
                        <div class="status-value">❌</div>
                        <div class="status-label">Erro: ${error.message}</div>
                    </div>
                `;
            }
        }

        // Health Check
        async function runHealthCheck() {
            try {
                const response = await fetch('/api/debug/health');
                if (response.status === 401) { window.location.href = '/login'; return; }
                const data = await response.json();
                
                const healthResults = document.getElementById('health-results');
                healthResults.innerHTML = data.checks.map(check => `
                    <div class="health-item health-${check.status}">
                        <strong>${check.name}</strong><br>
                        <span>${check.value || check.error || check.status}</span>
                        ${check.details ? `<br><small>${check.details}</small>` : ''}
                    </div>
                `).join('');
            } catch (error) {
                document.getElementById('health-results').innerHTML = `
                    <div class="health-item health-critical">
                        <strong>Erro</strong><br>
                        <span>${error.message}</span>
                    </div>
                `;
            }
        }

        // Descoberta de Rotas
        async function discoverRoutes() {
            try {
                const response = await fetch('/api/debug/routes');
                if (response.status === 401) { window.location.href = '/login'; return; }
                const data = await response.json();
                
                if (data.success) {
                    const routesOutput = document.getElementById('routes-output');
                    routesOutput.innerHTML = `
                        <div class="output success">
                            <strong>✅ ${data.total} rotas descobertas:</strong><br><br>
                            ${data.routes.map(route => `
                                <div class="route-item">
                                    <strong>${route.rule}</strong>
                                    <div class="route-methods">
                                        ${route.methods.map(method => 
                                            `<span class="method-badge method-${method.toLowerCase()}">${method}</span>`
                                        ).join('')}
                                    </div>
                                    <small>Endpoint: ${route.endpoint}</small><br>
                                    <small>Fonte: ${route.source}</small>
                                    ${route.docstring ? `<br><small>Descrição: ${route.docstring}</small>` : ''}
                                    <button class="btn" style="margin-top: 0.5rem;" onclick="testRoute('${route.endpoint}')">Testar Rota</button>
                                </div>
                            `).join('')}
                        </div>
                    `;
                } else {
                    document.getElementById('routes-output').innerHTML = `
                        <div class="output error">❌ Erro: ${data.error}</div>
                    `;
                }
            } catch (error) {
                document.getElementById('routes-output').innerHTML = `
                    <div class="output error">❌ Erro de rede: ${error.message}</div>
                `;
            }
        }

        // Descoberta de Modelos
        async function discoverModels() {
            try {
                const response = await fetch('/api/debug/models');
                if (response.status === 401) { window.location.href = '/login'; return; }
                const data = await response.json();
                
                if (data.success) {
                    const modelsOutput = document.getElementById('models-output');
                    modelsOutput.innerHTML = `
                        <div class="output success">
                            <strong>✅ ${data.total} modelos descobertos:</strong><br><br>
                            ${data.models.map(model => `
                                <div class="model-item">
                                    <strong>${model.name}</strong> (${model.file})<br>
                                    ${model.docstring ? `<em>${model.docstring}</em><br>` : ''}
                                    <strong>Métodos:</strong> ${model.methods.map(m => m.name).join(', ')}<br>
                                    <strong>Atributos:</strong> ${model.attributes.map(a => a.name).join(', ')}
                                </div>
                            `).join('')}
                        </div>
                    `;
                } else {
                    document.getElementById('models-output').innerHTML = `
                        <div class="output error">❌ Erro: ${data.error}</div>
                    `;
                }
            } catch (error) {
                document.getElementById('models-output').innerHTML = `
                    <div class="output error">❌ Erro de rede: ${error.message}</div>
                `;
            }
        }
    </script>
</body>
</html>
'''

# =============================================================================
# PONTO DE ENTRADA
# =============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Enhanced Debug Server')
    parser.add_argument('--host', default='127.0.0.1', help='Host para bind do servidor')
    parser.add_argument('--port', type=int, default=8081, help='Porta para o servidor')
    parser.add_argument('--debug', action='store_true', help='Modo debug')
    
    args = parser.parse_args()
    
    server = EnhancedDebugServer()
    server.run(host=args.host, port=args.port, debug=args.debug)
