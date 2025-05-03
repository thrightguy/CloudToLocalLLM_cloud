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
cat > /etc/nginx/sites-available/cloudtolocalllm.conf << 'EOF'
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
EOF

# Apply Nginx configuration
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

# Check firewall status and open necessary ports
echo -e "${YELLOW}Checking firewall status...${NC}"
if command -v ufw &> /dev/null; then
    ufw status
    ufw allow 80/tcp
    ufw allow 8080/tcp
    echo -e "${GREEN}UFW firewall ports opened${NC}"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --list-all
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --reload
    echo -e "${GREEN}FirewallD ports opened${NC}"
else
    echo -e "${YELLOW}No firewall detected${NC}"
fi

# Create test HTML file to confirm Nginx is serving files
echo -e "${YELLOW}Creating test HTML file...${NC}"
cat > /var/www/html/test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CloudToLocalLLM Test Page</title>
</head>
<body>
    <h1>CloudToLocalLLM Test Page</h1>
    <p>If you can see this page, Nginx is working correctly.</p>
    <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
</body>
</html>
EOF

# Fix permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo -e "${YELLOW}Restarting Docker container...${NC}"
cd /var/www/html
docker-compose down || true
docker-compose up -d

# Test local connection
echo -e "${YELLOW}Testing local connection...${NC}"
curl -I http://localhost
curl -I http://localhost:8080

echo -e "${GREEN}Connection troubleshooting completed!${NC}"
echo -e "${YELLOW}Try accessing the site again at http://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}You can also check http://cloudtolocalllm.online/test.html${NC}"
echo -e "${YELLOW}If still not working, check your domain DNS settings point to this server's IP${NC}" 