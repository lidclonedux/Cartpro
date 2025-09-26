#!/bin/bash

# Script de Debug Flutter para Ubuntu (no Termux)
# Salva em: ~/flutter_debug_logs/

# Criar diretório de logs
LOG_DIR="$HOME/flutter_debug_logs"
mkdir -p "$LOG_DIR"

# Nome do arquivo com timestamp
LOG_FILE="$LOG_DIR/flutter_debug_$(date +%Y%m%d_%H%M%S).log"

# Cores para terminal
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${GREEN}🚀 Flutter Debug Logger - Ubuntu${NC}"
echo -e "${BLUE}📱 Sistema: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')${NC}"
echo -e "${BLUE}📝 Arquivo de log: $LOG_FILE${NC}"
echo -e "${PURPLE}🔍 Pressione Ctrl+C para parar${NC}"
echo "============================================"

# Verificar se Flutter está disponível
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter não encontrado no PATH${NC}"
    echo -e "${YELLOW}💡 Certifique-se de que Flutter está instalado e no PATH${NC}"
    exit 1
fi

# Função para processar cada linha
process_line() {
    local line="$1"
    local timestamp=$(date '+%H:%M:%S')
    local formatted="[$timestamp] $line"
    
    # Salvar no arquivo (sempre)
    echo "$formatted" >> "$LOG_FILE"
    
    # Mostrar no terminal com cores
    if [[ $line == *"ERROR"* ]] || [[ $line == *"Exception"* ]] || [[ $line == *"FATAL"* ]]; then
        echo -e "${RED}🔴 $formatted${NC}"
    elif [[ $line == *"WARNING"* ]] || [[ $line == *"WARN"* ]]; then
        echo -e "${YELLOW}⚠️  $formatted${NC}"
    elif [[ $line == *"token"* ]] || [[ $line == *"auth"* ]] || [[ $line == *"Token"* ]] || [[ $line == *"JWT"* ]]; then
        echo -e "${PURPLE}🔑 $formatted${NC}"
    elif [[ $line == *"http"* ]] || [[ $line == *"HTTP"* ]] || [[ $line == *"localhost"* ]] || [[ $line == *"38143"* ]]; then
        echo -e "${BLUE}🌐 $formatted${NC}"
    elif [[ $line == *"INFO"* ]]; then
        echo -e "${GREEN}ℹ️  $formatted${NC}"
    else
        echo "$formatted"
    fi
}

# Verificar se Flutter está rodando
echo -e "${GREEN}📡 Iniciando captura de logs...${NC}"
echo -e "${YELLOW}💡 Se Flutter não estiver rodando, inicie em outra sessão:${NC}"
echo -e "${BLUE}   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080${NC}"
echo ""

# Capturar logs
flutter logs --verbose 2>&1 | while IFS= read -r line; do
    process_line "$line"
done
