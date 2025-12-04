#!/bin/bash

# Script to build all srsRAN images separately

set -e

echo "=========================================="
echo "Building srsRAN Docker Images Separately"
echo "=========================================="

# Build EPC image
echo ""
echo "[1/3] Building EPC (Core Network) image..."
docker build -f Dockerfile.epc -t srsran-epc:latest .
echo "✓ EPC image built successfully: srsran-epc:latest"

# Build eNodeB image
echo ""
echo "[2/3] Building eNodeB (Base Station) image..."
docker build -f Dockerfile.enb -t srsran-enb:latest .
echo "✓ eNodeB image built successfully: srsran-enb:latest"

# Build UE image
echo ""
echo "[3/3] Building UE (User Equipment) image..."
docker build -f Dockerfile.ue -t srsran-ue:latest .
echo "✓ UE image built successfully: srsran-ue:latest"

echo ""
echo "=========================================="
echo "✓ All images built successfully!"
echo "=========================================="
echo ""
echo "Available images:"
docker images | grep srsran

echo ""
echo "To push to ACR (replace <ACR_NAME> with your Azure Container Registry name):"
echo "  docker tag srsran-epc:latest <ACR_NAME>.azurecr.io/srsran-epc:latest"
echo "  docker tag srsran-enb:latest <ACR_NAME>.azurecr.io/srsran-enb:latest"
echo "  docker tag srsran-ue:latest <ACR_NAME>.azurecr.io/srsran-ue:latest"
echo ""
echo "  docker push <ACR_NAME>.azurecr.io/srsran-epc:latest"
echo "  docker push <ACR_NAME>.azurecr.io/srsran-enb:latest"
echo "  docker push <ACR_NAME>.azurecr.io/srsran-ue:latest"
