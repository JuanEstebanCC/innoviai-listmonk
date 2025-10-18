#!/bin/bash

# Script de instalación nativa de Listmonk en EC2 (sin Docker)
# Para Amazon Linux 2023

set -e

echo "======================================"
echo "Listmonk EC2 Native Installation"
echo "======================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${NC}→ $1${NC}"
}

# Verificar que estamos en el directorio correcto
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

print_info "======================================"
print_info "Instalando dependencias del sistema"
print_info "======================================"
echo ""

# Actualizar el sistema
print_info "Actualizando paquetes del sistema..."
sudo dnf update -y -q
print_success "Sistema actualizado"

# Instalar dependencias básicas
print_info "Instalando herramientas básicas..."
sudo dnf install -y wget git tar gzip 2>/dev/null || true
print_success "Herramientas básicas instaladas"

# Instalar Node.js 20
print_info "Instalando Node.js 20..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
    sudo dnf install -y nodejs
    print_success "Node.js instalado: $(node --version)"
else
    print_success "Node.js ya instalado: $(node --version)"
fi

# Instalar Yarn
print_info "Instalando Yarn..."
sudo npm install -g yarn
print_success "Yarn instalado: $(yarn --version)"

# Instalar Go 1.22+
print_info "Instalando Go..."
GO_VERSION="1.23.4"
if ! command -v go &> /dev/null; then
    cd /tmp
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # Agregar Go al PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    fi
    
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    cd "$SCRIPT_DIR"
    print_success "Go instalado: $(go version)"
else
    print_success "Go ya instalado: $(go version)"
fi

# Instalar PostgreSQL client
print_info "Instalando PostgreSQL client..."
sudo dnf install -y postgresql15
print_success "PostgreSQL client instalado"

echo ""
print_info "======================================"
print_info "Configuración de la Base de Datos"
print_info "======================================"
echo ""

read -p "Host de PostgreSQL (RDS endpoint): " DB_HOST
read -p "Puerto de PostgreSQL [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}
read -p "Usuario de PostgreSQL: " DB_USER
read -sp "Contraseña de PostgreSQL: " DB_PASSWORD
echo ""
read -p "Nombre de la base de datos: " DB_NAME

# Para RDS, preguntar si quiere SSL
print_info "Para AWS RDS se recomienda usar SSL"
read -p "SSL Mode (disable/require) [require]: " DB_SSL_MODE
DB_SSL_MODE=${DB_SSL_MODE:-require}

# Verificar conexión a PostgreSQL
print_info "Verificando conexión a PostgreSQL..."
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
    print_success "Conexión a PostgreSQL exitosa"
else
    print_warning "No se pudo verificar la conexión, continuando..."
fi

echo ""
print_info "======================================"
print_info "Configuración de Amazon SES"
print_info "======================================"
echo ""

read -p "Región de SES (ej: us-east-1): " SES_REGION
SES_HOST="email-smtp.${SES_REGION}.amazonaws.com"
print_info "Host SMTP: $SES_HOST"
read -p "SMTP Username de SES: " SES_USERNAME
read -sp "SMTP Password de SES: " SES_PASSWORD
echo ""

echo ""
print_info "======================================"
print_info "Configuración de la Aplicación"
print_info "======================================"
echo ""

# Obtener IP pública
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null)
fi
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null)
fi
print_info "IP Pública detectada: $PUBLIC_IP"

read -p "¿Tienes un dominio configurado? (s/n) [n]: " HAS_DOMAIN
HAS_DOMAIN=${HAS_DOMAIN:-n}

if [[ "$HAS_DOMAIN" =~ ^[Ss]$ ]]; then
    read -p "Dominio: " DOMAIN
    read -p "¿Ya tienes SSL configurado? (s/n) [n]: " HAS_SSL
    HAS_SSL=${HAS_SSL:-n}
    
    if [[ "$HAS_SSL" =~ ^[Ss]$ ]]; then
        APP_ROOT="https://${DOMAIN}"
    else
        APP_ROOT="http://${DOMAIN}"
    fi
else
    APP_ROOT="http://${PUBLIC_IP}:9000"
fi

echo ""
print_info "======================================"
print_info "Construyendo el Frontend"
print_info "======================================"
echo ""
print_warning "Esto tomará unos minutos..."

# Verificar que los directorios existen
if [ ! -d "frontend" ]; then
    print_error "No se encuentra el directorio frontend"
    exit 1
fi

# Construir email-builder
print_info "Construyendo email-builder..."
cd frontend/email-builder
if ! yarn install --production=false; then
    print_error "Error instalando dependencias de email-builder"
    exit 1
fi
if ! yarn build; then
    print_error "Error construyendo email-builder"
    exit 1
fi
print_success "Email-builder construido"

# Copiar email-builder a public
mkdir -p ../public/static/email-builder
cp -r dist/* ../public/static/email-builder/
print_success "Email-builder copiado"

# Construir frontend
print_info "Construyendo frontend..."
cd ../
if ! yarn install --production=false; then
    print_error "Error instalando dependencias del frontend"
    exit 1
fi
if ! yarn build; then
    print_error "Error construyendo frontend"
    exit 1
fi
print_success "Frontend construido"

cd "$SCRIPT_DIR"

echo ""
print_info "======================================"
print_info "Construyendo el Backend"
print_info "======================================"
echo ""

# Descargar dependencias de Go
print_info "Descargando dependencias de Go..."
go mod download
print_success "Dependencias descargadas"

# Compilar el backend
print_info "Compilando Listmonk..."
CGO_ENABLED=0 go build -o listmonk -ldflags="-s -w -X 'main.version=$(cat VERSION)'" cmd/*.go
sudo chmod +x listmonk
print_success "Listmonk compilado"

echo ""
print_info "======================================"
print_info "Creando archivo de configuración"
print_info "======================================"
echo ""

# Crear directorio uploads
mkdir -p uploads

# Crear config.toml
cat > config.toml << EOF
[app]
address = "0.0.0.0:9000"
root = "${APP_ROOT}"

[db]
host = "${DB_HOST}"
port = ${DB_PORT}
user = "${DB_USER}"
password = "${DB_PASSWORD}"
database = "${DB_NAME}"
ssl_mode = "${DB_SSL_MODE}"
max_open = 25
max_idle = 25
max_lifetime = "300s"

[[smtp]]
enabled = true
host = "${SES_HOST}"
port = 587
auth_protocol = "login"
username = "${SES_USERNAME}"
password = "${SES_PASSWORD}"
hello_hostname = ""
max_conns = 10
max_msg_retries = 2
idle_timeout = "15s"
wait_timeout = "5s"
tls_enabled = true
tls_skip_verify = false
email_headers = []

[privacy]
allow_blocklist = true
allow_export = true
allow_wipe = true
exportorwipe_delay = "48h"

[security]
enable_captcha = false

[upload]
path = "uploads"
extensions = ["jpg", "jpeg", "png", "gif", "svg", "pdf"]
max_file_size = 52428800

[bounce]
enabled = true
webhooks_enabled = true
EOF

chmod 600 config.toml
print_success "Archivo config.toml creado"

echo ""
print_info "======================================"
print_info "Inicializando la base de datos"
print_info "======================================"
echo ""

# Instalar e inicializar la base de datos
./listmonk --install --yes
print_success "Base de datos inicializada"

# Aplicar migraciones
./listmonk --upgrade --yes
print_success "Migraciones aplicadas"

echo ""
print_info "======================================"
print_info "Creando servicio systemd"
print_info "======================================"
echo ""

# Crear servicio systemd
sudo tee /etc/systemd/system/listmonk.service > /dev/null << EOF
[Unit]
Description=Listmonk - High performance, self-hosted newsletter and mailing list manager
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/listmonk
Restart=on-failure
RestartSec=5s

# Seguridad
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$SCRIPT_DIR/uploads

[Install]
WantedBy=multi-user.target
EOF

print_success "Servicio systemd creado"

# Habilitar e iniciar el servicio
sudo systemctl daemon-reload
sudo systemctl enable listmonk
sudo systemctl start listmonk
print_success "Servicio iniciado"

echo ""
print_success "======================================"
print_success "¡Instalación Completada!"
print_success "======================================"
echo ""
echo "Accede a Listmonk en: ${APP_ROOT}"
echo ""
echo "Credenciales por defecto:"
echo "  Usuario: admin"
echo "  Contraseña: admin"
echo ""
print_warning "¡IMPORTANTE! Cambia la contraseña después del primer inicio de sesión"
echo ""
echo "Comandos útiles:"
echo "  Ver logs:      sudo journalctl -u listmonk -f"
echo "  Estado:        sudo systemctl status listmonk"
echo "  Reiniciar:     sudo systemctl restart listmonk"
echo "  Detener:       sudo systemctl stop listmonk"
echo "  Ver procesos:  ps aux | grep listmonk"
echo ""
echo "El servicio se iniciará automáticamente al reiniciar el servidor."
echo ""

