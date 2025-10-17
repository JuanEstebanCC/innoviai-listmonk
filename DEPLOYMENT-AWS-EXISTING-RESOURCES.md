# Guía de Despliegue en EC2 con PostgreSQL y Amazon SES Existentes

Esta guía te ayudará a desplegar Listmonk en tu EC2 usando tu base de datos PostgreSQL y Amazon SES existentes.

## Requisitos Previos

- Instancia EC2 de AWS activa (Ubuntu 22.04 LTS recomendado)
- Base de datos PostgreSQL funcionando (puede estar en RDS o en otra instancia)
- Credenciales de Amazon SES configuradas
- Security Group de EC2 configurado con los siguientes puertos abiertos:
  - Puerto 22 (SSH)
  - Puerto 80 (HTTP)
  - Puerto 443 (HTTPS)
  - Puerto 9000 (Listmonk - temporal)

## PASO 1: Conectarse a la instancia EC2

```bash
ssh -i tu-key.pem ubuntu@tu-ip-ec2
```

Si usas otro usuario (como ec2-user para Amazon Linux):
```bash
ssh -i tu-key.pem ec2-user@tu-ip-ec2
```

## PASO 2: Actualizar el sistema

```bash
sudo apt update && sudo apt upgrade -y
```

Para Amazon Linux:
```bash
sudo yum update -y
```

## PASO 3: Instalar Docker y Docker Compose

```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Instalar Docker Compose plugin
sudo apt install docker-compose-plugin -y

# Para Amazon Linux use:
# sudo yum install docker -y
# sudo systemctl start docker
# sudo systemctl enable docker
```

**Importante:** Cerrar sesión y volver a conectar para que los cambios del grupo docker tomen efecto:
```bash
exit
```

Vuelve a conectarte:
```bash
ssh -i tu-key.pem ubuntu@tu-ip-ec2
```

Verifica la instalación:
```bash
docker --version
docker compose version
```

## PASO 4: Instalar Git y clonar el repositorio

```bash
# Instalar git si no está instalado
sudo apt install git -y

# Clonar el repositorio
cd ~
git clone https://github.com/TU_USUARIO/innoviai-listmonk.git
cd innoviai-listmonk
```

## PASO 5: Preparar la base de datos PostgreSQL

Necesitas crear la base de datos y el usuario si aún no existen. Conéctate a tu PostgreSQL:

```bash
# Si tu PostgreSQL está en RDS, conéctate desde tu EC2:
psql -h tu-rds-endpoint.rds.amazonaws.com -U tu_usuario_admin -d postgres

# O si está en otra instancia:
psql -h ip-del-servidor -U tu_usuario_admin -d postgres
```

Una vez conectado, ejecuta:

```sql
-- Crear base de datos
CREATE DATABASE listmonk;

-- Crear usuario (si no existe)
CREATE USER listmonk WITH PASSWORD 'tu_password_seguro';

-- Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE listmonk TO listmonk;

-- Salir
\q
```

**Nota importante sobre RDS:** Si usas RDS, asegúrate de:
1. El Security Group de RDS permita conexiones desde tu EC2
2. El usuario tenga permisos suficientes para crear tablas
3. Si usas SSL, configura `ssl_mode = "require"` en el paso siguiente

## PASO 6: Configurar las credenciales de Amazon SES

### 6.1 Obtener credenciales SMTP de SES

1. Ve a AWS Console > Amazon SES
2. En el menú lateral, haz clic en "SMTP Settings"
3. Anota el endpoint SMTP (ejemplo: `email-smtp.us-east-1.amazonaws.com`)
4. Si no tienes credenciales SMTP, haz clic en "Create SMTP Credentials"
5. Guarda el SMTP Username y SMTP Password de forma segura

### 6.2 Verificar dominios y emails

En Amazon SES:
1. Ve a "Verified identities"
2. Verifica tu dominio o email que usarás como remitente
3. Si estás en el sandbox de SES, también necesitas verificar los emails de destino

**Nota:** Para salir del sandbox de SES y enviar a cualquier dirección, debes solicitar aumento de límites en AWS Support.

## PASO 7: Crear archivo de configuración

Crea el archivo `config.toml` con tu configuración:

```bash
nano config.toml
```

Pega el siguiente contenido (reemplaza los valores con tus datos):

```toml
[app]
# Dirección donde correrá la aplicación
# 0.0.0.0 permite acceso desde cualquier interfaz
address = "0.0.0.0:9000"

# URL raíz de la aplicación
# Cambia esto por tu dominio o IP pública
root = "http://tu-ip-publica-ec2:9000"

# Base de datos PostgreSQL
[db]
host = "tu-rds-endpoint.rds.amazonaws.com"
port = 5432
user = "listmonk"
password = "tu_password_seguro"
database = "listmonk"

# Para RDS con SSL obligatorio use "require", sino "disable"
ssl_mode = "disable"

max_open = 25
max_idle = 25
max_lifetime = "300s"

# Configuración SMTP con Amazon SES
[[smtp]]
enabled = true
host = "email-smtp.us-east-1.amazonaws.com"
port = 587
auth_protocol = "login"
username = "tu_smtp_username_de_ses"
password = "tu_smtp_password_de_ses"
hello_hostname = ""
max_conns = 10
max_msg_retries = 2
idle_timeout = "15s"
wait_timeout = "5s"
tls_enabled = true
tls_skip_verify = false
email_headers = []

# Configuración adicional
[privacy]
# Permitir exportación de datos
allow_blocklist = true
allow_export = true
allow_wipe = true
exportorwipe_delay = "48h"

[security]
# Habilitar CAPTCHA en formularios públicos (recomendado)
enable_captcha = false

[upload]
# Directorio para archivos subidos
path = "uploads"
# Extensiones permitidas
extensions = ["jpg", "jpeg", "png", "gif", "svg", "pdf"]
# Tamaño máximo de archivo en bytes (50MB)
max_file_size = 52428800

[bounce]
# Configuración para manejo de rebotes
enabled = true
webhooks_enabled = true
```

Guarda el archivo: `Ctrl+O`, Enter, `Ctrl+X`

## PASO 8: Crear Dockerfile simplificado (sin PostgreSQL)

Vamos a usar el Dockerfile de producción existente. Verifica que esté presente:

```bash
ls -la Dockerfile.production
```

## PASO 9: Crear docker-compose para EC2

Crea un nuevo archivo de compose sin la base de datos:

```bash
nano docker-compose.ec2.yml
```

Pega el siguiente contenido:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.production
    container_name: listmonk_app
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - ./uploads:/listmonk/uploads:rw
      - ./config.toml:/listmonk/config.toml:ro
    command: >
      sh -c "./listmonk --install --idempotent --yes &&
             ./listmonk --upgrade --yes &&
             ./listmonk"
```

Guarda: `Ctrl+O`, Enter, `Ctrl+X`

## PASO 10: Construir y levantar la aplicación

```bash
# Construir la imagen (esto tomará varios minutos la primera vez)
docker compose -f docker-compose.ec2.yml build

# Levantar el servicio
docker compose -f docker-compose.ec2.yml up -d

# Ver los logs para verificar que todo está funcionando
docker compose -f docker-compose.ec2.yml logs -f
```

Busca en los logs mensajes como:
- "database migration completed"
- "HTTP server listening on 0.0.0.0:9000"

Presiona `Ctrl+C` para salir de los logs.

## PASO 11: Verificar que está funcionando

```bash
# Ver el estado del contenedor
docker compose -f docker-compose.ec2.yml ps

# Debe mostrar el contenedor corriendo (status "Up")
```

Abre tu navegador y visita: `http://TU_IP_PUBLICA_EC2:9000`

Deberías ver la interfaz de login de Listmonk.

**Primer inicio de sesión:**
- Usuario: `admin`
- Contraseña: `admin`
- **¡IMPORTANTE!** Cambia la contraseña inmediatamente después de entrar.

## PASO 12: Configurar Nginx como Reverse Proxy (Recomendado)

```bash
# Instalar Nginx
sudo apt install nginx -y

# Crear configuración
sudo nano /etc/nginx/sites-available/listmonk
```

Pega este contenido (reemplaza `tu-dominio.com`):

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
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Activar la configuración:

```bash
# Crear enlace simbólico
sudo ln -s /etc/nginx/sites-available/listmonk /etc/nginx/sites-enabled/

# Verificar configuración
sudo nginx -t

# Si todo está bien, reiniciar nginx
sudo systemctl restart nginx

# Habilitar nginx al inicio
sudo systemctl enable nginx
```

Ahora puedes acceder en: `http://tu-dominio.com`

**Actualiza el config.toml:**
```bash
nano config.toml
```

Cambia la línea:
```toml
root = "http://tu-dominio.com"
```

Reinicia el contenedor:
```bash
docker compose -f docker-compose.ec2.yml restart
```

## PASO 13: Configurar SSL con Let's Encrypt (Muy Recomendado)

```bash
# Instalar Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtener certificado SSL
sudo certbot --nginx -d tu-dominio.com -d www.tu-dominio.com
```

Sigue las instrucciones en pantalla. Certbot configurará automáticamente HTTPS.

**Actualiza el config.toml una vez más:**
```bash
nano config.toml
```

Cambia:
```toml
root = "https://tu-dominio.com"
```

Reinicia:
```bash
docker compose -f docker-compose.ec2.yml restart
```

## PASO 14: Configurar Listmonk

Inicia sesión en tu instalación de Listmonk y:

1. **Cambiar contraseña de admin:**
   - Ve a Settings > Users
   - Cambia la contraseña del usuario admin

2. **Verificar SMTP (Amazon SES):**
   - Ve a Settings > SMTP
   - Verifica que tu configuración de SES esté cargada
   - Haz clic en "Test" para enviar un email de prueba
   - Si falla, revisa los logs: `docker compose -f docker-compose.ec2.yml logs -f`

3. **Configurar bounce webhook (opcional pero recomendado):**
   - Ve a Settings > Bounces
   - Activa el manejo de rebotes
   - Configura SNS en AWS SES para enviar notificaciones de bounces a tu endpoint

4. **Configurar tu primer lista:**
   - Ve a Lists
   - Crea una nueva lista
   - Configura los permisos y opciones

## Comandos Útiles

### Ver logs en tiempo real
```bash
docker compose -f docker-compose.ec2.yml logs -f
```

### Reiniciar la aplicación
```bash
docker compose -f docker-compose.ec2.yml restart
```

### Detener la aplicación
```bash
docker compose -f docker-compose.ec2.yml down
```

### Actualizar la aplicación
```bash
# Detener
docker compose -f docker-compose.ec2.yml down

# Obtener cambios
git pull origin master

# Reconstruir
docker compose -f docker-compose.ec2.yml build

# Levantar
docker compose -f docker-compose.ec2.yml up -d
```

### Ver uso de recursos
```bash
docker stats
```

### Backup de archivos
```bash
# Crear backup de uploads
tar -czf backup_uploads_$(date +%Y%m%d).tar.gz uploads/

# Crear backup de configuración
cp config.toml config.toml.backup
```

### Restaurar backup
```bash
tar -xzf backup_uploads_20240101.tar.gz
```

## Solución de Problemas

### Error de conexión a PostgreSQL

**Síntoma:** Logs muestran "connection refused" o "timeout"

**Solución:**
1. Verifica que el Security Group de tu RDS permita conexiones desde tu EC2
2. Verifica que las credenciales en `config.toml` sean correctas
3. Prueba la conexión manualmente:
   ```bash
   docker run --rm postgres:17 psql -h tu-rds-endpoint.rds.amazonaws.com -U listmonk -d listmonk
   ```

### Error con Amazon SES

**Síntoma:** Emails no se envían, logs muestran errores de SMTP

**Soluciones:**
1. Verifica que tu cuenta NO esté en el sandbox de SES o que los destinatarios estén verificados
2. Verifica las credenciales SMTP en `config.toml`
3. Asegúrate de usar el endpoint correcto de tu región
4. Verifica que el puerto 587 esté permitido en el Security Group (salida)
5. Prueba el envío desde la interfaz: Settings > SMTP > Test

### El contenedor no inicia

```bash
# Ver logs detallados
docker compose -f docker-compose.ec2.yml logs

# Ver el estado
docker compose -f docker-compose.ec2.yml ps

# Entrar al contenedor para debuggear
docker exec -it listmonk_app sh
```

### Error de permisos en uploads

```bash
# Arreglar permisos
sudo chown -R 1000:1000 uploads/
```

### No puedo acceder desde el navegador

1. Verifica que el Security Group permita tráfico en puerto 9000 (o 80/443 con nginx)
2. Verifica que el contenedor esté corriendo: `docker ps`
3. Verifica que el puerto esté escuchando: `sudo netstat -tlnp | grep 9000`
4. Verifica los logs: `docker compose -f docker-compose.ec2.yml logs`

### Error "too many connections" en PostgreSQL

Si estás usando RDS con límites bajos de conexiones:

```bash
nano config.toml
```

Reduce los valores:
```toml
[db]
max_open = 10
max_idle = 5
```

Reinicia:
```bash
docker compose -f docker-compose.ec2.yml restart
```

## Configuración de Seguridad Adicional

### 1. Firewall UFW (Ubuntu)

```bash
# Habilitar UFW
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 2. Actualizaciones automáticas

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. Monitoreo de logs

```bash
# Instalar logwatch
sudo apt install logwatch -y

# Ver reporte
sudo logwatch --detail high --mailto tu@email.com --service all --range today
```

### 4. Backups automáticos

Crea un script de backup:

```bash
nano ~/backup.sh
```

Contenido:
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
cd ~/innoviai-listmonk

# Backup de uploads
tar -czf ~/backups/uploads_$DATE.tar.gz uploads/

# Backup de configuración
cp config.toml ~/backups/config_$DATE.toml

# Limpiar backups antiguos (mantener últimos 7 días)
find ~/backups -name "*.tar.gz" -mtime +7 -delete
find ~/backups -name "*.toml" -mtime +7 -delete
```

Hacer ejecutable y programar:
```bash
chmod +x ~/backup.sh
mkdir -p ~/backups

# Agregar a crontab (backup diario a las 2 AM)
crontab -e
```

Agregar esta línea:
```
0 2 * * * /home/ubuntu/backup.sh
```

## Monitoreo y Métricas

### Ver métricas del contenedor

```bash
docker stats listmonk_app
```

### Monitoreo con CloudWatch (opcional)

Si quieres enviar logs a CloudWatch:

1. Instala el agente de CloudWatch en tu EC2
2. Configura el agente para enviar logs de Docker
3. Crea alarmas para métricas importantes

## Escalamiento

Si necesitas más capacidad:

### Vertical (más recursos)

1. Para la aplicación: `docker compose -f docker-compose.ec2.yml down`
2. Cambia el tipo de instancia EC2 en AWS Console
3. Inicia la instancia nuevamente
4. Levanta la aplicación: `docker compose -f docker-compose.ec2.yml up -d`

### Horizontal (más instancias)

Considera usar:
- Application Load Balancer de AWS
- Auto Scaling Group
- RDS con réplicas de lectura
- ElastiCache para sesiones

## Recursos Adicionales

- Documentación oficial de Listmonk: https://listmonk.app/docs/
- Amazon SES Documentation: https://docs.aws.amazon.com/ses/
- Docker Documentation: https://docs.docker.com/

## Soporte

Para problemas específicos de:
- **Listmonk:** https://github.com/knadh/listmonk/issues
- **Amazon SES:** AWS Support
- **Esta instalación:** Contacta al administrador del repositorio

