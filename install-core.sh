#!/bin/bash
set -e
echo "======================================================================"
echo "Installing srsRAN Core (EPC + eNodeB)"
echo "======================================================================"

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

# Create docker-compose for Core (EPC + eNodeB only)
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  srsepc:
    container_name: srsran-epc
    image: nouisser1/srsepc-4g:latest
    networks:
      backend:
        ipv4_address: 10.100.1.10
    cap_add:
      - NET_ADMIN
      - SYS_NICE
    devices:
      - /dev/net/tun
    ports:
      - "36412:36412"
      - "2152:2152/udp"
    environment:
      - MME_ADDR=0.0.0.0
      - SPGW_ADDR=0.0.0.0

  srsenb:
    container_name: srsran-enb
    image: nouisser1/srsenb-4g:latest
    depends_on:
      - srsepc
    networks:
      backend:
        ipv4_address: 10.100.1.20
    cap_add:
      - SYS_NICE
    ports:
      - "2001:2001"
    environment:
      - ENB_MME_ADDR=srsepc
      - ENB_GTP_ADDR=0.0.0.0
      - RF_DEVICE_ARGS=fail_on_disconnect=true,tx_port=tcp://*:2001

networks:
  backend:
    driver: bridge
    ipam:
      config:
        - subnet: 10.100.1.0/24
COMPOSE

echo "Core services created"
docker-compose up -d

# Display status
sleep 5
echo ""
echo "======================================================================"
echo "Core services status:"
echo "======================================================================"
docker-compose ps
echo ""
echo "To view logs:"
echo "  docker-compose logs -f srsepc"
echo "  docker-compose logs -f srsenb"
