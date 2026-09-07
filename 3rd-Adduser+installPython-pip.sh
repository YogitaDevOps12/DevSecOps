# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins to apply changes
sudo systemctl restart jenkins

# Verify Jenkins can access Docker
sudo -u jenkins docker ps

# Update & Install Python pip 
sudo apt update
sudo apt install -y python3-venv python3-pip

# Install docker-compose on your Jenkins server:
sudo apt update
sudo apt install -y docker-compose-plugin
