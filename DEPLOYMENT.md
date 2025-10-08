# Guía de Despliegue en AWS EC2

Esta guía te ayudará a desplegar listmonk con tu logo personalizado en una instancia EC2 de AWS.

## Requisitos Previos

- Una instancia EC2 de AWS (Ubuntu 22.04 LTS recomendado)
- Mínimo: 2 GB RAM, 1 vCPU, 20 GB de almacenamiento
- Security Group configurado con los siguientes puertos abiertos:
  - Puerto 22 (SSH)
  - Puerto 80 (HTTP)
  - Puerto 443 (HTTPS)
  - Puerto 9000 (Listmonk - temporal, cerrar después de configurar nginx)

## Paso 1: Conectarse a la instancia EC2

```bash
ssh -i tu-key.pem ubuntu@tu-ip-ec2
```

## Paso 2: Actualizar el sistema

```bash
sudo apt update
sudo apt upgrade -y
```

## Paso 3: Instalar Docker y Docker Compose

```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo apt install docker-compose-plugin -y

# Cerrar sesión y volver a conectar para que los cambios tomen efecto
exit
```

Vuelve a conectarte:
```bash
ssh -i tu-key.pem ubuntu@tu-ip-ec2
```

## Paso 4: Clonar el repositorio

```bash
cd ~
git clone https://github.com/JuanEstebanCC/innoviai-listmonk.git
cd innoviai-listmonk
```

## Paso 5: Configurar variables de entorno

```bash
# Copiar el archivo de ejemplo
cp env.example .env

# Editar el archivo .env con tus credenciales
nano .env
```

Modifica los valores:
```env
DB_USER=listmonk
DB_PASSWORD=TU_CONTRASEÑA_SEGURA_AQUI
DB_NAME=listmonk
TZ=America/Bogota
LISTMONK_ADMIN_USER=admin
LISTMONK_ADMIN_PASSWORD=TU_CONTRASEÑA_ADMIN_AQUI
```

Guarda con `Ctrl+O`, Enter, y sal con `Ctrl+X`.

## Paso 6: Construir y levantar los contenedores

```bash
# Construir la imagen (esto tomará varios minutos la primera vez)
docker compose -f docker-compose.production.yml build

# Levantar los servicios
docker compose -f docker-compose.production.yml up -d

# Ver los logs para verificar que todo está funcionando
docker compose -f docker-compose.production.yml logs -f
```

Presiona `Ctrl+C` para salir de los logs.

## Paso 7: Verificar que está funcionando

```bash
# Ver el estado de los contenedores
docker compose -f docker-compose.production.yml ps
```

Abre tu navegador y visita: `http://TU_IP_EC2:9000`

Deberías ver la interfaz de listmonk con tu logo personalizado.

## Paso 8: Configurar Nginx como Reverse Proxy (Recomendado)

```bash
# Instalar Nginx
sudo apt install nginx -y

# Crear configuración de nginx
sudo nano /etc/nginx/sites-available/listmonk
```

Agrega el siguiente contenido (reemplaza `tu-dominio.com` con tu dominio):

```nginx
server {
    listen 80;
    server_name tu-dominio.com www.tu-dominio.com;

    client_max_body_size 50M;

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Guarda y activa la configuración:

```bash
# Activar el sitio
sudo ln -s /etc/nginx/sites-available/listmonk /etc/nginx/sites-enabled/

# Verificar la configuración
sudo nginx -t

# Reiniciar nginx
sudo systemctl restart nginx
```

Ahora puedes acceder a listmonk en: `http://tu-dominio.com`

## Paso 9: Configurar SSL con Let's Encrypt (Opcional pero Recomendado)

```bash
# Instalar Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtener certificado SSL
sudo certbot --nginx -d tu-dominio.com -d www.tu-dominio.com

# Seguir las instrucciones en pantalla
```

Certbot configurará automáticamente HTTPS y renovará el certificado automáticamente.

## Comandos Útiles

### Ver logs
```bash
docker compose -f docker-compose.production.yml logs -f
docker compose -f docker-compose.production.yml logs -f app
docker compose -f docker-compose.production.yml logs -f db
```

### Reiniciar servicios
```bash
docker compose -f docker-compose.production.yml restart
```

### Detener servicios
```bash
docker compose -f docker-compose.production.yml down
```

### Actualizar la aplicación
```bash
# Detener los servicios
docker compose -f docker-compose.production.yml down

# Obtener últimos cambios
git pull origin master

# Reconstruir y levantar
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d
```

### Hacer backup de la base de datos
```bash
docker exec listmonk_db pg_dump -U listmonk listmonk > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restaurar backup
```bash
docker exec -i listmonk_db psql -U listmonk listmonk < backup_20240101_120000.sql
```

## Configuración de Email (SMTP)

Después de iniciar sesión en listmonk:

1. Ve a **Settings > SMTP**
2. Configura tu servidor SMTP (por ejemplo: Gmail, SendGrid, AWS SES, etc.)
3. Guarda y prueba la configuración

## Solución de Problemas

### Los contenedores no inician
```bash
# Ver logs detallados
docker compose -f docker-compose.production.yml logs

# Verificar el estado
docker compose -f docker-compose.production.yml ps
```

### Error de permisos
```bash
# Arreglar permisos de uploads
sudo chown -R 1000:1000 uploads/
```

### No puedo acceder desde el navegador
- Verifica que el Security Group de AWS permita el tráfico en el puerto 9000 (o 80/443 si usas nginx)
- Verifica que los contenedores estén corriendo: `docker ps`
- Verifica los logs: `docker compose -f docker-compose.production.yml logs`

### Actualizar solo el logo
Si solo necesitas actualizar el logo sin reconstruir todo:

1. Reemplaza los archivos en `frontend/src/assets/`
2. Reconstruye: `docker compose -f docker-compose.production.yml build app`
3. Reinicia: `docker compose -f docker-compose.production.yml up -d`

## Seguridad Adicional

1. **Cambiar puerto SSH por defecto**
2. **Configurar firewall (UFW)**
3. **Habilitar actualizaciones automáticas de seguridad**
4. **Usar contraseñas fuertes en la base de datos**
5. **Configurar backups automáticos**
6. **Monitorear logs regularmente**

## Soporte

Para más información sobre listmonk, visita: https://listmonk.app/docs/

