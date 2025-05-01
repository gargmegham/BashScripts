# Exit on any error
set -e

# Define the custom message
CUSTOM_MESSAGE="Replace This With Your Message"

# Install Figlet
sudo apt-get update
sudo apt-get install -y figlet

# Create the MOTD script to display hostname and custom message in ASCII art
sudo bash -c 'cat > /etc/update-motd.d/00-figlet-hostname <<EOF
#!/bin/bash
echo ""
figlet -c "'"$CUSTOM_MESSAGE"'"
echo ""
EOF'

# Make the script executable
sudo chmod +x /etc/update-motd.d/00-figlet-hostname

# Optional: Test the MOTD immediately
sudo run-parts /etc/update-motd.d/

echo "MOTD setup complete. SSH into the instance to see the hostname and custom message in ASCII art."
