# =============================================================================
# Deployment srsRAN 4G on 2 Azure VMs (Distributed Architecture)
# VM1: srsran-core (EPC + eNodeB)
# VM2: srsran-ue (UE only)
# =============================================================================

param(
    [switch]$SkipValidation = $false
)

$ErrorActionPreference = "Continue"

# Configuration
$RESOURCE_GROUP = "rg-srsran-4g"
$LOCATION = "francecentral"
$VM_SIZE = "Standard_B2s"  # 2 vCPUs, 4 GB RAM (lighter and within quota)
$IMAGE = "Debian11"  # Lighter than Ubuntu
$ADMIN_USERNAME = "azureuser"

# Distributed VMs
$VM_CORE = "srsran-core-vm"    # EPC + eNodeB
$VM_UE = "srsran-ue-vm"        # UE only

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  Deployment srsRAN 4G on 2 Azure VMs (Distributed)" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

# Create new Resource Group
Write-Host "`n[*] Creating Resource Group..." -ForegroundColor Yellow
Write-Host "  Name: $RESOURCE_GROUP" -ForegroundColor Gray
Write-Host "  Location: $LOCATION" -ForegroundColor Gray

# Suppress error output and check exit code instead
$null = az group show --name $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating new Resource Group..." -ForegroundColor Yellow
    $result = az group create --name $RESOURCE_GROUP --location $LOCATION --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Resource Group created successfully" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Failed to create Resource Group" -ForegroundColor Red
        Write-Host "  $result" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  Resource Group already exists" -ForegroundColor Gray
}

# Create virtual network and subnets
Write-Host "`n[*] Creating virtual network..." -ForegroundColor Yellow
$vnet = "srsran-vnet"
$subnet_core = "subnet-core"
$subnet_ue = "subnet-ue"

# Create VNet
$vnetResult = az network vnet create `
    --resource-group $RESOURCE_GROUP `
    --name $vnet `
    --address-prefix 10.0.0.0/16 `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  VNET created" -ForegroundColor Green
} else {
    Write-Host "  VNET exists" -ForegroundColor Gray
}

# Create Core subnet
$subnetResult = az network vnet subnet create `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $vnet `
    --name $subnet_core `
    --address-prefix 10.0.1.0/24 `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Core subnet created" -ForegroundColor Green
} else {
    Write-Host "  Core subnet exists" -ForegroundColor Gray
}

# Create UE subnet
$subnetResult = az network vnet subnet create `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $vnet `
    --name $subnet_ue `
    --address-prefix 10.0.2.0/24 `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  UE subnet created" -ForegroundColor Green
} else {
    Write-Host "  UE subnet exists" -ForegroundColor Gray
}

# Create NSG for Core
Write-Host "`n[*] Configuring network security groups..." -ForegroundColor Yellow
$nsg_core = "srsran-core-nsg"
$nsgResult = az network nsg create `
    --resource-group $RESOURCE_GROUP `
    --name $nsg_core `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Core NSG created" -ForegroundColor Green
} else {
    Write-Host "  Core NSG exists" -ForegroundColor Gray
}

# NSG rules for Core (S1, GTP-U, ZMQ)
$coreRules = @(
    @{name = "allow-s1-mme"; port = 36412; protocol = "Tcp"; priority = 100},
    @{name = "allow-gtp-u"; port = 2152; protocol = "Udp"; priority = 110},
    @{name = "allow-zmq-rx"; port = 2001; protocol = "Tcp"; priority = 120},
    @{name = "allow-ssh"; port = 22; protocol = "Tcp"; priority = 130}
)

foreach ($rule in $coreRules) {
    $ruleResult = az network nsg rule create `
        --resource-group $RESOURCE_GROUP `
        --nsg-name $nsg_core `
        --name $rule.name `
        --priority $rule.priority `
        --access Allow `
        --protocol $rule.protocol `
        --destination-port-ranges $rule.port `
        --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Rule $($rule.name) created" -ForegroundColor Green
    } else {
        Write-Host "  Rule $($rule.name) exists" -ForegroundColor Gray
    }
}

# Create NSG for UE
$nsg_ue = "srsran-ue-nsg"
$nsgResult = az network nsg create `
    --resource-group $RESOURCE_GROUP `
    --name $nsg_ue `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  UE NSG created" -ForegroundColor Green
} else {
    Write-Host "  UE NSG exists" -ForegroundColor Gray
}

# NSG rules for UE (ZMQ TX, SSH)
$ueRules = @(
    @{name = "allow-zmq-tx"; port = 2000; protocol = "Tcp"; priority = 100},
    @{name = "allow-ssh"; port = 22; protocol = "Tcp"; priority = 110}
)

foreach ($rule in $ueRules) {
    $ruleResult = az network nsg rule create `
        --resource-group $RESOURCE_GROUP `
        --nsg-name $nsg_ue `
        --name $rule.name `
        --priority $rule.priority `
        --access Allow `
        --protocol $rule.protocol `
        --destination-port-ranges $rule.port `
        --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Rule $($rule.name) created" -ForegroundColor Green
    } else {
        Write-Host "  Rule $($rule.name) exists" -ForegroundColor Gray
    }
}

# Create Core VM (EPC + eNodeB)
Write-Host "`n[*] Creating Core VM (EPC + eNodeB)..." -ForegroundColor Yellow
Write-Host "  Type: $VM_SIZE (Recent CPU with AVX2)" -ForegroundColor Gray
Write-Host "  Subnet: $subnet_core (10.0.1.0)" -ForegroundColor Gray

$vmResult = az vm create `
    --resource-group $RESOURCE_GROUP `
    --name $VM_CORE `
    --image $IMAGE `
    --size $VM_SIZE `
    --admin-username $ADMIN_USERNAME `
    --vnet-name $vnet `
    --subnet $subnet_core `
    --nsg $nsg_core `
    --public-ip-sku Standard `
    --generate-ssh-keys `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Core VM created" -ForegroundColor Green
} else {
    Write-Host "  Core VM exists" -ForegroundColor Gray
}

# Create UE VM
Write-Host "`n[*] Creating UE VM..." -ForegroundColor Yellow
Write-Host "  Type: $VM_SIZE (Recent CPU with AVX2)" -ForegroundColor Gray
Write-Host "  Subnet: $subnet_ue (10.0.2.0)" -ForegroundColor Gray

$vmResult = az vm create `
    --resource-group $RESOURCE_GROUP `
    --name $VM_UE `
    --image $IMAGE `
    --size $VM_SIZE `
    --admin-username $ADMIN_USERNAME `
    --vnet-name $vnet `
    --subnet $subnet_ue `
    --nsg $nsg_ue `
    --public-ip-sku Standard `
    --generate-ssh-keys `
    --output none 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  UE VM created" -ForegroundColor Green
} else {
    Write-Host "  UE VM exists" -ForegroundColor Gray
}

# Get IP addresses
Write-Host "`n[*] Retrieving IP addresses..." -ForegroundColor Yellow

$ipCore = az vm show -d --resource-group $RESOURCE_GROUP --name $VM_CORE --query privateIps -o tsv
$publicIpCore = az vm show -d --resource-group $RESOURCE_GROUP --name $VM_CORE --query publicIps -o tsv

$ipUE = az vm show -d --resource-group $RESOURCE_GROUP --name $VM_UE --query privateIps -o tsv
$publicIpUE = az vm show -d --resource-group $RESOURCE_GROUP --name $VM_UE --query publicIps -o tsv

Write-Host "`n[OK] VMs created/configured" -ForegroundColor Green
Write-Host ""
Write-Host "CORE VM (EPC + eNodeB):" -ForegroundColor Cyan
Write-Host "  Name: $VM_CORE" -ForegroundColor White
Write-Host "  Private IP: $ipCore" -ForegroundColor White
Write-Host "  Public IP: $publicIpCore" -ForegroundColor White
Write-Host ""
Write-Host "UE VM (User Equipment):" -ForegroundColor Cyan
Write-Host "  Name: $VM_UE" -ForegroundColor White
Write-Host "  Private IP: $ipUE" -ForegroundColor White
Write-Host "  Public IP: $publicIpUE" -ForegroundColor White
Write-Host ""

# Installation script for Core VM
$coreScript = @"
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
sudo usermod -aG docker `$USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-`$(uname -s)-`$(uname -m)" -o /usr/local/bin/docker-compose
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
"@

# Installation script for UE VM
$ueScript = @"
#!/bin/bash
set -e
echo "======================================================================"
echo "Installing srsRAN UE (User Equipment)"
echo "======================================================================"

# Get Core machine IP from subnet
CORE_IP="$ipCore"
echo "Core IP (from subnet): CORE_IP"

# Update and install Docker
sudo apt-get update
sudo apt-get upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker `$USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-`$(uname -s)-`$(uname -m)" -o /usr/local/bin/docker-compose
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
      - ENB_ADDR=$ipCore
      - RF_DEVICE_ARGS=tx_port=tcp://*:2000,rx_port=tcp://$ipCore:2001,id=ue,base_srate=23.04e6

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
"@

# Execute installation scripts
Write-Host "`n[*] Installing on VMs..." -ForegroundColor Yellow
Write-Host "  This will take 5-10 minutes per VM..." -ForegroundColor Gray

Write-Host "`n  -> Installing Core VM..." -ForegroundColor Yellow
$coreScript | Out-File -FilePath "install-core.sh" -Encoding UTF8
az vm run-command invoke `
    --resource-group $RESOURCE_GROUP `
    --name $VM_CORE `
    --command-id RunShellScript `
    --scripts @install-core.sh `
    --output none

Write-Host "`n  -> Installing UE VM..." -ForegroundColor Yellow
$ueScript | Out-File -FilePath "install-ue.sh" -Encoding UTF8
az vm run-command invoke `
    --resource-group $RESOURCE_GROUP `
    --name $VM_UE `
    --command-id RunShellScript `
    --scripts @install-ue.sh `
    --output none

Write-Host "`n[OK] Installations completed !" -ForegroundColor Green

# Final summary
Write-Host "`n" -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "                    DEPLOYMENT SUCCESSFUL" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green

Write-Host "`n[INFO] DEPLOYED ARCHITECTURE:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  CORE VM (10.0.1.0/24):" -ForegroundColor White
Write-Host "    - srsepc (EPC) - Ports 36412 (S1-MME), 2152 (GTP-U)" -ForegroundColor Gray
Write-Host "    - srsenb (eNodeB) - Port 2001 (ZMQ RX)" -ForegroundColor Gray
Write-Host ""
Write-Host "  UE VM (10.0.2.0/24):" -ForegroundColor White
Write-Host "    - srsue (User Equipment) - Port 2000 (ZMQ TX)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Communication via Azure VNet (10.0.0.0/16)" -ForegroundColor Gray
Write-Host ""

Write-Host "[INFO] CONNECTIVITY:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Core VM:" -ForegroundColor White
Write-Host "    Private IP: $ipCore" -ForegroundColor Yellow
Write-Host "    Public IP:  $publicIpCore" -ForegroundColor Yellow
Write-Host ""
Write-Host "  UE VM:" -ForegroundColor White
Write-Host "    Private IP: $ipUE" -ForegroundColor Yellow
Write-Host "    Public IP:  $publicIpUE" -ForegroundColor Yellow
Write-Host ""

Write-Host "[INFO] USEFUL COMMANDS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Connect to Core VM:" -ForegroundColor White
Write-Host "    ssh -i ~/.ssh/id_rsa azureuser@$publicIpCore" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Connect to UE VM:" -ForegroundColor White
Write-Host "    ssh -i ~/.ssh/id_rsa azureuser@$publicIpUE" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Check services on Core:" -ForegroundColor White
Write-Host "    docker-compose ps" -ForegroundColor Yellow
Write-Host "    docker-compose logs -f" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Check UE:" -ForegroundColor White
Write-Host "    docker-compose logs -f srsue" -ForegroundColor Yellow
Write-Host ""

Write-Host "[INFO] MONITORING:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Azure Portal:" -ForegroundColor White
Write-Host "    https://portal.azure.com" -ForegroundColor Yellow
Write-Host ""
Write-Host "  List resources:" -ForegroundColor White
Write-Host "    az resource list -g $RESOURCE_GROUP -o table" -ForegroundColor Yellow
Write-Host ""

Write-Host "[INFO] NEXT STEPS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Verify connectivity between Core and UE" -ForegroundColor White
Write-Host "  2. Validate UE connection to eNodeB" -ForegroundColor White
Write-Host "  3. Test performance (throughput, latency)" -ForegroundColor White
Write-Host "  4. Add 5G services in the future" -ForegroundColor White
Write-Host ""

Write-Host "[INFO] Local files created:" -ForegroundColor Gray
Write-Host "  - install-core.sh" -ForegroundColor Gray
Write-Host "  - install-ue.sh" -ForegroundColor Gray
Write-Host ""
