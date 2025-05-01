#!/bin/bash

# FastAPI VM Setup Script
# This script sets up a virtual machine with FastAPI, Docker, and Nginx for production deployment
# Usage: ./FastAPI_VM_Setup.sh [domain] [email] [repo_url] [app_directory] [cron_path]

# Exit on any error
set -e

# Default values
DOMAIN=${1:-"example.com"}
EMAIL=${2:-"your-email@example.com"}
REPO_URL=${3:-"https://github.com/username/repository.git"}
APP_DIR=${4:-"app"}
CRON_PATH=${5:-"/home/ubuntu/app"}

echo "Setting up FastAPI environment with the following configuration:"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo "Repository: $REPO_URL"
echo "App Directory: $APP_DIR"
echo "Cron Path: $CRON_PATH"
echo

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install necessary packages
echo "Installing required packages..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git python3-pip python3-venv

# Install Docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker installed successfully."
else
    echo "Docker is already installed."
fi

# Install Docker Compose
echo "Installing Docker Compose..."
if ! command -v docker compose &> /dev/null; then
    mkdir -p ~/.docker/cli-plugins/
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    curl -SL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    echo "Docker Compose installed successfully."
else
    echo "Docker Compose is already installed."
fi

# Clone the repository
echo "Cloning repository..."
if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
else
    echo "Directory $APP_DIR already exists."
    cd "$APP_DIR"
    git pull
fi

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -U pip
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi
    deactivate
fi

# Set up cron job script that runs daily at midnight
echo "Setting up cron job..."
(crontab -l 2>/dev/null; echo "0 0 * * * $CRON_PATH/.venv/bin/python3 $CRON_PATH/main.py") | crontab -

# Build and run Docker Compose services
echo "Building and starting Docker services..."
if [ -f "docker-compose.yml" ]; then
    sudo docker compose up --build -d
else
    echo "No docker-compose.yml found. Skipping Docker Compose setup."
fi

# Install Nginx
echo "Installing and configuring Nginx..."
sudo apt install -y nginx

# Generate self-signed certificates for initial setup
echo "Generating self-signed SSL certificates..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/selfsigned.key \
    -out /etc/ssl/certs/selfsigned.crt \
    -subj "/CN=$DOMAIN" -addext "subjectAltName=DNS:$DOMAIN"

# Create Nginx site configuration
echo "Creating Nginx site configuration..."
sudo bash -c "cat > /etc/nginx/sites-available/fastapi <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF"

# Enable the site and remove default configuration
echo "Enabling Nginx site configuration..."
sudo ln -s /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
echo "Testing and reloading Nginx configuration..."
sudo nginx -t && sudo systemctl reload nginx

# Install Certbot and obtain SSL certificates
echo "Installing Certbot and obtaining SSL certificates..."
sudo apt install -y certbot python3-certbot-nginx
if [[ "$DOMAIN" != "example.com" && "$EMAIL" != "your-email@example.com" ]]; then
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
else
    echo "Using default domain/email. Skipping Let's Encrypt certificate generation."
    echo "To obtain a real SSL certificate, run:"
    echo "sudo certbot --nginx -d your-domain.com --agree-tos --email your-email@example.com"
fi

# Set up firewall
echo "Configuring firewall..."
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo
echo "✅ Setup complete!"
echo "🔒 HTTPS is configured with Nginx as a reverse proxy"
echo "🐳 Docker is running the application"
echo "🔄 Cron job is set up to run daily at midnight"
echo
echo "Next steps:"
echo "1. Ensure your DNS points to this server's IP address"
echo "2. Check that security groups/firewall allow ports 22, 80, and 443"
echo "3. Test your application at https://$DOMAIN"
