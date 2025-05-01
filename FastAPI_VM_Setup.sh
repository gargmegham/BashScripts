#!/bin/bash

# Exit on any error
set -e

# Update system
sudo apt update && sudo apt upgrade -y

# Install necessary packages
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce
sudo systemctl start docker
sudo systemctl enable docker

# Install Docker Compose
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.32.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Clone the repository
git clone https://github.com/gargmegham/!!!REPLACE_WITH_REPO_NAME!!!.git
cd PubTrawlr

# To set up cron job script that runs daily at midnight
(crontab -l 2>/dev/null; echo "0 0 * * * /home/ubuntu/!!!REPLACE WITH YOUR PATH!!!/.venv/bin/python3 /home/ubuntu/!!!REPLACE WITH YOUR PATH!!!/main.py") | crontab -

# To build and run Docker Compose services
sudo docker compose up --build -d

# Install Nginx
sudo apt install -y nginx

# Create Nginx site configuration
sudo bash -c 'cat > /etc/nginx/sites-available/server <<EOF
server {
    listen 443 ssl;
    server_name REPLACE_THIS_WITH_IP_OR_DOMAIN;

    ssl_certificate /etc/ssl/certs/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;

    location / {
        proxy_pass http://localhost:8000;  # Proxy to your FastAPI container running on port 80
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name REPLACE_THIS_WITH_IP_OR_DOMAIN;  # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}
EOF'

# Enable the site and remove default configuration
sudo ln -s /etc/nginx/sites-available/server  /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Install Certbot and obtain SSL certificates
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d chat.pubtrawlr.com --non-interactive --agree-tos --email your-email@example.com

echo "Setup complete. Ensure your DNS points to this instance and security groups allow ports 80 and 443."
