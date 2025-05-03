# CloudToLocalLLM VPS Deployment Guide

This guide explains how to deploy the CloudToLocalLLM cloud component with its landing page to a Virtual Private Server (VPS). The application is fully containerized with Docker for simple and consistent deployment.

## Prerequisites

- A VPS with SSH access (Ubuntu/Debian recommended)
- SSH key pair for authentication (mandatory)
- Basic knowledge of Linux commands

Note: The deployment scripts will automatically install Docker and Docker Compose if they're not already installed.

## SSH Key Setup

SSH key authentication is required for deployment. If you don't have an SSH key:

1. Generate an SSH key:
   ```powershell
   # Windows (PowerShell)
   ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa"
   ```
   
   ```bash
   # Linux/Mac
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```

2. Copy your public key to the server:
   ```powershell
   # Windows (if ssh-copy-id is available)
   ssh-copy-id -i "$env:USERPROFILE\.ssh\id_rsa" user@your-server-ip -p 22
   
   # Alternative: manually copy the key
   # Display your public key:
   cat "$env:USERPROFILE\.ssh\id_rsa.pub"
   ```
   
   ```bash
   # Linux/Mac
   ssh-copy-id -i ~/.ssh/id_rsa user@your-server-ip -p 22
   ```

3. Verify the connection:
   ```bash
   ssh -i path/to/your/private_key user@your-server-ip
   ```

## Docker Containerization

The CloudToLocalLLM cloud component is fully containerized using Docker:

- `Dockerfile` - Builds the web application using Dart/Flutter and serves it with Nginx
- `docker-compose.yml` - Orchestrates the deployment with proper networking and port mapping
- Deployment scripts handle all setup and configuration automatically

This containerization ensures:
- Consistent environments across different servers
- Easy updates and rollbacks
- Proper isolation and security
- Simplified dependency management

## VPS Cleanup

The deployment script includes a VPS cleanup procedure that:

1. Stops all running Docker containers
2. Removes unused Docker resources (containers, networks, images, volumes)
3. Cleans up the apt cache
4. Removes temporary files
5. Ensures Docker is configured correctly

This cleanup process helps to:
- Free up disk space
- Improve performance
- Eliminate potential conflicts with previous deployments
- Ensure a clean state for new deployments

You can manually run the cleanup script on your VPS with:
```bash
cd /var/www/cloudtolocalllm
bash cleanup_vps.sh
```

## Port Configuration

The application is configured to use port 80 directly:

- Docker container exposes port 80 internally
- Docker Compose maps the container's port 80 to the host's port 80
- No additional port mapping or proxying is needed

This direct port mapping:
- Simplifies the deployment architecture
- Improves performance by eliminating unnecessary layers
- Makes the application directly accessible via HTTP (http://your-vps-ip/)

## Deployment Options

### Option 1: Automated Deployment (Recommended)

The easiest way to deploy is using the included deployment scripts:

#### For Windows Users:

```powershell
# Navigate to the cloud directory
cd path\to\cloud

# Run the PowerShell script with your VPS details and SSH key
.\deploy_to_vps.ps1 -VpsIp YOUR_VPS_IP -VpsUser YOUR_VPS_USERNAME -IdentityFile PATH_TO_PRIVATE_KEY [-SshPort SSH_PORT]

# Example
.\deploy_to_vps.ps1 -VpsIp 123.456.789.012 -VpsUser root -IdentityFile "$env:USERPROFILE\.ssh\id_rsa" -SshPort 22
```

Additional parameters:
- `-IdentityFile` - Path to your SSH private key (mandatory)
- `-InstallDocker` - Set to automatically install and configure Docker (default: true)

The script handles:
- Checking if your SSH key is valid
- Setting up Docker and Docker Compose
- Configuring Docker to use BuildKit (modern builder)
- Creating and deploying the landing page

#### For Linux/Mac Users:

```bash
# Make the script executable
chmod +x deploy_to_vps.sh

# Run the script with your VPS details
./deploy_to_vps.sh YOUR_VPS_IP YOUR_VPS_USERNAME PATH_TO_PRIVATE_KEY [SSH_PORT]

# Example
./deploy_to_vps.sh 123.456.789.012 root ~/.ssh/id_rsa 22
```

The script will:
- Package up the landing page
- Clean up the VPS
- Copy files to your VPS
- Set up Docker
- Start the service on port 80

### Option 2: Manual Deployment

If you prefer to deploy manually, follow these steps:

1. Build and prepare files locally:
   ```bash
   # Create a deployment directory
   mkdir -p deploy/web
   
   # Copy web files
   cp -r web/* deploy/web/
   ```

2. Install Docker on your VPS (if not already installed):
   ```bash
   # Update package lists
   sudo apt-get update
   
   # Install prerequisites
   sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
   
   # Add Docker's official GPG key
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
   
   # Add Docker repository
   sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
   
   # Install Docker CE
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. Clean up the VPS:
   ```bash
   # Stop all running containers
   sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
   
   # Remove unused Docker resources
   sudo docker system prune -af --volumes
   
   # Clean apt cache
   sudo apt-get clean
   sudo apt-get autoremove -y
   
   # Remove temporary files
   sudo rm -rf /tmp/*
   
   # Restart Docker
   sudo systemctl restart docker
   ```

4. Transfer files to your VPS (using SSH key authentication):
   ```bash
   # Create directory on VPS
   ssh -i path/to/your/private_key user@your-vps "mkdir -p /var/www/cloudtolocalllm"
   
   # Copy files
   scp -i path/to/your/private_key -r deploy/* user@your-vps:/var/www/cloudtolocalllm/
   ```

5. Configure and start Docker on VPS:
   ```bash
   ssh -i path/to/your/private_key user@your-vps
   
   # Go to project directory
   cd /var/www/cloudtolocalllm
   
   # Start Docker on port 80
   sudo docker-compose up -d
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
   ssh -i path/to/your/private_key user@your-vps "cd /var/www/cloudtolocalllm && sudo docker-compose restart"
   ```

## Removing Unnecessary Packages

Before deployment, you might want to optimize your Docker image by removing unnecessary packages. This can be done in two ways:

### Option 1: Update .dockerignore

The `.dockerignore` file in the cloud directory already excludes many unnecessary files. You can edit it to add any additional files or directories that shouldn't be included in the Docker image:

```
# Ignore test files
**/test/
*_test.dart

# Ignore build artifacts
build/
.dart_tool/

# Add any other unnecessary files here
```

### Option 2: Multi-stage builds

The `Dockerfile` already uses multi-stage builds to keep the final image small. The first stage builds the application, and only the necessary output files are copied to the final Nginx image.

## Troubleshooting

### Common Issues

- **SSH key authentication fails**: Make sure your public key is properly added to the server's `~/.ssh/authorized_keys` file
- **Docker installation fails**: Try installing Docker manually following the [official Docker documentation](https://docs.docker.com/engine/install/)
- **Web page not loading**: Check if Docker is running with `docker ps` and verify it's using port 80 with `sudo netstat -tulpn | grep 80`
- **SSL certificate issues**: Verify Certbot setup and renewal
- **Permission errors**: Ensure proper permissions on files and directories
- **Port 80 already in use**: Identify and stop any service using port 80 with `sudo lsof -i :80`

### Logs

To check logs:
```bash
ssh -i path/to/your/private_key user@your-vps "cd /var/www/cloudtolocalllm && sudo docker-compose logs"
```

## Support

If you encounter issues or need help with deployment, please open an issue on the GitHub repository. 