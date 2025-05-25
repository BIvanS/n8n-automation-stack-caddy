# 🚀 N8N Automation Stack with Caddy

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![SSL](https://img.shields.io/badge/SSL-Auto-green.svg)](https://letsencrypt.org/)
[![N8N](https://img.shields.io/badge/N8N-Latest-orange.svg)](https://n8n.io/)

**Production-ready N8N automation platform with automatic SSL certificates**

Complete automation solution with N8N, PostgreSQL, Redis, Qdrant vector database, Portainer, and Caddy reverse proxy with automatic Let's Encrypt SSL. Get green lock instantly - no SSL configuration required!

## ✨ Key Features

- 🔒 **Automatic SSL certificates** - Green lock guaranteed with Let's Encrypt
- 🔄 **Zero SSL configuration** - Caddy handles everything automatically
- ⚡ **One-command installation** - Deploy in 5 minutes
- 🔄 **N8N** - Visual workflow automation platform
- 🗄️ **PostgreSQL** - Reliable database with extensions
- ⚡ **Redis** - High-performance caching and queuing
- 🔍 **Qdrant** - Vector database for AI/ML applications
- 🐳 **Portainer** - Docker container management UI
- 🌐 **Caddy** - Modern reverse proxy with automatic HTTPS
- 💾 **Automated Backups** - Built-in backup and monitoring scripts
- 📊 **Health Monitoring** - Comprehensive system monitoring

## 🚀 Quick Start

### One-Command Installation

```bash
curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/quick-install.sh | bash
```

### Alternative Installation

```bash
# Download and run separately
wget https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/quick-install.sh
chmod +x quick-install.sh
./quick-install.sh
```

### Simple Installation (Fallback)

```bash
curl -fsSL https://raw.githubusercontent.com/BIvanS/n8n-automation-stack-caddy/main/install-simple.sh | bash
```

### Requirements

- **OS**: Ubuntu 18.04+, Debian 9+, CentOS 7+
- **RAM**: 2GB minimum (4GB+ recommended)
- **Disk**: 20GB free space
- **Network**: Internet access for container downloads
- **Domain**: Optional (works with IP, but domain recommended for auto-SSL)

## 🔒 SSL Certificate Magic

### With Domain (Recommended)
```bash
# Your domain will get automatic Let's Encrypt certificate
# Green lock instantly - no configuration needed!
https://your-domain.com  ✅ 🔒
```

### With IP Address
```bash
# Works immediately with self-signed certificate
# Can upgrade to real domain later
https://your-server-ip  ✅ ⚠️
```

## 📋 Default Access

After installation, services are available at:

| Service | URL | Features |
|---------|-----|----------|
| **N8N** | `https://your-domain/` | 🔒 Auto SSL + Workflow automation |
| **Portainer** | `https://your-domain/portainer/` | 🔒 Auto SSL + Docker management |
| **Qdrant** | `https://your-domain/dashboard` | 🔒 Auto SSL + Vector database UI |

> 🔐 **Credentials are automatically generated and saved to `.credentials` file**

## 🛠️ Management Commands

```bash
# Navigate to project directory
cd n8n-automation-stack  # (created by installation script)

# System Status
docker compose ps                 # List containers
docker compose logs -f [service]  # View logs
docker compose restart [service]  # Restart service
docker compose down               # Stop all services
docker compose up -d             # Start all services

# View credentials
cat .credentials

# Backup (if backup script available)
./scripts/backup.sh

# Update (if update script available)
./scripts/update.sh
```

## 📁 Project Structure

```
n8n-automation-stack/          # Created by installation
├── docker-compose.yml         # Service definitions with Caddy
├── Caddyfile                  # Caddy configuration
├── .env                       # Environment variables
├── .credentials              # Generated credentials
├── init-scripts/
│   └── 01-init.sql          # Database initialization
└── scripts/                 # Management scripts
    ├── backup.sh
    ├── update.sh
    └── monitor.sh
```

## 🔧 Configuration

### Environment Variables

The installation script automatically generates secure passwords and configuration. You can modify `.env` file after installation:

```bash
# Edit configuration
nano .env

# Key variables:
DOMAIN=your-domain.com        # Your domain (for auto SSL)
SERVER_IP=your-domain.com     # Same as domain
N8N_PASSWORD=generated        # Admin password for N8N
POSTGRES_PASSWORD=generated   # Database password
REDIS_PASSWORD=generated      # Redis password
```

### Caddy Auto-SSL

**The Magic of Caddy:**
- ✅ **Automatic certificate** provisioning from Let's Encrypt
- ✅ **Automatic renewal** - never expires
- ✅ **HTTP to HTTPS** redirect automatically
- ✅ **Modern TLS** configuration out of the box
- ✅ **Green lock** in browser instantly

**For Domain Setup:**
```bash
# 1. Point your domain to server IP (A record)
# 2. Update .env file with your domain
# 3. Restart: docker compose restart caddy
# 4. Automatic green lock in 30 seconds!
```

## 🌐 Domain Setup

### Quick Domain Setup

1. **Create A record** pointing to your server IP:
   ```
   Type: A
   Name: @ (or subdomain)
   Value: YOUR-SERVER-IP
   TTL: 300
   ```

2. **Update configuration:**
   ```bash
   nano .env
   # Change:
   DOMAIN=your-domain.com
   SERVER_IP=your-domain.com
   ```

3. **Restart Caddy:**
   ```bash
   docker compose restart caddy
   ```

4. **Enjoy green lock!** 🔒✨

### Popular DNS Providers

- **Cloudflare**: DNS → Records → Add record
- **Namecheap**: Domain List → Manage → Advanced DNS
- **GoDaddy**: DNS Management → Add Record
- **Google Domains**: DNS → Custom records

## 📊 Monitoring

### Health Checks

```bash
# Quick status
docker compose ps

# Detailed container stats
docker stats

# Service logs
docker compose logs -f [service-name]

# Caddy specific logs
docker compose logs -f caddy
```

### SSL Certificate Status

```bash
# Check certificate info
curl -vI https://your-domain.com 2>&1 | grep -i "certificate\|ssl\|tls"

# Check certificate expiry
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

## 💾 Backup & Recovery

### Automated Backups

```bash
# Create backup
./scripts/backup.sh

# Backup includes:
# - PostgreSQL databases
# - N8N workflows and data
# - Redis data
# - Configuration files
# - Caddy data (certificates, configs)
```

### Backup Schedule

Set up automated daily backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/n8n-automation-stack/scripts/backup.sh
```

## 🐛 Troubleshooting

### Common Issues

**SSL certificate not working:**
```bash
# Check Caddy logs
docker compose logs caddy

# Verify domain points to server
nslookup your-domain.com

# Restart Caddy
docker compose restart caddy
```

**Services not accessible:**
```bash
# Check container status
docker compose ps

# Check firewall
ufw status

# Check Caddy configuration
docker compose exec caddy caddy fmt --config /etc/caddy/Caddyfile
```

### Recovery Commands

```bash
# Emergency restart
docker compose down && docker compose up -d

# Remove and recreate containers
docker compose down
docker compose up -d --force-recreate

# Reset Caddy certificates (if needed)
docker compose down
docker volume rm n8n-automation-stack_caddy_data
docker compose up -d
```

## 🔄 Updates

### Container Updates

```bash
# Update all containers
./scripts/update.sh

# Manual update
docker compose pull
docker compose up -d
```

## 🆚 Why Caddy over NGINX?

| Feature | Caddy | NGINX |
|---------|-------|-------|
| **Auto SSL** | ✅ Built-in | ❌ Manual setup |
| **Configuration** | 📝 Simple | 🔧 Complex |
| **Let's Encrypt** | ✅ Automatic | ❌ External tools |
| **Maintenance** | 🔄 Zero | ⚙️ Regular |
| **Green Lock** | ✅ Instant | ❌ After setup |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📖 [Documentation](./docs/)
- 🐛 [Issue Tracker](https://github.com/BIvanS/n8n-automation-stack-caddy/issues)
- 💬 [Discussions](https://github.com/BIvanS/n8n-automation-stack-caddy/discussions)

## 🙏 Acknowledgments

- [N8N](https://n8n.io/) - Workflow automation platform
- [Caddy](https://caddyserver.com/) - Modern web server with automatic HTTPS
- [PostgreSQL](https://www.postgresql.org/) - Advanced open source database
- [Redis](https://redis.io/) - In-memory data structure store
- [Qdrant](https://qdrant.tech/) - Vector database for AI applications
- [Portainer](https://www.portainer.io/) - Container management platform

---

**⭐ If this project helped you get green lock instantly, please give it a star!**

**🔒 Finally, SSL that just works!** 🎉