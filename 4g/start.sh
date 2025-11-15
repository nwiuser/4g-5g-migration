#!/bin/bash
# Install docker-compose
echo 'Installing docker-compose...'
sudo apt-get install docker-compose-plugin -y

# Build the Docker images
docker-compose build

# Start the Docker containers in the background
docker-compose up
