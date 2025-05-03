#!/bin/bash

# Exit on error
set -e

# VPS details
VPS_IP="$1"
VPS_USER="$2"
SSH_KEY="$3"
SSH_PORT="${4:-22}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if required parameters are provided
if [ -z "$VPS_IP" ] || [ -z "$VPS_USER" ] || [ -z "$SSH_KEY" ]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    echo "Usage: $0 VPS_IP VPS_USER SSH_KEY [SSH_PORT]"
    echo "Example: $0 123.456.789.012 root ~/.ssh/id_rsa 22"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

echo -e "${GREEN}Starting deployment to VPS (${VPS_IP})...${NC}"

# SSH command helper
function ssh_cmd() {
    ssh -p "$SSH_PORT" -i "$SSH_KEY" "${VPS_USER}@${VPS_IP}" "$1"
}

# SCP command helper
function scp_cmd() {
    scp -P "$SSH_PORT" -i "$SSH_KEY" "$1" "${VPS_USER}@${VPS_IP}:$2"
}

# Create temporary directory
TEMP_DIR=$(mktemp -d)
DEPLOY_DIR="$TEMP_DIR/deploy"
mkdir -p "$DEPLOY_DIR"

# Copy web files and configurations
cp -r web/* "$DEPLOY_DIR/"
cp Dockerfile "$TEMP_DIR/"
cp docker-compose.yml "$TEMP_DIR/"

# Create nginx site configuration
cat << 'EOF' > "$TEMP_DIR/cloudtolocalllm.conf"
server {
    listen 80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        autoindex off;
    }

    location /cloud/ {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Create cleanup script for VPS
cat << 'EOF' > "$TEMP_DIR/cleanup_vps.sh"
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting VPS cleanup...${NC}"

# Stop all running containers
echo -e "${YELLOW}Stopping all running containers...${NC}"
docker stop $(docker ps -q) 2>/dev/null || true

# Remove unused containers, networks, images, and volumes
echo -e "${YELLOW}Removing unused Docker resources...${NC}"
docker system prune -af --volumes

# Clean apt cache
echo -e "${YELLOW}Cleaning apt cache...${NC}"
apt-get clean
apt-get autoremove -y

# Remove temporary files
echo -e "${YELLOW}Removing temporary files...${NC}"
rm -rf /tmp/*

# Fix permissions for web folder
echo -e "${YELLOW}Setting correct permissions for web folder...${NC}"
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Configure Git to allow operations in the web directory
git config --global --add safe.directory /var/www/html

# Ensure Docker service is properly configured
echo -e "${YELLOW}Ensuring Docker is configured correctly...${NC}"
systemctl restart docker

# Update Nginx configuration
echo -e "${YELLOW}Updating Nginx configuration...${NC}"
if [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default
fi
cp /var/www/cloudtolocalllm/cloudtolocalllm.conf /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

echo -e "${GREEN}VPS cleanup complete!${NC}"
EOF

# Upload files to VPS
echo -e "${YELLOW}Uploading files to VPS...${NC}"
ssh_cmd "mkdir -p /var/www/cloudtolocalllm"
scp_cmd -r "$TEMP_DIR/*" "/var/www/cloudtolocalllm"

# Setup and deploy on VPS
echo -e "${YELLOW}Setting up and deploying on VPS...${NC}"
ssh_cmd "cd /var/www/cloudtolocalllm && bash cleanup_vps.sh && docker-compose up -d"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Your application is now available at http://${VPS_IP}${NC}"
echo "To set up a domain and SSL, follow the instructions in VPS_DEPLOYMENT.md" 