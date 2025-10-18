#!/bin/bash

# Script de rebuild rápido para Listmonk
# Uso: ./rebuild.sh

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Listmonk Quick Rebuild Script${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar que Go esté en el PATH
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}Agregando Go al PATH...${NC}"
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
fi

# Obtener últimos cambios
echo -e "${YELLOW}→ Obteniendo últimos cambios del repositorio...${NC}"
git pull origin master

# Reconstruir email-builder
echo ""
echo -e "${YELLOW}→ Reconstruyendo email-builder...${NC}"
cd frontend/email-builder
yarn build

# Copiar email-builder a public
echo -e "${YELLOW}→ Copiando email-builder...${NC}"
cd ..
mkdir -p public/static/email-builder
cp -r email-builder/dist/* public/static/email-builder/

# Reconstruir frontend
echo ""
echo -e "${YELLOW}→ Reconstruyendo frontend...${NC}"
yarn build

# Volver al directorio principal
cd ..

# Recompilar backend
echo ""
echo -e "${YELLOW}→ Recompilando backend...${NC}"
CGO_ENABLED=0 go build -o listmonk -ldflags="-s -w" cmd/*.go
chmod +x listmonk

# Aplicar migraciones
echo ""
echo -e "${YELLOW}→ Aplicando migraciones...${NC}"
./listmonk --upgrade --yes

# Reiniciar servicio
echo ""
echo -e "${YELLOW}→ Reiniciando Listmonk...${NC}"
sudo systemctl restart listmonk

# Verificar estado
echo ""
echo -e "${GREEN}✓ Rebuild completado!${NC}"
echo ""
echo "Estado del servicio:"
sudo systemctl status listmonk --no-pager

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Para ver logs en tiempo real:${NC}"
echo "  sudo journalctl -u listmonk -f"
echo -e "${GREEN}======================================${NC}"

