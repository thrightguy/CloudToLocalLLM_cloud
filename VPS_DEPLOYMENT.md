# CloudToLocalLLM VPS Deployment Guide

This guide explains how to deploy the CloudToLocalLLM cloud component with its landing page to a Virtual Private Server (VPS).

## Prerequisites

- A VPS with SSH access (Ubuntu/Debian recommended)
- Docker and Docker Compose installed on your VPS
- SSH access to your VPS
- Basic knowledge of Linux commands

## Deployment Options

### Option 1: Automated Deployment (Recommended)

The easiest way to deploy is using the included deployment scripts:

#### For Windows Users:

```powershell
# Navigate to the cloud directory
cd path\to\cloud

# Run the PowerShell script with your VPS details
.\deploy_to_vps.ps1 -VpsIp YOUR_VPS_IP -VpsUser YOUR_VPS_USERNAME [-SshPort SSH_PORT]

# Example
.\deploy_to_vps.ps1 -VpsIp 123.456.789.012 -VpsUser root -SshPort 22
```

#### For Linux/Mac Users:

```bash
# Make the script executable
chmod +x deploy_to_vps.sh

# Run the script with your VPS details
./deploy_to_vps.sh YOUR_VPS_IP YOUR_VPS_USERNAME [SSH_PORT]

# Example
./deploy_to_vps.sh 123.456.789.012 root 22
```

The script will:
- Package up the landing page
- Copy it to your VPS
- Set up Docker and Nginx
- Start the service

### Option 2: Manual Deployment

If you prefer to deploy manually, follow these steps:

1. Build and prepare files locally:
   ```bash
   # Create a deployment directory
   mkdir -p deploy/web
   
   # Copy web files
   cp -r web/* deploy/web/
   ```

2. Transfer files to your VPS:
   ```bash
   # Create directory on VPS
   ssh user@your-vps "mkdir -p /var/www/cloudtolocalllm"
   
   # Copy files
   scp -r deploy/* user@your-vps:/var/www/cloudtolocalllm/
   ```

3. Configure and start Docker on VPS:
   ```bash
   ssh user@your-vps
   
   # Go to project directory
   cd /var/www/cloudtolocalllm
   
   # Start Docker
   docker-compose up -d
   ```

## Setting Up a Domain and SSL

Once deployed, you might want to set up a domain and SSL:

1. Point your domain to your VPS IP address using DNS records
2. Install Certbot on your VPS:
   ```bash
   sudo apt update
   sudo apt install certbot python3-certbot-nginx
   ```
3. Obtain SSL certificate:
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

## Updating the Deployment

To update your deployment after changes:

1. Make changes to files locally
2. Run the deployment script again or manually transfer files
3. Restart the Docker container:
   ```bash
   ssh user@your-vps "cd /var/www/cloudtolocalllm && docker-compose restart"
   ```

## Troubleshooting

### Common Issues

- **Web page not loading**: Check if Docker is running with `docker ps`
- **SSL certificate issues**: Verify Certbot setup and renewal
- **Permission errors**: Ensure proper permissions on files and directories

### Logs

To check logs:
```bash
ssh user@your-vps "cd /var/www/cloudtolocalllm && docker-compose logs"
```

## Support

If you encounter issues or need help with deployment, please open an issue on the GitHub repository. 