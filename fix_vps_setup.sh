#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting VPS setup fix...${NC}"

# Fix Git repository permissions
echo -e "${YELLOW}Fixing Git repository permissions...${NC}"
git config --global --add safe.directory /var/www/html

# Pull latest changes
echo -e "${YELLOW}Pulling latest changes from repository...${NC}"
cd /var/www/html
git pull || {
  echo -e "${RED}Git pull failed. You may need to stash or reset local changes.${NC}"
  echo -e "Try running: git stash && git pull"
  echo -e "Or if you want to discard all local changes: git reset --hard origin/main"
}

# Create Nginx configuration
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
cat > /tmp/cloudtolocalllm.conf << 'EOF'
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
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Apply Nginx configuration
echo -e "${YELLOW}Applying Nginx configuration...${NC}"
rm -f /etc/nginx/sites-enabled/default || true
cp /tmp/cloudtolocalllm.conf /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
nginx -t && systemctl restart nginx

# Fix permissions
echo -e "${YELLOW}Fixing file permissions...${NC}"
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Stop any running Docker containers
echo -e "${YELLOW}Cleaning up Docker...${NC}"
docker stop $(docker ps -q) 2>/dev/null || true
docker system prune -af --volumes || true

# Make sure Docker is running
echo -e "${YELLOW}Ensuring Docker is running...${NC}"
systemctl restart docker

# Check what's using port 80
echo -e "${YELLOW}Checking what's using port 80...${NC}"
netstat -tulpn | grep :80

# Create cloud-only docker-compose file
echo -e "${YELLOW}Creating cloud-only Docker configuration...${NC}"
cat > /tmp/docker-compose.yml << 'EOF'
version: '3.8'

services:
  webapp:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./cloud/web:/usr/share/nginx/html
    restart: always
    container_name: cloudtolocalllm-web

networks:
  default:
    driver: bridge
EOF

# Start Docker container for the web application
echo -e "${YELLOW}Starting Docker container...${NC}"
cp /tmp/docker-compose.yml /var/www/html/
cd /var/www/html
docker-compose up -d

echo -e "${GREEN}VPS setup fixed successfully!${NC}"
echo -e "${YELLOW}Your website should now be accessible at http://cloudtolocalllm.online${NC}"
echo -e "If SSL is needed, run: certbot --nginx -d cloudtolocalllm.online -d www.cloudtolocalllm.online" 