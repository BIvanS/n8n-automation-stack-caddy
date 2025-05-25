# ===========================================
# N8N Automation Stack with Caddy Configuration
# Copy this file to .env and update values
# ===========================================

# Domain Configuration (IMPORTANT for SSL)
# Use your domain for automatic Let's Encrypt SSL
DOMAIN=your-domain.com
SERVER_IP=your-domain.com

# Alternative: Use IP address (self-signed SSL)
# DOMAIN=your-server-ip
# SERVER_IP=your-server-ip

# Database Configuration
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=change-this-secure-password
N8N_DB=n8n

# N8N Configuration
N8N_USER=admin
N8N_PASSWORD=change-this-secure-password

# Redis Configuration  
REDIS_PASSWORD=change-this-secure-password

# Security
JWT_SECRET=change-this-super-long-jwt-secret-key

# Timezone (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
TZ=UTC

# Backup Configuration
BACKUP_RETENTION_DAYS=7

# ===========================================
# Caddy SSL Configuration
# ===========================================

# Caddy will automatically:
# - Get Let's Encrypt certificates for domains
# - Use self-signed certificates for IP addresses
# - Renew certificates automatically
# - Redirect HTTP to HTTPS

# For production with domain:
# 1. Set DOMAIN to your real domain
# 2. Point DNS A record to your server IP
# 3. Caddy will get SSL certificate automatically

# ===========================================
# Optional: External Services Configuration
# ===========================================

# Email/SMTP (for N8N notifications)
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_USER=your-email@gmail.com
# SMTP_PASS=your-app-password

# Monitoring (if using external monitoring)
# MONITORING_ENABLED=false
# GRAFANA_PASSWORD=change-this-password

# ===========================================
# Advanced Caddy Configuration
# ===========================================

# Custom Caddy settings (usually not needed)
# CADDY_ADMIN_LISTEN=localhost:2019
# CADDY_LOG_LEVEL=INFO
# CADDY_ACME_EMAIL=your-email@domain.com

# Rate limiting (included in Caddyfile)
# CADDY_RATE_LIMIT=100req/min