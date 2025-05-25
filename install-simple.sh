#!/bin/bash
echo "🚀 Installing N8N Automation Stack with Caddy..."
echo "🔒 Automatic SSL certificates with Let's Encrypt support"

# Обновление системы
apt update && apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com | sh
systemctl start docker
systemctl enable docker

# Остановка существующих контейнеров
echo "🧹 Cleaning up existing containers..."
docker stop n8n_postgres n8n_redis n8n_qdrant n8n_main n8n_portainer n8n_nginx n8n_caddy 2>/dev/null || true
docker rm n8n_postgres n8n_redis n8n_qdrant n8n_main n8n_portainer n8n_nginx n8n_caddy 2>/dev/null || true

# Создание папки проекта
mkdir -p /root/n8n-automation-stack
cd /root/n8n-automation-stack
mkdir -p init-scripts

# Получение IP и генерация паролей
SERVER_IP=$(curl -4 -s ifconfig.me)
POSTGRES_PASSWORD=$(openssl rand -base64 16 | tr -d /=+)
N8N_PASSWORD=$(openssl rand -base64 12 | tr -d /=+)
REDIS_PASSWORD=$(openssl rand -base64 16 | tr -d /=+)

# Проверка интерактивного режима
if [ -t 0 ]; then
    # Интерактивный режим
    echo
    echo "🌐 Domain Configuration:"
    echo "1. Use domain name (recommended for auto SSL): your-domain.com"
    echo "2. Use IP address (self-signed certificate): ${SERVER_IP}"
    echo
    read -p "Enter your domain name (or press Enter to use IP): " USER_DOMAIN
else
    # Неинтерактивный режим
    echo "⚡ Non-interactive mode: using IP address"
    USER_DOMAIN=""
fi

if [ ! -z "$USER_DOMAIN" ]; then
    DOMAIN="$USER_DOMAIN"
    echo "✅ Using domain: $DOMAIN (automatic Let's Encrypt SSL)"
else
    DOMAIN="$SERVER_IP"
    echo "✅ Using IP: $DOMAIN (self-signed SSL)"
fi

# Создание .env
cat > .env << EOF
DOMAIN=${DOMAIN}
SERVER_IP=${DOMAIN}
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
N8N_DB=n8n
N8N_USER=admin
N8N_PASSWORD=${N8N_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
JWT_SECRET=$(openssl rand -base64 32 | tr -d /=+)
TZ=Europe/Berlin
BACKUP_RETENTION_DAYS=7
EOF

# Docker Compose файл с Caddy
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - n8n_network

  redis:
    image: redis:7-alpine
    container_name: n8n_redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - n8n_network

  qdrant:
    image: qdrant/qdrant:latest
    container_name: n8n_qdrant
    restart: unless-stopped
    volumes:
      - qdrant_data:/qdrant/storage
    networks:
      - n8n_network
    environment:
      QDRANT__SERVICE__HTTP_PORT: 6333
      QDRANT__WEB_UI__ENABLED: true

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n_main
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${N8N_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      QUEUE_BULL_REDIS_HOST: redis
      QUEUE_BULL_REDIS_PORT: 6379
      QUEUE_BULL_REDIS_PASSWORD: ${REDIS_PASSWORD}
      N8N_HOST: 0.0.0.0
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://${DOMAIN}
      TZ: ${TZ}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n_network

  portainer:
    image: portainer/portainer-ce:latest
    container_name: n8n_portainer
    restart: unless-stopped
    command: --base-url /portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - n8n_network

  caddy:
    image: caddy:alpine
    container_name: n8n_caddy
    restart: unless-stopped
    depends_on:
      - n8n
      - portainer
      - qdrant
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - n8n_network
    environment:
      - DOMAIN=${DOMAIN}

volumes:
  postgres_data:
  redis_data:
  qdrant_data:
  n8n_data:
  portainer_data:
  caddy_data:
  caddy_config:

networks:
  n8n_network:
    driver: bridge
COMPOSE_EOF

# Caddyfile конфигурация
cat > Caddyfile << 'CADDY_EOF'
{$DOMAIN:localhost} {
    reverse_proxy n8n_main:5678 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
        header_up X-Forwarded-For {http.request.remote}
        header_up X-Forwarded-Proto {http.request.scheme}
    }

    handle /portainer/* {
        uri strip_prefix /portainer
        reverse_proxy n8n_portainer:9000
    }

    handle /dashboard* {
        reverse_proxy n8n_qdrant:6333
    }

    handle /health {
        respond "healthy"
    }

    header {
        Strict-Transport-Security "max-age=31536000"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        -Server
    }

    log {
        output stdout
        format console
    }
}
CADDY_EOF

# Инициализация БД
cat > init-scripts/01-init.sql << 'SQL_EOF'
-- N8N Database Initialization
CREATE DATABASE n8n;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
GRANT ALL PRIVILEGES ON DATABASE n8n TO postgres;

-- Connect to n8n database
\c n8n;

-- Create schema for application data
CREATE SCHEMA IF NOT EXISTS app;

-- Create logging table
CREATE TABLE IF NOT EXISTS app.system_logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON app.system_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON app.system_logs(level);

-- Insert initial log
INSERT INTO app.system_logs (level, message, metadata) 
VALUES ('INFO', 'N8N Automation Stack with Caddy initialized', '{"version": "1.0.0", "ssl": "caddy-auto"}');
SQL_EOF

# Файрвол
ufw allow 22,80,443/tcp -y 2>/dev/null || true
ufw --force enable 2>/dev/null || true

# Запуск
echo "🚀 Starting N8N Automation Stack with Caddy..."
docker compose up -d

echo "⏳ Waiting for startup (60 seconds)..."
sleep 60

# Сохранение паролей
cat > .credentials << EOF
=== N8N AUTOMATION STACK WITH CADDY CREDENTIALS ===

🌐 Access URLs:
   N8N:       https://${DOMAIN}
   Portainer: https://${DOMAIN}/portainer/
   Qdrant:    https://${DOMAIN}/dashboard

🔐 Login Credentials:
   N8N:        Setup required on first visit
   PostgreSQL: postgres / ${POSTGRES_PASSWORD}
   Redis:      ${REDIS_PASSWORD}

🔒 SSL Certificate:
   Type:       $([ "$DOMAIN" != "$SERVER_IP" ] && echo "Let's Encrypt (automatic)" || echo "Self-signed")
   Status:     $([ "$DOMAIN" != "$SERVER_IP" ] && echo "Green lock 🔒" || echo "Browser warning ⚠️")

⚠️  IMPORTANT: Save these credentials securely!
EOF

chmod 600 .credentials

echo
echo "🎉 Installation Complete!"
echo "🌐 N8N: https://${DOMAIN}"
if [ "$DOMAIN" != "$SERVER_IP" ]; then
    echo "🔒 SSL: Automatic Let's Encrypt - Green lock guaranteed!"
else
    echo "🔒 SSL: Self-signed certificate - Accept browser warning"
    echo "💡 Tip: Add domain later for automatic green lock!"
fi
echo "📋 All credentials saved in .credentials file"
echo
echo "🚀 Your N8N Automation Stack with Caddy is ready!"
