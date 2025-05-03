#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting port conflict fix...${NC}"

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

# Check what's using port 80
echo -e "${YELLOW}Checking what's using port 80...${NC}"
netstat -tulpn | grep :80

# Stop any running Docker containers
echo -e "${YELLOW}Stopping any running Docker containers...${NC}"
docker stop $(docker ps -q) 2>/dev/null || true

# Create cloud-only docker-compose file
echo -e "${YELLOW}Creating cloud-only Docker configuration with port 8080...${NC}"
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
echo -e "${YELLOW}Starting Docker container on port 8080...${NC}"
cp /tmp/docker-compose.yml /var/www/html/
cd /var/www/html
docker-compose up -d

echo -e "${GREEN}Port conflict fix completed successfully!${NC}"
echo -e "${YELLOW}Your website should now be accessible at http://cloudtolocalllm.online${NC}"
echo -e "Nginx is serving the main site on port 80, and Docker is running on port 8080" 