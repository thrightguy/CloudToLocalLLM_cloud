param (
    [Parameter(Mandatory=$true)]
    [string]$VpsIp,
    
    [Parameter(Mandatory=$true)]
    [string]$VpsUser,
    
    [Parameter()]
    [string]$SshPort = "22"
)

# CloudToLocalLLM VPS Deployment Script (PowerShell version)
# This script deploys the CloudToLocalLLM cloud component with a landing page to a VPS

# Output colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Starting deployment to VPS (${VpsIp})..."

# Create temporary directory
Write-ColorOutput Yellow "Preparing files for deployment..."
$TempDir = Join-Path $env:TEMP "cloudtolocalllm_deploy_$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TempDir "deploy") | Out-Null

# Copy web files
Copy-Item -Path "web\*" -Destination (Join-Path $TempDir "deploy") -Recurse

# Copy Dockerfile
Copy-Item -Path "Dockerfile" -Destination $TempDir

# Create docker-compose.yml
$DockerComposeContent = @"
version: '3'
services:
  web:
    build: .
    ports:
      - "80:80"
    restart: always
    volumes:
      - ./deploy:/usr/share/nginx/html
"@
Set-Content -Path (Join-Path $TempDir "docker-compose.yml") -Value $DockerComposeContent

# Create nginx.conf
$NginxConfContent = @"
server {
    listen 80;
    server_name _;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files `$uri `$uri/ /index.html;
    }
    
    # Redirect server error pages to static page
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
"@
Set-Content -Path (Join-Path $TempDir "nginx.conf") -Value $NginxConfContent

# SSH into the VPS and prepare the environment
Write-ColorOutput Yellow "Preparing VPS environment..."
ssh -p $SshPort "${VpsUser}@${VpsIp}" "mkdir -p /var/www/cloudtolocalllm"

# Copy files to VPS
Write-ColorOutput Yellow "Uploading files to VPS..."
scp -P $SshPort -r (Join-Path $TempDir "*") "${VpsUser}@${VpsIp}:/var/www/cloudtolocalllm/"

# Deploy on VPS
Write-ColorOutput Yellow "Deploying application on VPS..."
$sshResult = ssh -p $SshPort "${VpsUser}@${VpsIp}" "cd /var/www/cloudtolocalllm && docker-compose down 2>/dev/null || true && docker-compose up -d"

# Cleanup temporary files
Remove-Item -Path $TempDir -Recurse -Force

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput Green "Deployment completed successfully!"
    Write-Host "Your app should be available at: http://$VpsIp/"
    Write-Host ""
    Write-ColorOutput Yellow "Next steps:"
    Write-Host "1. Configure your domain (if you have one) to point to this IP"
    Write-Host "2. Set up SSL with: sudo certbot --nginx -d yourdomain.com"
    
    # Push to Github
    Write-Host ""
    Write-ColorOutput Yellow "Pushing changes to Github..."
    Write-Host "Remember to commit and push these changes to your Github repository."
    Write-Host "git add cloud/web/index.html cloud/web/manifest.json cloud/deploy_to_vps.ps1"
    Write-Host "git commit -m ""Add cloud landing page and deployment script"""
    Write-Host "git push origin main"
} else {
    Write-ColorOutput Red "Error during deployment!"
    exit 1
} 