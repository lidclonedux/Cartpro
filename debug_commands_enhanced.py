# debug_commands_enhanced.py - Comandos de Debug Aprimorados
# Santo Graal Prodígio - Sistema de Debug Avançado

import os
import sys
import json
import time
import subprocess
import argparse
import requests
from datetime import datetime
from pathlib import Path

class EnhancedDebugCommands:
    def __init__(self, server_url="http://localhost:8080"):
        self.server_url = server_url
        self.config_file = "debug_config.json"
        self.load_config()
        self.setup_colors()
    
    def load_config(self):
        """Carrega configuração do arquivo JSON"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.config = json.load(f)
            else:
                self.config = self.get_default_config()
        except Exception as e:
            print(f"Erro ao carregar configuração: {e}")
            self.config = self.get_default_config()
    
    def get_default_config(self):
        """Configuração padrão"""
        return {
            "debug_server": {
                "host": "localhost",
                "port": 8080
            },
            "main_app": {
                "host": "localhost", 
                "port": 5000
            }
        }
    
    def setup_colors(self):
        """Configuração de cores para terminal"""
        self.colors = {
            'RED': '\033[0;31m',
            'GREEN': '\033[0;32m',
            'YELLOW': '\033[1;33m',
            'BLUE': '\033[0;34m',
            'PURPLE': '\033[0;35m',
            'CYAN': '\033[0;36m',
            'WHITE': '\033[1;37m',
            'BOLD': '\033[1m',
            'NC': '\033[0m'  # No Color
        }
    
    def colored_print(self, message, color='WHITE'):
        """Print colorido"""
        color_code = self.colors.get(color.upper(), self.colors['WHITE'])
        print(f"{color_code}{message}{self.colors['NC']}")
    
    def print_header(self, title):
        """Cabeçalho estilizado"""
        self.colored_print("=" * 60, 'CYAN')
        self.colored_print(f"🚀 {title.upper()}", 'YELLOW')
        self.colored_print("=" * 60, 'CYAN')
    
    def print_section(self, title):
        """Seção estilizada"""
        self.colored_print(f"\n📋 {title}", 'BLUE')
        self.colored_print("-" * 40, 'BLUE')
    
    def check_server_connectivity(self):
        """Verifica conectividade com o servidor de debug"""
        try:
            response = requests.get(f"{self.server_url}/api/debug/status", timeout=5)
            return response.status_code == 200, response.json() if response.status_code == 200 else None
        except requests.exceptions.ConnectionError:
            return False, {"error": "Conexão recusada - servidor não está rodando"}
        except requests.exceptions.Timeout:
            return False, {"error": "Timeout - servidor não responde"}
        except Exception as e:
            return False, {"error": str(e)}
    
    def cmd_status(self):
        """Status completo do sistema"""
        self.print_header("ENHANCED DEBUG STATUS")
        
        # Verificar conectividade
        server_running, server_data = self.check_server_connectivity()
        
        if server_running:
            self.colored_print("✅ Enhanced Debug Server: ONLINE", 'GREEN')
            self.colored_print(f"   URL: {self.server_url}", 'WHITE')
            self.colored_print(f"   Timestamp: {server_data.get('timestamp', 'N/A')}", 'WHITE')
            self.colored_print(f"   Uptime: {server_data.get('uptime', 'N/A')}", 'WHITE')
            
            # Informações descobertas
            self.print_section("Auto-descoberta")
            self.colored_print(f"🛣️  Rotas descobertas: {server_data.get('discovered_routes', 0)}", 'CYAN')
            self.colored_print(f"📋 Modelos descobertos: {server_data.get('discovered_models', 0)}", 'CYAN')
            self.colored_print(f"⚡ Processos ativos: {server_data.get('active_processes', 0)}", 'CYAN')
            
            # Informações de memória
            if 'memory_info' in server_data:
                mem_info = server_data['memory_info']
                if 'system' in mem_info:
                    mem_system = mem_info['system']
                    total_gb = mem_system.get('total', 0) / (1024**3)
                    available_gb = mem_system.get('available', 0) / (1024**3)
                    percent = mem_system.get('percent', 0)
                    
                    self.print_section("Memória do Sistema")
                    self.colored_print(f"💾 Total: {total_gb:.1f}GB", 'WHITE')
                    self.colored_print(f"💾 Disponível: {available_gb:.1f}GB", 'WHITE')
                    self.colored_print(f"💾 Uso: {percent:.1f}%", 'WHITE')
        else:
            self.colored_print("❌ Enhanced Debug Server: OFFLINE", 'RED')
            error_msg = server_data.get('error', 'Erro desconhecido') if server_data else 'Servidor não acessível'
            self.colored_print(f"   Erro: {error_msg}", 'RED')
            self.colored_print(f"   URL tentada: {self.server_url}", 'WHITE')
        
        # Verificar servidor principal
        self.print_section("Servidor Principal")
        main_url = f"http://{self.config['main_app']['host']}:{self.config['main_app']['port']}"
        try:
            response = requests.get(f"{main_url}/api/debug/status", timeout=3)
            if response.status_code == 200:
                self.colored_print("✅ Main App: ONLINE", 'GREEN')
                self.colored_print(f"   URL: {main_url}", 'WHITE')
            else:
                self.colored_print(f"⚠️  Main App: HTTP {response.status_code}", 'YELLOW')
        except:
            self.colored_print("❌ Main App: OFFLINE", 'RED')
            self.colored_print(f"   URL: {main_url}", 'WHITE')
        
        # URLs úteis
        self.print_section("URLs de Acesso")
        self.colored_print(f"🌐 Debug Panel: {self.server_url}/debug-panel", 'CYAN')
        self.colored_print(f"📊 API Status: {self.server_url}/api/debug/status", 'CYAN')
        self.colored_print(f"🛣️  Routes: {self.server_url}/api/debug/routes", 'CYAN')
        self.colored_print(f"📋 Models: {self.server_url}/api/debug/models", 'CYAN')
        self.colored_print(f"🏥 Health: {self.server_url}/api/debug/health", 'CYAN')
    
    def cmd_routes(self):
        """Descobrir e listar rotas"""
        self.print_header("AUTO-DESCOBERTA DE ROTAS")
        
        try:
            response = requests.get(f"{self.server_url}/api/debug/routes", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    routes = data.get('routes', [])
                    self.colored_print(f"✅ {len(routes)} rotas descobertas:", 'GREEN')
                    
                    # Agrupar por fonte
                    sources = {}
                    for route in routes:
                        source = route.get('source', 'unknown')
                        if source not in sources:
                            sources[source] = []
                        sources[source].append(route)
                    
                    for source, source_routes in sources.items():
                        self.print_section(f"Fonte: {source}")
                        for route in source_routes:
                            methods = ', '.join(route.get('methods', []))
                            self.colored_print(f"🛣️  {route['rule']}", 'CYAN')
                            self.colored_print(f"   Métodos: {methods}", 'WHITE')
                            self.colored_print(f"   Endpoint: {route['endpoint']}", 'WHITE')
                            if route.get('docstring'):
                                self.colored_print(f"   Descrição: {route['docstring']}", 'WHITE')
                            print()
                else:
                    self.colored_print(f"❌ Erro: {data.get('error')}", 'RED')
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_models(self):
        """Descobrir e listar modelos"""
        self.print_header("AUTO-DESCOBERTA DE MODELOS")
        
        try:
            response = requests.get(f"{self.server_url}/api/debug/models", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    models = data.get('models', [])
                    self.colored_print(f"✅ {len(models)} modelos descobertos:", 'GREEN')
                    
                    for model in models:
                        self.colored_print(f"\n📋 {model['name']}", 'CYAN')
                        self.colored_print(f"   Arquivo: {model['file']}", 'WHITE')
                        self.colored_print(f"   Módulo: {model['module']}", 'WHITE')
                        
                        if model.get('docstring'):
                            self.colored_print(f"   Descrição: {model['docstring']}", 'WHITE')
                        
                        methods = [m['name'] for m in model.get('methods', [])]
                        if methods:
                            self.colored_print(f"   Métodos: {', '.join(methods)}", 'WHITE')
                        
                        attributes = [a['name'] for a in model.get('attributes', [])]
                        if attributes:
                            self.colored_print(f"   Atributos: {', '.join(attributes)}", 'WHITE')
                else:
                    self.colored_print(f"❌ Erro: {data.get('error')}", 'RED')
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_test(self, test_type='all', endpoint=None):
        """Executar testes"""
        self.print_header(f"EXECUTANDO TESTES: {test_type.upper()}")
        
        try:
            payload = {'type': test_type}
            if endpoint:
                payload['endpoint'] = endpoint
            
            response = requests.post(
                f"{self.server_url}/api/debug/test",
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    self.colored_print("✅ Teste executado com sucesso!", 'GREEN')
                    
                    if test_type == 'connectivity':
                        self.print_section("Testes de Conectividade")
                        for test in data.get('tests', []):
                            status = "✅" if test['success'] else "❌"
                            self.colored_print(f"{status} {test['name']}: {test['details']}", 'WHITE')
                            if 'response_time' in test:
                                self.colored_print(f"   Tempo: {test['response_time']:.2f}ms", 'WHITE')
                    
                    elif test_type == 'api':
                        self.print_section("Teste de API")
                        self.colored_print(f"URL: {data.get('url')}", 'WHITE')
                        self.colored_print(f"Status: {data.get('status_code')}", 'WHITE')
                        self.colored_print(f"Tempo: {data.get('response_time_ms')}ms", 'WHITE')
                        self.colored_print(f"Tamanho: {data.get('content_length')} bytes", 'WHITE')
                    
                    elif test_type == 'all_routes':
                        self.print_section("Teste de Todas as Rotas")
                        self.colored_print(f"Total testado: {data.get('total_routes_tested')}", 'WHITE')
                        
                        for result in data.get('results', []):
                            endpoint_name = result.get('endpoint', 'N/A')
                            self.colored_print(f"\n🛣️  {endpoint_name}", 'CYAN')
                            
                            for test_result in result.get('test_results', []):
                                method = test_result.get('method')
                                success = test_result.get('success')
                                status = "✅" if success else "❌"
                                status_code = test_result.get('status_code', 'N/A')
                                response_time = test_result.get('response_time_ms', 'N/A')
                                
                                self.colored_print(f"   {status} {method}: HTTP {status_code} ({response_time}ms)", 'WHITE')
                    
                    elif test_type == 'memory':
                        self.print_section("Teste de Memória")
                        mem_info = data.get('memory_info', {})
                        if 'system' in mem_info:
                            sys_mem = mem_info['system']
                            self.colored_print(f"Sistema - Uso: {sys_mem.get('percent', 0):.1f}%", 'WHITE')
                            self.colored_print(f"Sistema - Total: {sys_mem.get('total', 0) / (1024**3):.1f}GB", 'WHITE')
                        
                        self.colored_print(f"Objetos Python: {data.get('python_objects', 0)}", 'WHITE')
                        
                else:
                    self.colored_print(f"❌ Erro no teste: {data.get('error')}", 'RED')
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_health(self):
        """Health check completo"""
        self.print_header("HEALTH CHECK COMPLETO")
        
        try:
            response = requests.get(f"{self.server_url}/api/debug/health", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                overall_status = data.get('overall_status', 'unknown')
                
                # Status geral
                if overall_status == 'healthy':
                    self.colored_print("✅ Status Geral: SAUDÁVEL", 'GREEN')
                elif overall_status == 'warning':
                    self.colored_print("⚠️  Status Geral: ATENÇÃO", 'YELLOW')
                else:
                    self.colored_print("❌ Status Geral: CRÍTICO", 'RED')
                
                # Checks individuais
                self.print_section("Verificações Individuais")
                for check in data.get('checks', []):
                    name = check.get('name')
                    status = check.get('status')
                    value = check.get('value', '')
                    details = check.get('details', '')
                    error = check.get('error', '')
                    
                    if status == 'healthy':
                        icon = "✅"
                        color = 'GREEN'
                    elif status == 'warning':
                        icon = "⚠️"
                        color = 'YELLOW'
                    elif status == 'critical':
                        icon = "❌"
                        color = 'RED'
                    else:
                        icon = "❓"
                        color = 'WHITE'
                    
                    self.colored_print(f"{icon} {name}: {value}", color)
                    if details:
                        self.colored_print(f"   {details}", 'WHITE')
                    if error:
                        self.colored_print(f"   Erro: {error}", 'RED')
                
                timestamp = data.get('timestamp', '')
                self.colored_print(f"\n🕐 Timestamp: {timestamp}", 'CYAN')
                
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_execute(self, command):
        """Executar comando remoto"""
        self.print_header(f"EXECUTANDO: {command}")
        
        try:
            response = requests.post(
                f"{self.server_url}/api/debug/execute",
                json={'command': command},
                timeout=35
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    self.colored_print(f"✅ Comando executado com sucesso!", 'GREEN')
                    self.colored_print(f"Return Code: {data.get('return_code')}", 'BLUE')
                    self.colored_print(f"Timestamp: {data.get('timestamp')}", 'BLUE')
                    
                    stdout = data.get('stdout', '')
                    stderr = data.get('stderr', '')
                    
                    if stdout:
                        self.print_section("STDOUT")
                        print(stdout)
                    
                    if stderr:
                        self.print_section("STDERR")
                        self.colored_print(stderr, 'RED')
                    
                    if not stdout and not stderr:
                        self.colored_print("(Sem output)", 'YELLOW')
                        
                else:
                    self.colored_print(f"❌ Erro: {data.get('error')}", 'RED')
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_logs(self, lines=50):
        """Visualizar logs"""
        self.print_header(f"LOGS RECENTES ({lines} linhas)")
        
        try:
            response = requests.get(f"{self.server_url}/api/debug/logs?lines={lines}", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                logs = data.get('logs', [])
                
                if logs:
                    for log_line in logs:
                        line = log_line.strip()
                        if '[ERROR]' in line:
                            self.colored_print(line, 'RED')
                        elif '[WARNING]' in line:
                            self.colored_print(line, 'YELLOW')
                        elif '[INFO]' in line:
                            self.colored_print(line, 'BLUE')
                        else:
                            self.colored_print(line, 'WHITE')
                else:
                    self.colored_print("Nenhum log encontrado", 'YELLOW')
                    
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_metrics(self):
        """Métricas do sistema"""
        self.print_header("MÉTRICAS DO SISTEMA")
        
        try:
            response = requests.get(f"{self.server_url}/api/debug/metrics", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                # CPU
                if 'cpu' in data:
                    cpu = data['cpu']
                    self.print_section("CPU")
                    self.colored_print(f"💻 Uso: {cpu.get('percent', 0):.1f}%", 'CYAN')
                    self.colored_print(f"💻 Cores: {cpu.get('count', 0)}", 'CYAN')
                
                # Memória
                if 'memory' in data:
                    memory = data['memory']
                    if 'system' in memory:
                        sys_mem = memory['system']
                        self.print_section("Memória")
                        total_gb = sys_mem.get('total', 0) / (1024**3)
                        used_gb = sys_mem.get('used', 0) / (1024**3)
                        percent = sys_mem.get('percent', 0)
                        self.colored_print(f"💾 Total: {total_gb:.1f}GB", 'CYAN')
                        self.colored_print(f"💾 Usado: {used_gb:.1f}GB ({percent:.1f}%)", 'CYAN')
                
                # Disco
                if 'disk' in data:
                    disk = data['disk']
                    self.print_section("Disco")
                    total_gb = disk.get('total', 0) / (1024**3)
                    used_gb = disk.get('used', 0) / (1024**3)
                    percent = disk.get('percent', 0)
                    self.colored_print(f"💽 Total: {total_gb:.1f}GB", 'CYAN')
                    self.colored_print(f"💽 Usado: {used_gb:.1f}GB ({percent:.1f}%)", 'CYAN')
                
                # Processos Python
                python_procs = data.get('python_processes', [])
                if python_procs:
                    self.print_section("Processos Python")
                    for proc in python_procs[:5]:  # Mostrar apenas os 5 primeiros
                        pid = proc.get('pid', 'N/A')
                        name = proc.get('name', 'N/A')
                        cpu_percent = proc.get('cpu_percent', 0)
                        mem_percent = proc.get('memory_percent', 0)
                        self.colored_print(f"🐍 PID {pid}: {name} (CPU: {cpu_percent:.1f}%, MEM: {mem_percent:.1f}%)", 'WHITE')
                
                # Uptime
                uptime = data.get('uptime', 'N/A')
                self.colored_print(f"\n⏰ Uptime: {uptime}", 'CYAN')
                
            else:
                self.colored_print(f"❌ HTTP {response.status_code}", 'RED')
                
        except Exception as e:
            self.colored_print(f"❌ Erro de conexão: {e}", 'RED')
    
    def cmd_monitor(self, interval=5):
        """Monitor contínuo"""
        self.colored_print(f"🔍 Iniciando monitor (atualização a cada {interval}s, Ctrl+C para parar)", 'YELLOW')
        
        try:
            while True:
                os.system('clear' if os.name == 'posix' else 'cls')
                self.cmd_status()
                
                self.colored_print(f"\n⏰ Última atualização: {datetime.now().strftime('%H:%M:%S')}", 'CYAN')
                self.colored_print(f"🔄 Próxima atualização em {interval}s (Ctrl+C para parar)", 'BLUE')
                
                time.sleep(interval)
        except KeyboardInterrupt:
            self.colored_print("\n👋 Monitor parado", 'YELLOW')
    
    def cmd_open(self, target='panel'):
        """Abrir URLs no navegador"""
        urls = {
            'panel': f"{self.server_url}/debug-panel",
            'status': f"{self.server_url}/api/debug/status",
            'routes': f"{self.server_url}/api/debug/routes",
            'models': f"{self.server_url}/api/debug/models",
            'health': f"{self.server_url}/api/debug/health"
        }
        
        if target not in urls:
            self.colored_print(f"❌ Target inválido. Opções: {', '.join(urls.keys())}", 'RED')
            return
        
        url = urls[target]
        self.colored_print(f"🌐 Abrindo: {url}", 'CYAN')
        
        try:
            import webbrowser
            webbrowser.open(url)
            self.colored_print("✅ URL aberta no navegador!", 'GREEN')
        except Exception as e:
            self.colored_print(f"❌ Erro ao abrir navegador: {e}", 'RED')
            self.colored_print(f"Acesse manualmente: {url}", 'YELLOW')

def main():
    parser = argparse.ArgumentParser(description='Enhanced Debug Commands - Santo Graal Prodígio')
    parser.add_argument('--server', default='http://localhost:8080', help='URL do debug server')
    
    subparsers = parser.add_subparsers(dest='command', help='Comandos disponíveis')
    
    # Comando status
    subparsers.add_parser('status', help='Status completo do sistema')
    
    # Comando routes
    subparsers.add_parser('routes', help='Descobrir e listar rotas')
    
    # Comando models
    subparsers.add_parser('models', help='Descobrir e listar modelos')
    
    # Comando test
    test_parser = subparsers.add_parser('test', help='Executar testes')
    test_parser.add_argument('type', nargs='?', default='connectivity',
                           choices=['api', 'connectivity', 'memory', 'all_routes'],
                           help='Tipo de teste')
    test_parser.add_argument('--endpoint', help='Endpoint para teste de API')
    
    # Comando health
    subparsers.add_parser('health', help='Health check completo')
    
    # Comando execute
    exec_parser = subparsers.add_parser('exec', help='Executar comando remoto')
    exec_parser.add_argument('command', nargs='+', help='Comando para executar')
    
    # Comando logs
    logs_parser = subparsers.add_parser('logs', help='Visualizar logs')
    logs_parser.add_argument('-n', '--lines', type=int, default=50, help='Número de linhas')
    
    # Comando metrics
    subparsers.add_parser('metrics', help='Métricas do sistema')
    
    # Comando monitor
    monitor_parser = subparsers.add_parser('monitor', help='Monitor contínuo')
    monitor_parser.add_argument('-i', '--interval', type=int, default=5, help='Intervalo em segundos')
    
    # Comando open
    open_parser = subparsers.add_parser('open', help='Abrir URLs no navegador')
    open_parser.add_argument('target', nargs='?', default='panel',
                           choices=['panel', 'status', 'routes', 'models', 'health'],
                           help='Target para abrir')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    debug_cmd = EnhancedDebugCommands(server_url=args.server)
    
    if args.command == 'status':
        debug_cmd.cmd_status()
    elif args.command == 'routes':
        debug_cmd.cmd_routes()
    elif args.command == 'models':
        debug_cmd.cmd_models()
    elif args.command == 'test':
        debug_cmd.cmd_test(args.type, args.endpoint)
    elif args.command == 'health':
        debug_cmd.cmd_health()
    elif args.command == 'exec':
        command = ' '.join(args.command)
        debug_cmd.cmd_execute(command)
    elif args.command == 'logs':
        debug_cmd.cmd_logs(args.lines)
    elif args.command == 'metrics':
        debug_cmd.cmd_metrics()
    elif args.command == 'monitor':
        debug_cmd.cmd_monitor(args.interval)
    elif args.command == 'open':
        debug_cmd.cmd_open(args.target)

if __name__ == '__main__':
    main()

