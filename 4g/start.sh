#!/bin/bash
# Install docker-compose
echo 'Installing docker-compose...'
su -
apt update
apt install sudo
sudo apt install -y docker-compose

# Build the Docker images
docker-compose build

# Start the Docker containers in the background
docker-compose up
