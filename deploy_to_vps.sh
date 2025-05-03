#!/bin/bash

# CloudToLocalLLM VPS Deployment Script
# This script deploys the CloudToLocalLLM cloud component with a landing page to a VPS

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if required parameters were provided
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Error: Missing parameters${NC}"
    echo "Usage: $0 <VPS_IP> <VPS_USER> [SSH_PORT]"
    echo "Example: $0 192.168.1.100 root 22"
    exit 1
fi

VPS_IP=$1
VPS_USER=$2
SSH_PORT=${3:-22}

echo -e "${GREEN}Starting deployment to VPS (${VPS_IP})...${NC}"

# Build the landing page (we're using the already modified index.html)
echo -e "${YELLOW}Preparing files for deployment...${NC}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
mkdir -p $TEMP_DIR/deploy

# Copy web files
cp -r web/* $TEMP_DIR/deploy/

# Copy Dockerfile and docker-compose.yml
cp Dockerfile $TEMP_DIR/
cat > $TEMP_DIR/docker-compose.yml << EOF
version: '3'
services:
  web:
    build: .
    ports:
      - "80:80"
    restart: always
    volumes:
      - ./deploy:/usr/share/nginx/html
EOF

# Create nginx.conf file
cat > $TEMP_DIR/nginx.conf << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    # Redirect server error pages to static page
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

# SSH into the VPS and prepare the environment
echo -e "${YELLOW}Preparing VPS environment...${NC}"
ssh -p $SSH_PORT $VPS_USER@$VPS_IP "mkdir -p /var/www/cloudtolocalllm"

# Copy files to VPS
echo -e "${YELLOW}Uploading files to VPS...${NC}"
scp -P $SSH_PORT -r $TEMP_DIR/* $VPS_USER@$VPS_IP:/var/www/cloudtolocalllm/

# Deploy on VPS
echo -e "${YELLOW}Deploying application on VPS...${NC}"
ssh -p $SSH_PORT $VPS_USER@$VPS_IP "cd /var/www/cloudtolocalllm && \
    docker-compose down || true && \
    docker-compose up -d"

# Cleanup temporary files
rm -rf $TEMP_DIR

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "Your app should be available at: http://$VPS_IP/"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Configure your domain (if you have one) to point to this IP"
    echo "2. Set up SSL with: sudo certbot --nginx -d yourdomain.com"
    
    # Push to Github
    echo -e "\n${YELLOW}Pushing changes to Github...${NC}"
    echo "Remember to commit and push these changes to your Github repository."
    echo "git add cloud/web/index.html cloud/web/manifest.json cloud/deploy_to_vps.sh"
    echo "git commit -m \"Add cloud landing page and deployment script\""
    echo "git push origin main"
else
    echo -e "${RED}Error during deployment!${NC}"
    exit 1
fi 