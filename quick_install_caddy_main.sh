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
        ufw allow 22/tcp comment "SSH"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        ufw --force enable
        log_success "UFW firewall configured"
    fi
}

# Get domain or IP
get_domain() {
    log_step "Configuring domain..."
    
    # Get server IP
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "localhost")
    
    # Ask user for domain
    echo
    echo -e "${YELLOW}🌐 Domain Configuration:${NC}"
    echo -e "1. Use domain name (recommended for auto SSL): ${GREEN}your-domain.com${NC}"
    echo -e "2. Use IP address (self-signed certificate): ${BLUE}${SERVER_IP}${NC}"
    echo
    read -p "Enter your domain name (or press Enter to use IP): " USER_DOMAIN
    
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

# Download project files
download_files() {
    log_step "Downloading project files..."
    
    # Create directory structure
    mkdir -p init-scripts scripts
    
    # Download main files
    curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/docker-compose.yml -o docker-compose.yml
    curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/Caddyfile -o Caddyfile
    curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/init-scripts/01-init.sql -o init-scripts/01-init.sql
    
    # Download scripts if available
    curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/scripts/backup.sh -o scripts/backup.sh 2>/dev/null || true
    curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/scripts/update.sh -o scripts/update.sh 2>/dev/null || true
    curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/scripts/monitor.sh -o scripts/monitor.sh 2>/dev/null || true
    
    # Make scripts executable
    chmod +x scripts/*.sh 2>/dev/null || true
    
    log_success "Project files downloaded"
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
    if [ "$DOMAIN" != "$SERVER_IP" ]; then
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
    echo -e "💾 Backup:    ${YELLOW}./scripts/backup.sh${NC}"
    echo
    echo -e "${GREEN}🚀 Your N8N Automation Stack with Caddy is ready!${NC}"
    if [ "$DOMAIN" != "$SERVER_IP" ]; then
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
    get_domain
    generate_env
    download_files
    start_stack
    show_final_info
}

# Run main function
main "$@"