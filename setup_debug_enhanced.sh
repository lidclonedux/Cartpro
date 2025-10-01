#!/bin/bash

# setup_debug_enhanced.sh - Script de Setup do Debug Server Aprimorado
# Santo Graal Prodígio - Sistema de Debug Avançado

echo "🚀 Configurando Enhanced Debug Server - Santo Graal Prodígio"
echo "============================================================"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se estamos no diretório correto
if [ ! -f "src/main.py" ]; then
    print_error "Arquivo src/main.py não encontrado!"
    print_error "Execute este script na raiz do projeto Backend/"
    exit 1
fi

print_status "Verificando estrutura do projeto..."

# Verificar dependências Python
print_status "Verificando dependências Python..."

REQUIRED_PACKAGES=(
    "flask"
    "psutil"
    "requests"
    "werkzeug"
)

MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python3 -c "import $package" 2>/dev/null; then
        MISSING_PACKAGES+=($package)
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    print_warning "Instalando dependências faltantes: ${MISSING_PACKAGES[*]}"
    pip3 install "${MISSING_PACKAGES[@]}"
    
    if [ $? -eq 0 ]; then
        print_success "Dependências instaladas com sucesso!"
    else
        print_error "Falha ao instalar dependências!"
        exit 1
    fi
else
    print_success "Todas as dependências estão instaladas!"
fi

# Criar diretórios necessários
print_status "Criando diretórios necessários..."

DIRECTORIES=(
    "logs"
    "debug_data"
    "temp"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Diretório $dir criado"
    fi
done

# Verificar se o Flutter Web build existe
print_status "Verificando Flutter Web build..."

if [ ! -d "static" ]; then
    print_warning "Diretório static/ não encontrado!"
    print_warning "Criando estrutura básica..."
    mkdir -p static/web
    
    # Criar index.html básico se não existir
    if [ ! -f "static/web/index.html" ]; then
        cat > static/web/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Flutter Web App</title>
</head>
<body>
    <div id="loading">
        <h2>Flutter Web App</h2>
        <p>Carregando aplicação...</p>
    </div>
</body>
</html>
EOF
        print_success "Arquivo static/web/index.html criado"
    fi
else
    print_success "Diretório static/ encontrado!"
fi

# Criar arquivo de configuração do debug
print_status "Criando arquivo de configuração..."

cat > debug_config.json << EOF
{
    "debug_server": {
        "host": "0.0.0.0",
        "port": 8080,
        "auto_reload": true,
        "log_level": "INFO"
    },
    "main_app": {
        "host": "localhost",
        "port": 5000,
        "path": "src"
    },
    "monitoring": {
        "auto_discover_routes": true,
        "auto_discover_models": true,
        "metrics_interval": 30,
        "log_rotation_size": "2MB",
        "log_backup_count": 5
    },
    "security": {
        "allowed_commands": [
            "ls", "pwd", "ps", "df", "free", "uname", "whoami",
            "curl", "wget", "ping", "netstat", "ss",
            "python", "pip", "flask", "gunicorn",
            "git", "cat", "head", "tail", "grep",
            "find", "which", "echo", "date", "uptime"
        ],
        "command_timeout": 30,
        "max_log_lines": 1000
    }
}
EOF

print_success "Arquivo debug_config.json criado!"

# Criar script de inicialização rápida
print_status "Criando script de inicialização rápida..."

cat > start_debug.sh << 'EOF'
#!/bin/bash

# start_debug.sh - Inicialização Rápida do Debug Server

echo "🚀 Iniciando Enhanced Debug Server..."

# Verificar se o servidor principal está rodando
if curl -s http://localhost:5000/api/debug/status > /dev/null 2>&1; then
    echo "✅ Servidor principal detectado em localhost:5000"
else
    echo "⚠️  Servidor principal não detectado em localhost:5000"
    echo "   Certifique-se de que src/main.py está rodando"
fi

# Iniciar debug server
python3 debug_server_enhanced.py --port 8080 --host 0.0.0.0

EOF

chmod +x start_debug.sh
print_success "Script start_debug.sh criado!"

# Criar script de parada
print_status "Criando script de parada..."

cat > stop_debug.sh << 'EOF'
#!/bin/bash

# stop_debug.sh - Parar Debug Server

echo "🛑 Parando Enhanced Debug Server..."

# Encontrar e matar processos do debug server
PIDS=$(ps aux | grep "debug_server_enhanced.py" | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "ℹ️  Nenhum processo do debug server encontrado"
else
    for PID in $PIDS; do
        echo "🔪 Matando processo $PID"
        kill -TERM $PID
        sleep 2
        
        # Verificar se ainda está rodando
        if kill -0 $PID 2>/dev/null; then
            echo "💀 Forçando parada do processo $PID"
            kill -KILL $PID
        fi
    done
    echo "✅ Debug server parado!"
fi

EOF

chmod +x stop_debug.sh
print_success "Script stop_debug.sh criado!"

# Criar script de status
print_status "Criando script de status..."

cat > debug_status.sh << 'EOF'
#!/bin/bash

# debug_status.sh - Status do Debug Server

echo "📊 Status do Enhanced Debug Server"
echo "=================================="

# Verificar se está rodando
PIDS=$(ps aux | grep "debug_server_enhanced.py" | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "❌ Debug Server: OFFLINE"
else
    echo "✅ Debug Server: ONLINE"
    for PID in $PIDS; do
        echo "   PID: $PID"
        echo "   Memória: $(ps -p $PID -o rss= | awk '{print $1/1024 " MB"}')"
        echo "   CPU: $(ps -p $PID -o %cpu= | awk '{print $1"%"}')"
    done
fi

# Verificar conectividade
echo ""
echo "🌐 Conectividade:"

if curl -s http://localhost:8080/api/debug/status > /dev/null 2>&1; then
    echo "✅ Debug API: http://localhost:8080/api/debug/status"
else
    echo "❌ Debug API: Não acessível"
fi

if curl -s http://localhost:8080/debug-panel > /dev/null 2>&1; then
    echo "✅ Debug Panel: http://localhost:8080/debug-panel"
else
    echo "❌ Debug Panel: Não acessível"
fi

# Verificar logs
echo ""
echo "📝 Logs:"
if [ -f "debug_enhanced.log" ]; then
    LOG_SIZE=$(du -h debug_enhanced.log | cut -f1)
    LOG_LINES=$(wc -l < debug_enhanced.log)
    echo "✅ Log file: debug_enhanced.log ($LOG_SIZE, $LOG_LINES linhas)"
    echo "   Últimas 3 linhas:"
    tail -3 debug_enhanced.log | sed 's/^/   /'
else
    echo "❌ Log file: Não encontrado"
fi

EOF

chmod +x debug_status.sh
print_success "Script debug_status.sh criado!"

# Criar arquivo README para o debug
print_status "Criando documentação..."

cat > DEBUG_README.md << 'EOF'
# Enhanced Debug Server - Santo Graal Prodígio

Sistema de debug avançado com auto-descoberta de rotas e modelos.

## 🚀 Inicialização Rápida

```bash
# Iniciar debug server
./start_debug.sh

# Verificar status
./debug_status.sh

# Parar debug server
./stop_debug.sh
```

## 🌐 URLs de Acesso

- **Debug Panel**: http://localhost:8080/debug-panel
- **Flutter App**: http://localhost:8080/
- **API Status**: http://localhost:8080/api/debug/status
- **Rotas**: http://localhost:8080/api/debug/routes
- **Modelos**: http://localhost:8080/api/debug/models

## 🔧 Funcionalidades

### Auto-descoberta
- ✅ Descoberta automática de rotas Flask
- ✅ Descoberta automática de modelos de dados
- ✅ Mapeamento de blueprints
- ✅ Análise de parâmetros e documentação

### Testes
- ✅ Teste individual de rotas
- ✅ Teste em lote de todas as rotas
- ✅ Testes de conectividade
- ✅ Testes de memória
- ✅ Health checks completos

### Monitoramento
- ✅ Métricas de sistema em tempo real
- ✅ Monitoramento de CPU e memória
- ✅ Logs estruturados com rotação
- ✅ Histórico de comandos

### Terminal
- ✅ Execução remota de comandos
- ✅ Lista de comandos permitidos
- ✅ Timeout de segurança
- ✅ Histórico de execuções

## 📊 Interface Web

O painel web oferece:

1. **Dashboard**: Status geral do sistema
2. **Rotas**: Auto-descoberta e teste de endpoints
3. **Modelos**: Análise de estruturas de dados
4. **Terminal**: Execução remota de comandos
5. **Testes**: Suite completa de testes
6. **Logs**: Visualização em tempo real
7. **Métricas**: Gráficos de performance

## ⚙️ Configuração

Edite `debug_config.json` para personalizar:

- Portas e hosts
- Comandos permitidos
- Intervalos de monitoramento
- Configurações de log

## 🔒 Segurança

- Lista restrita de comandos permitidos
- Timeout para execuções
- Logs de todas as ações
- Validação de entrada

## 📝 Logs

- Arquivo: `debug_enhanced.log`
- Rotação automática (2MB)
- 5 backups mantidos
- Níveis: DEBUG, INFO, WARNING, ERROR

## 🐛 Troubleshooting

### Debug server não inicia
```bash
# Verificar dependências
pip3 install flask psutil requests werkzeug

# Verificar porta
netstat -tlnp | grep :8080
```

### Rotas não descobertas
```bash
# Verificar se main.py está acessível
python3 -c "from src.main import app; print('OK')"
```

### Testes falhando
```bash
# Verificar se servidor principal está rodando
curl http://localhost:5000/api/debug/status
```

## 📞 Suporte

Para problemas ou sugestões, verifique:
1. Logs em `debug_enhanced.log`
2. Status com `./debug_status.sh`
3. Configuração em `debug_config.json`
EOF

print_success "Documentação DEBUG_README.md criada!"

# Verificar integridade dos arquivos criados
print_status "Verificando integridade dos arquivos..."

FILES_TO_CHECK=(
    "debug_server_enhanced.py"
    "debug_config.json"
    "start_debug.sh"
    "stop_debug.sh"
    "debug_status.sh"
    "DEBUG_README.md"
)

ALL_OK=true

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        print_success "✅ $file"
    else
        print_error "❌ $file não encontrado!"
        ALL_OK=false
    fi
done

# Teste rápido de sintaxe Python
print_status "Testando sintaxe do debug server..."

if python3 -m py_compile debug_server_enhanced.py; then
    print_success "✅ Sintaxe Python válida!"
else
    print_error "❌ Erro de sintaxe no debug server!"
    ALL_OK=false
fi

# Resumo final
echo ""
echo "============================================================"
if [ "$ALL_OK" = true ]; then
    print_success "🎉 Setup concluído com sucesso!"
    echo ""
    echo -e "${CYAN}Próximos passos:${NC}"
    echo "1. Execute: ${YELLOW}./start_debug.sh${NC}"
    echo "2. Acesse: ${YELLOW}http://localhost:8080/debug-panel${NC}"
    echo "3. Verifique: ${YELLOW}./debug_status.sh${NC}"
    echo ""
    echo -e "${GREEN}Enhanced Debug Server - Santo Graal Prodígio está pronto!${NC}"
else
    print_error "❌ Setup concluído com erros!"
    echo "Verifique os erros acima e tente novamente."
    exit 1
fi

echo "============================================================"

