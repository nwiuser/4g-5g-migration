#!/bin/bash
# Install docker-compose
echo 'Installing docker-compose...'
apt update
apt install docker-compose-plugin


# Build the Docker images
docker-compose build

# Start the Docker containers in the background
docker-compose up
