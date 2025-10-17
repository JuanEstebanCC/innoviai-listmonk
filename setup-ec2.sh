#!/bin/bash

# Script de configuración automática para desplegar Listmonk en EC2
# con PostgreSQL y Amazon SES existentes

set -e

echo "======================================"
echo "Listmonk EC2 Setup Script"
echo "======================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Función para imprimir mensajes con color
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
if [ ! -f "config.ec2.toml.example" ]; then
    print_error "Error: No se encuentra config.ec2.toml.example"
    print_error "Asegúrate de estar en el directorio del proyecto"
    exit 1
fi

print_info "Verificando requisitos..."

# Verificar Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado"
    echo ""
    echo "Instala Docker con:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo "  sudo usermod -aG docker \$USER"
    exit 1
fi
print_success "Docker instalado"

# Verificar Docker Compose (soporta tanto 'docker compose' como 'docker-compose')
DOCKER_COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    print_error "Docker Compose no está instalado"
    echo ""
    echo "Instala Docker Compose con:"
    echo "  sudo apt install docker-compose-plugin -y"
    echo "O para Amazon Linux:"
    echo "  sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m) -o /usr/local/bin/docker-compose"
    echo "  sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi
print_success "Docker Compose instalado ($DOCKER_COMPOSE_CMD)"

# Verificar que el usuario tiene permisos de Docker
if ! docker ps &> /dev/null; then
    print_warning "No tienes permisos para usar Docker"
    echo "Ejecuta: sudo usermod -aG docker \$USER"
    echo "Luego cierra sesión y vuelve a conectar"
    exit 1
fi
print_success "Permisos de Docker OK"

echo ""
print_info "======================================"
print_info "Configuración de la Base de Datos"
print_info "======================================"
echo ""

# Solicitar información de PostgreSQL
read -p "Host de PostgreSQL (ej: tu-rds.rds.amazonaws.com): " DB_HOST
read -p "Puerto de PostgreSQL [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}
read -p "Usuario de PostgreSQL [listmonk]: " DB_USER
DB_USER=${DB_USER:-listmonk}
read -sp "Contraseña de PostgreSQL: " DB_PASSWORD
echo ""
read -p "Nombre de la base de datos [listmonk]: " DB_NAME
DB_NAME=${DB_NAME:-listmonk}
read -p "SSL Mode (disable/require) [disable]: " DB_SSL_MODE
DB_SSL_MODE=${DB_SSL_MODE:-disable}

echo ""
print_info "Verificando conexión a PostgreSQL..."

# Verificar conexión a PostgreSQL usando psql local si está disponible
if command -v psql &> /dev/null; then
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        print_success "Conexión a PostgreSQL exitosa"
    else
        print_warning "No se pudo verificar la conexión a PostgreSQL con psql"
        print_warning "Continuando con la instalación..."
        echo ""
        read -p "¿Deseas continuar de todas formas? (s/n) [s]: " CONTINUE
        CONTINUE=${CONTINUE:-s}
        if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
            print_error "Instalación cancelada"
            exit 1
        fi
    fi
else
    print_warning "psql no está instalado, omitiendo verificación de PostgreSQL"
    print_info "Asegúrate de que las credenciales sean correctas"
    echo ""
fi

echo ""
print_info "======================================"
print_info "Configuración de Amazon SES"
print_info "======================================"
echo ""

# Solicitar información de Amazon SES
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

# Obtener IP pública de la instancia
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "TU_IP_PUBLICA")
print_info "IP Pública detectada: $PUBLIC_IP"

read -p "¿Tienes un dominio configurado? (s/n) [n]: " HAS_DOMAIN
HAS_DOMAIN=${HAS_DOMAIN:-n}

if [[ "$HAS_DOMAIN" =~ ^[Ss]$ ]]; then
    read -p "Dominio (ej: listmonk.tudominio.com): " DOMAIN
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

print_info "URL de la aplicación: $APP_ROOT"

echo ""
print_info "======================================"
print_info "Creando archivo de configuración"
print_info "======================================"
echo ""

# Crear directorio de uploads si no existe
mkdir -p uploads
print_success "Directorio uploads creado"

# Crear config.toml desde el template
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

print_success "Archivo config.toml creado"

# Establecer permisos seguros
chmod 600 config.toml
print_success "Permisos de config.toml configurados (600)"

echo ""
print_info "======================================"
print_info "Construyendo la imagen Docker"
print_info "======================================"
echo ""
print_warning "Esto puede tomar varios minutos..."
echo ""

if $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml build; then
    print_success "Imagen construida exitosamente"
else
    print_error "Error al construir la imagen"
    exit 1
fi

echo ""
print_info "======================================"
print_info "Iniciando Listmonk"
print_info "======================================"
echo ""

if $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml up -d; then
    print_success "Listmonk iniciado exitosamente"
else
    print_error "Error al iniciar Listmonk"
    exit 1
fi

echo ""
print_info "Esperando a que Listmonk esté listo..."
sleep 10

# Verificar que el contenedor esté corriendo
if $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml ps | grep -q "Up"; then
    print_success "Contenedor corriendo"
else
    print_error "El contenedor no está corriendo"
    print_info "Ver logs con: $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml logs"
    exit 1
fi

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
echo "  Ver logs:      $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml logs -f"
echo "  Reiniciar:     $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml restart"
echo "  Detener:       $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml down"
echo "  Ver estado:    $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml ps"
echo ""

if [[ "$HAS_DOMAIN" =~ ^[Ss]$ ]] && [[ ! "$HAS_SSL" =~ ^[Ss]$ ]]; then
    echo "Próximos pasos recomendados:"
    echo "  1. Configurar Nginx como reverse proxy"
    echo "  2. Instalar certificado SSL con Let's Encrypt"
    echo ""
    echo "Ver instrucciones completas en: DEPLOYMENT-AWS-EXISTING-RESOURCES.md"
    echo ""
fi

print_info "Ver logs en tiempo real con:"
echo "  $DOCKER_COMPOSE_CMD -f docker-compose.ec2.yml logs -f"
echo ""

