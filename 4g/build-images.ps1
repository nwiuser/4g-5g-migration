# PowerShell script to build all srsRAN images separately

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building srsRAN Docker Images Separately" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Build EPC image
Write-Host ""
Write-Host "[1/3] Building EPC (Core Network) image..." -ForegroundColor Yellow
docker build -f Dockerfile.epc -t srsran-epc:latest .
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK - EPC image built successfully: srsran-epc:latest" -ForegroundColor Green
} else {
    Write-Host "ERROR - Failed to build EPC image" -ForegroundColor Red
    exit 1
}

# Build eNodeB image
Write-Host ""
Write-Host "[2/3] Building eNodeB (Base Station) image..." -ForegroundColor Yellow
docker build -f Dockerfile.enb -t srsran-enb:latest .
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK - eNodeB image built successfully: srsran-enb:latest" -ForegroundColor Green
} else {
    Write-Host "ERROR - Failed to build eNodeB image" -ForegroundColor Red
    exit 1
}

# Build UE image
Write-Host ""
Write-Host "[3/3] Building UE (User Equipment) image..." -ForegroundColor Yellow
docker build -f Dockerfile.ue -t srsran-ue:latest .
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK - UE image built successfully: srsran-ue:latest" -ForegroundColor Green
} else {
    Write-Host "ERROR - Failed to build UE image" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "All images built successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available images:" -ForegroundColor Yellow
docker images | Select-String "srsran"

Write-Host ""
Write-Host "To load images into Minikube:" -ForegroundColor Yellow
Write-Host "  minikube image load srsran-epc:latest" -ForegroundColor White
Write-Host "  minikube image load srsran-enb:latest" -ForegroundColor White
Write-Host "  minikube image load srsran-ue:latest" -ForegroundColor White

Write-Host ""
Write-Host "To push to ACR (replace ACR_NAME with your Azure Container Registry name):" -ForegroundColor Yellow
Write-Host '  docker tag srsran-epc:latest ACR_NAME.azurecr.io/srsran-epc:latest' -ForegroundColor White
Write-Host '  docker tag srsran-enb:latest ACR_NAME.azurecr.io/srsran-enb:latest' -ForegroundColor White
Write-Host '  docker tag srsran-ue:latest ACR_NAME.azurecr.io/srsran-ue:latest' -ForegroundColor White
Write-Host ""
Write-Host '  docker push ACR_NAME.azurecr.io/srsran-epc:latest' -ForegroundColor White
Write-Host '  docker push ACR_NAME.azurecr.io/srsran-enb:latest' -ForegroundColor White
Write-Host '  docker push ACR_NAME.azurecr.io/srsran-ue:latest' -ForegroundColor White
