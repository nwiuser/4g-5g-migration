#!/bin/bash
set -e
echo "======================================================================"
echo "Installing srsRAN UE (User Equipment)"
echo "======================================================================"

# Get Core machine IP from subnet
CORE_IP="10.0.1.4"
echo "Core IP (from subnet): CORE_IP"

# Update and install Docker
sudo apt-get update
sudo apt-get upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create directory
mkdir -p /home/srsran
cd /home/srsran

# Create docker-compose for UE
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  srsue:
    container_name: srsran-ue
    image: nouisser1/srsue-4g:latest
    networks:
      radio:
    cap_add:
      - NET_ADMIN
      - SYS_NICE
    devices:
      - /dev/net/tun
    ports:
      - "2000:2000"
    environment:
      - ENB_ADDR=10.0.1.4
      - RF_DEVICE_ARGS=tx_port=tcp://*:2000,rx_port=tcp://,id=ue,base_srate=23.04e6

networks:
  radio:
    driver: bridge
COMPOSE

echo "UE service created"
docker-compose up -d

# Display status
sleep 5
echo ""
echo "======================================================================"
echo "UE service status:"
echo "======================================================================"
docker-compose ps
echo ""
echo "To view logs:"
echo "  docker-compose logs -f srsue"
