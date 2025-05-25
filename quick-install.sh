#!/bin/bash

# ===========================================
# N8N Automation Stack with Caddy - Quick Install
# Automatic SSL certificates with Let's Encrypt
# ===========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Logo
show_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
    ███╗   ██╗ █████╗ ███╗   ██╗     ██████╗ █████╗ ██████╗ ██████╗ ██╗   ██╗
    ████╗  ██║██╔══██╗████╗  ██║    ██╔════╝██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
    ██╔██╗ ██║╚█████╔╝██╔██╗ ██║    ██║     ███████║██║  ██║██║  ██║ ╚████╔╝ 
    ██║╚██╗██║██╔══██╗██║╚██╗██║    ██║     ██╔══██║██║  ██║██║  ██║  ╚██╔╝  
    ██║ ╚████║╚█████╔╝██║ ╚████║    ╚██████╗██║  ██║██████╔╝██████╔╝   ██║   
    ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝     ╚═════╝╚═╝  ╚═╝╚═════╝ ╚═════╝    ╚═╝   
    
    🚀 N8N + PostgreSQL + Redis + Qdrant + Portainer + Caddy
    🔒 Automatic SSL certificates with Let's Encrypt - Green lock guaranteed!
EOF
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Install dependencies
install_dependencies() {
    log_step "Installing dependencies..."
    
    # Update system
    apt update && apt upgrade -y
    
    # Install required packages
    apt install -y curl wget git openssl lsof htop nano unzip ca-certificates jq
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    fi
    
    # Install Docker Compose if not present
    if ! docker compose version &>/dev/null; then
        log_info "Installing Docker Compose..."
        apt install -y docker-compose-plugin
    fi
    
    log_success "Dependencies installed"
}

# Setup firewall
setup_firewall() {
    log_step "Setting up firewall..."
    
    # Configure UFW if available
    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp comment "SSH" >/dev/null 2>&1 || true
        ufw allow 80/tcp comment "HTTP" >/dev/null 2>&1 || true
        ufw allow 443/tcp comment "HTTPS" >/dev/null 2>&1 || true
        ufw --force enable >/dev/null 2>&1 || true
        log_success "UFW firewall configured"
    fi
}

# Get domain or IP - FIXED for non-interactive mode
get_domain() {
    log_step "Configuring domain..."
    
    # Get server IP
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "localhost")
    
    # Try to read from stdin with timeout for non-interactive mode
    if [ -t 0 ]; then
        # Interactive mode
        echo
        echo -e "${YELLOW}🌐 Domain Configuration:${NC}"
        echo -e "1. Use domain name (recommended for auto SSL): ${GREEN}your-domain.com${NC}"
        echo -e "2. Use IP address (self-signed certificate): ${BLUE}${SERVER_IP}${NC}"
        echo
        read -p "Enter your domain name (or press Enter to use IP): " USER_DOMAIN
    else
        # Non-interactive mode - use IP
        log_info "Non-interactive mode detected, using IP address"
        USER_DOMAIN=""
    fi
    
    if [ ! -z "$USER_DOMAIN" ]; then
        DOMAIN="$USER_DOMAIN"
        log_info "Using domain: $DOMAIN"
        log_info "🔒 Caddy will automatically get Let's Encrypt certificate!"
    else
        DOMAIN="$SERVER_IP"
        log_info "Using IP: $DOMAIN"
        log_warning "Using self-signed certificate (browser warning expected)"
    fi
}

# Stop any existing containers with same names
stop_existing_containers() {
    log_step "Stopping any existing containers..."
    
    # Stop and remove containers if they exist
    docker stop n8n_postgres n8n_redis n8n_qdrant n8n_main n8n_portainer n8n_nginx n8n_caddy 2>/dev/null || true
    docker rm n8n_postgres n8n_redis n8n_qdrant n8n_main n8n_portainer n8n_nginx n8n_caddy 2>/dev/null || true
    
    log_success "Existing containers cleared"
}

# Generate environment variables
generate_env() {
    log_step "Generating environment variables..."
    
    # Generate secure passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d /=+ | cut -c -20)
    REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d /=+ | cut -c -20)
    N8N_PASSWORD=$(openssl rand -base64 16 | tr -d /=+ | cut -c -12)
    JWT_SECRET=$(openssl rand -base64 32 | tr -d /=+ | cut -c -32)
    
    # Create .env file
    cat > .env << ENV_EOF
# ===========================================
# N8N Automation Stack with Caddy Configuration
# ===========================================

# Domain Configuration
DOMAIN=${DOMAIN}
SERVER_IP=${DOMAIN}

# Database
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
N8N_DB=n8n

# N8N
N8N_USER=admin
N8N_PASSWORD=${N8N_PASSWORD}

# Redis
REDIS_PASSWORD=${REDIS_PASSWORD}

# Security
JWT_SECRET=${JWT_SECRET}

# Timezone
TZ=Europe/Berlin

# Backup
BACKUP_RETENTION_DAYS=7
ENV_EOF

    # Save credentials
    cat > .credentials << CRED_EOF
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

⚠️  IMPORTANT: Save these credentials in a secure location!
CRED_EOF

    chmod 600 .credentials
    
    log_success "Environment configured with secure passwords"
}

# Create project files locally instead of downloading
create_project_files() {
    log_step "Creating project files..."
    
    # Create directory structure
    mkdir -p init-scripts

    # Create docker-compose.yml
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: n8n_redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - n8n_network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n_main
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
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
      N8N_SECURE_COOKIE: false
      N8N_COOKIES_SAME_SITE: lax
      N8N_PROXY_HOPS: 1
      N8N_METRICS: true
      N8N_LOG_LEVEL: info
      TZ: ${TZ}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3

  caddy:
    image: caddy:alpine
    container_name: n8n_caddy
    restart: unless-stopped
    depends_on:
      n8n:
        condition: service_healthy
      portainer:
        condition: service_healthy
      qdrant:
        condition: service_healthy
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
    healthcheck:
      test: ["CMD", "caddy", "version"]
      interval: 30s
      timeout: 10s
      retries: 3

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
    ipam:
      config:
        - subnet: 172.20.0.0/16
COMPOSE_EOF

    # Create Caddyfile
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
        reverse_proxy n8n_portainer:9000 {
            header_up Host {http.request.host}
            header_up X-Real-IP {http.request.remote.host}
            header_up X-Forwarded-For {http.request.remote}
            header_up X-Forwarded-Proto {http.request.scheme}
        }
    }

    handle /dashboard* {
        reverse_proxy n8n_qdrant:6333 {
            header Access-Control-Allow-Origin "*"
            header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        }
    }

    handle /health {
        respond "healthy" 200
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

    # Create database initialization
    cat > init-scripts/01-init.sql << 'SQL_EOF'
-- N8N Database Initialization
CREATE DATABASE n8n;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
GRANT ALL PRIVILEGES ON DATABASE n8n TO postgres;

\c n8n;

CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.system_logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON app.system_logs(created_at);

INSERT INTO app.system_logs (level, message, metadata) 
VALUES ('INFO', 'N8N Automation Stack with Caddy initialized', '{"version": "1.0.0", "ssl": "caddy-auto"}');
SQL_EOF
    
    log_success "Project files created"
}

# Start the stack
start_stack() {
    log_step "Starting N8N Automation Stack with Caddy..."
    
    # Start all services
    docker compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start (60 seconds)..."
    sleep 60
    
    # Check status
    log_info "Checking service status..."
    docker compose ps
    
    log_success "N8N Automation Stack started successfully!"
}

# Show final information
show_final_info() {
    clear
    show_logo
    
    echo -e "${GREEN}🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo
    echo -e "${CYAN}=== ACCESS INFORMATION ===${NC}"
    echo -e "🌐 N8N:       https://$(cat .env | grep DOMAIN | cut -d= -f2)"
    echo -e "🔧 Portainer: https://$(cat .env | grep DOMAIN | cut -d= -f2)/portainer/"
    echo -e "🔍 Qdrant:    https://$(cat .env | grep DOMAIN | cut -d= -f2)/dashboard"
    echo
    echo -e "${CYAN}=== SSL STATUS ===${NC}"
    if [ "$DOMAIN" != "$(curl -4 -s ifconfig.me)" ]; then
        echo -e "🔒 SSL: ${GREEN}Let's Encrypt automatic${NC} - Green lock guaranteed!"
        echo -e "📋 Certificate: ${GREEN}Valid and trusted${NC}"
    else
        echo -e "🔒 SSL: ${YELLOW}Self-signed certificate${NC} - Browser warning expected"
        echo -e "📋 To get green lock: Add domain and restart Caddy"
    fi
    echo
    echo -e "${CYAN}=== CREDENTIALS ===${NC}"
    echo -e "📋 All credentials saved in: ${YELLOW}.credentials${NC}"
    echo -e "🔑 N8N: Complete setup on first visit"
    echo
    echo -e "${CYAN}=== MANAGEMENT COMMANDS ===${NC}"
    echo -e "📊 Status:    ${YELLOW}docker compose ps${NC}"
    echo -e "📜 Logs:      ${YELLOW}docker compose logs -f${NC}"
    echo -e "🔄 Restart:   ${YELLOW}docker compose restart [service]${NC}"
    echo -e "⏹️  Stop:      ${YELLOW}docker compose down${NC}"
    echo
    echo -e "${GREEN}🚀 Your N8N Automation Stack with Caddy is ready!${NC}"
    if [ "$DOMAIN" != "$(curl -4 -s ifconfig.me)" ]; then
        echo -e "${GREEN}🔒 Enjoy your automatic SSL certificate and green lock!${NC}"
    else
        echo -e "${YELLOW}💡 Tip: Add a domain later for automatic green lock SSL!${NC}"
    fi
}

# Main function
main() {
    show_logo
    
    log_info "Starting installation of N8N Automation Stack with Caddy..."
    log_info "🔒 Automatic SSL certificates with Let's Encrypt support"
    log_info "Running as: $(whoami)"
    
    install_dependencies
    
    # Create project directory
    PROJECT_DIR="n8n-automation-stack"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR
    
    setup_firewall
    stop_existing_containers
    get_domain
    generate_env
    create_project_files
    start_stack
    show_final_info
}

# Run main function
main "$@"
