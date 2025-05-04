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

# CloudToLocalLLM VPS Deployment Script
# Usage: ./deploy_to_vps.sh user@your-vps-ip

if [ $# -eq 0 ]; then
    echo "Usage: ./deploy_to_vps.sh user@your-vps-ip"
    exit 1
fi

SERVER=$1
echo "Deploying to $SERVER..."

# Create local docker-compose-vps.yml with CPU-only configuration
cat > docker-compose-vps.yml << 'EOF'
version: '3.8'

services:
  ollama:
    image: ollama/ollama
    networks:
      - llm-network
    volumes:
      - ./check_ollama.sh:/check_ollama.sh
    # Removed GPU requirements
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s
  tunnel:
    build:
      context: .
      dockerfile: Dockerfile
    depends_on:
      ollama:
        condition: service_healthy
    networks:
      - llm-network
    volumes:
      - ./lib:/app/lib
      - ./setup_tunnel.sh:/app/setup_tunnel.sh
    command: /bin/bash /app/setup_tunnel.sh
  cloud:
    image: node:20
    working_dir: /app
    depends_on:
      tunnel:
        condition: service_started
    networks:
      - llm-network
    volumes:
      - ./cloud:/app
      - ./setup_cloud.sh:/app/setup_cloud.sh
    command: /bin/bash /app/setup_cloud.sh
    ports:
      - "8080:3456"  # Changed from 3456:3456 to use port 8080
networks:
  llm-network:
    driver: bridge
EOF

# Copy the DNS/firewall fix script
cat > dns_firewall_fix.sh << 'EOF'
#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting connection troubleshooting...${NC}"

# Check running services
echo -e "${YELLOW}Checking running services...${NC}"
systemctl status nginx
docker ps

# Check if ports are open
echo -e "${YELLOW}Checking if ports are open...${NC}"
netstat -tulpn | grep ':80\|:8080'

# Ensure Nginx config is correct
echo -e "${YELLOW}Setting up Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/cloudtolocalllm.conf << 'EOF2'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
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
EOF2

# Apply Nginx configuration
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Check firewall status and open necessary ports
echo -e "${YELLOW}Checking firewall status...${NC}"
if command -v ufw &> /dev/null; then
    sudo ufw status
    sudo ufw allow 80/tcp
    sudo ufw allow 8080/tcp
    echo -e "${GREEN}UFW firewall ports opened${NC}"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --list-all
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo -e "${GREEN}FirewallD ports opened${NC}"
else
    echo -e "${YELLOW}No firewall detected${NC}"
fi

# Create test HTML file to confirm Nginx is serving files
echo -e "${YELLOW}Creating test HTML file...${NC}"
sudo cat > /var/www/html/index.html << 'EOF2'
<!DOCTYPE html>
<html>
<head>
    <title>CloudToLocalLLM</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1 {
            color: #0066cc;
        }
        .container {
            border: 1px solid #ddd;
            padding: 20px;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>CloudToLocalLLM</h1>
    <div class="container">
        <h2>Welcome to CloudToLocalLLM</h2>
        <p>If you can see this page, the web server is working correctly.</p>
        <p>To access the cloud application, visit: <a href="/cloud/">/cloud/</a></p>
        <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
    </div>
</body>
</html>
EOF2

# Fix permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

echo -e "${YELLOW}Restarting Docker container...${NC}"
cd /var/www/html
sudo docker-compose down || true
sudo docker-compose up -d

# Test local connection
echo -e "${YELLOW}Testing local connection...${NC}"
curl -I http://localhost
curl -I http://localhost:8080

echo -e "${GREEN}Connection troubleshooting completed!${NC}"
echo -e "${YELLOW}Try accessing the site again at http://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}You can also check http://cloudtolocalllm.online/cloud/ for the application${NC}"
echo -e "${YELLOW}If still not working, check your domain DNS settings point to this server's IP${NC}"
EOF

# Create a complete VPS setup script
cat > vps_setup.sh << 'EOF'
#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting complete VPS setup...${NC}"

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y docker.io docker-compose nginx curl git

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Clone the repository if not exists
if [ ! -d "/var/www/html/.git" ]; then
  sudo mkdir -p /var/www/html
  sudo chown -R $USER:$USER /var/www/html
  cd /var/www/html
  git clone https://github.com/yourusername/CloudToLocalLLM.git .
else
  cd /var/www/html
  git pull
fi

# Copy the CPU-only docker-compose file
cp docker-compose-vps.yml /var/www/html/docker-compose.yml

# Run the connection fix script
bash dns_firewall_fix.sh

echo -e "${GREEN}VPS setup completed!${NC}"
echo -e "${YELLOW}Your application should now be accessible at:${NC}"
echo -e "${GREEN}http://cloudtolocalllm.online${NC}"
echo -e "${GREEN}http://cloudtolocalllm.online/cloud/${NC}"
EOF

# Make scripts executable
chmod +x dns_firewall_fix.sh vps_setup.sh

# Copy files to server
echo "Copying files to server..."
scp docker-compose-vps.yml dns_firewall_fix.sh vps_setup.sh $SERVER:~/

# Execute setup on the server
echo "Executing setup on server..."
ssh $SERVER "bash vps_setup.sh"

echo "Deployment complete! Check http://cloudtolocalllm.online" 