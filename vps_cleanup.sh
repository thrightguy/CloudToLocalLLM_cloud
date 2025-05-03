#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting comprehensive VPS cleanup...${NC}"

# Stop all running containers
echo -e "${YELLOW}Stopping all running Docker containers...${NC}"
docker stop $(docker ps -q) 2>/dev/null || true

# Remove all Docker containers, images, volumes, and networks
echo -e "${YELLOW}Removing all Docker resources...${NC}"
docker system prune -af --volumes

# Stop Nginx and other services that might be using port 80
echo -e "${YELLOW}Stopping Nginx and other services...${NC}"
systemctl stop nginx
systemctl stop apache2 2>/dev/null || true

# Find and kill any process that might be using port 80
echo -e "${YELLOW}Killing any process using port 80...${NC}"
kill $(lsof -t -i:80) 2>/dev/null || true

# Clean package cache and remove unused packages
echo -e "${YELLOW}Cleaning package cache and removing unused packages...${NC}"
apt-get clean
apt-get autoremove -y
apt-get update

# Remove Docker Compose old files
echo -e "${YELLOW}Removing Docker Compose files...${NC}"
rm -f /var/www/html/docker-compose.yml

# Remove old Docker Compose and install newer version
echo -e "${YELLOW}Installing latest Docker Compose...${NC}"
rm -f /usr/local/bin/docker-compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create a simplified Docker Compose file
echo -e "${YELLOW}Creating simplified Docker configuration...${NC}"
cat > /var/www/html/docker-compose.yml << 'EOF'
version: '3'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./cloud/web:/usr/share/nginx/html
    restart: always
EOF

# Setup simple nginx config
echo -e "${YELLOW}Setting up simplified Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/cloudtolocalllm.conf << 'EOF'
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
    }
}
EOF

# Start services in the right order
echo -e "${YELLOW}Starting services in the right order...${NC}"
systemctl start nginx

# Start Docker container with the simplified config
echo -e "${YELLOW}Starting Docker container with simplified config...${NC}"
cd /var/www/html
docker-compose up -d

echo -e "${GREEN}VPS cleanup and setup completed!${NC}"
echo -e "${YELLOW}Your website should now be accessible at http://cloudtolocalllm.online${NC}" 