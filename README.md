# CloudToLocalLLM Cloud Component

This is the cloud component for CloudToLocalLLM, providing a secure web interface and remote access to your local LLMs via Docker.

## Features

- **Secure Tunneling**: Built-in ngrok integration for secure remote access
- **Web Interface**: Modern UI for interacting with your LLMs
- **Docker Support**: Easy deployment with Docker and Docker Compose
- **Health Monitoring**: Automatic health checks and status monitoring
- **Landing Page**: Attractive "coming soon" page for initial deployments

## Prerequisites

- Docker and Docker Compose

## Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/thrightguy/CloudToLocalLLM_cloud.git
   cd CloudToLocalLLM_cloud
   ```

2. **Build and Run**
   ```bash
   docker compose up -d --build
   ```

3. **Access the Web Interface**
   - Open your browser and navigate to `http://<your-server-ip>/`
   - Connect to your local LLM instance

## Configuration

- The web application runs on port **80** by default (see `docker-compose.yml`).
- You can change the port mapping in `docker-compose.yml` if needed.

## VPS Deployment

For deploying to your own VPS:

1. **Using the Deployment Script**
   ```bash
   chmod +x deploy_to_vps.sh
   ./deploy_to_vps.sh YOUR_VPS_IP YOUR_VPS_USER [SSH_PORT]
   ```

2. **Manual Deployment**
   See `VPS_DEPLOYMENT.md` for detailed manual deployment instructions.

## Landing Page

The cloud component includes an attractive "coming soon" landing page that:
- Explains the service features
- Has a professional and modern design
- Is responsive for all devices
- Will be replaced by the full application when it's ready

To customize the landing page, edit the files in the `web/` directory.

## Deployment

- For DigitalOcean or Render.com deployment, see the relevant deployment guides in this repo.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Create a pull request

## License

MIT License - see LICENSE file

## Related Projects

- [CloudToLocalLLM](https://github.com/thrightguy/CloudToLocalLLM) - The main Windows application
