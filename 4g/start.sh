#!/bin/bash

# Build the Docker images
docker-compose build

# Check if containers already exist and remove them if they do
if [ "$(docker ps -aq -f name=virtual-srsepc)" ]; then
    echo "Removing existing virtual-srsepc container..."
    docker rm -f virtual-srsepc
fi

if [ "$(docker ps -aq -f name=virtual-srsenb)" ]; then
    echo "Removing existing virtual-srsenb container..."
    docker rm -f virtual-srsenb
fi

if [ "$(docker ps -aq -f name=virtual-srsue)" ]; then
    echo "Removing existing virtual-srsue container..."
    docker rm -f virtual-srsue
fi

# Start the Docker containers in the background
docker-compose up
