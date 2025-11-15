#!/bin/bash
# Install docker-compose
echo 'Installing docker-compose...'
apk add docker-cli
apt install docker.io

# Build the Docker images
docker-compose build

# Start the Docker containers in the background
docker-compose up
