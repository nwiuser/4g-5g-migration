# =============================================================================
# Script de Test de Connectivité 4G - srsRAN sur Azure (2 VMs)
# =============================================================================

param(
    [string]$ResourceGroup = "rg-srsran-4g",
    [string]$CoreVM = "srsran-core-vm",
    [string]$UEVM = "srsran-ue-vm"
)

$ErrorActionPreference = "Continue"

# =============================================================================
# Récupération des IPs
# =============================================================================

Write-Host "`n========================================================================"  -ForegroundColor Cyan
Write-Host "  Test de Connectivité 4G - srsRAN Distribué" -ForegroundColor Cyan
Write-Host "========================================================================"  -ForegroundColor Cyan

Write-Host "`nRécupération des adresses IP des VMs..." -ForegroundColor Yellow

$ipCore = az vm show -d --resource-group $ResourceGroup --name $CoreVM --query privateIps -o tsv 2>$null
$publicIpCore = az vm show -d --resource-group $ResourceGroup --name $CoreVM --query publicIps -o tsv 2>$null
$ipUE = az vm show -d --resource-group $ResourceGroup --name $UEVM --query privateIps -o tsv 2>$null
$publicIpUE = az vm show -d --resource-group $ResourceGroup --name $UEVM --query publicIps -o tsv 2>$null

if (-not $ipCore -or -not $ipUE) {
    Write-Host "Erreur: Impossible de récupérer les IPs des VMs" -ForegroundColor Red
    exit 1
}

Write-Host "  Core VM - IP privée: $ipCore | IP publique: $publicIpCore" -ForegroundColor White
Write-Host "  UE VM   - IP privée: $ipUE   | IP publique: $publicIpUE" -ForegroundColor White

# =============================================================================
# TEST 1: Connectivité Réseau
# =============================================================================

$testsPassedCount = 0
$totalTests = 10

Write-Host "`n========================================================================"  -ForegroundColor Cyan
Write-Host "  TEST 1: Connectivité Réseau" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan

Write-Host "`n[1.1] Test SSH vers Core VM (port 22)..." -ForegroundColor Yellow
$sshTestCore = Test-NetConnection -ComputerName $publicIpCore -Port 22 -WarningAction SilentlyContinue

if ($sshTestCore.TcpTestSucceeded) {
    Write-Host "  ✓ SSH accessible sur Core VM" -ForegroundColor Green
    $testsPassedCount++
} else {
    Write-Host "  ✗ SSH non accessible sur Core VM" -ForegroundColor Red
}

Write-Host "`n[1.2] Test SSH vers UE VM (port 22)..." -ForegroundColor Yellow
$sshTestUE = Test-NetConnection -ComputerName $publicIpUE -Port 22 -WarningAction SilentlyContinue

if ($sshTestUE.TcpTestSucceeded) {
    Write-Host "  ✓ SSH accessible sur UE VM" -ForegroundColor Green
    $testsPassedCount++
} else {
    Write-Host "  ✗ SSH non accessible sur UE VM" -ForegroundColor Red
}

Write-Host "`n[1.3] Test Ping UE -> Core (via VNet)..." -ForegroundColor Yellow
$pingScript = @'
ping -c 4 ipCoreValue
'@ -replace 'ipCoreValue', $ipCore

$pingResult = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $UEVM `
    --command-id RunShellScript `
    --scripts $pingScript `
    --query 'value[0].message' -o tsv 2>&1

if ($pingResult -match "4 packets transmitted, 4 received") {
    Write-Host "  [OK] Ping reussi (0`% packet loss)" -ForegroundColor Green
    $testsPassedCount++
} else {
    Write-Host "  [FAIL] Ping echoue" -ForegroundColor Red
    Write-Host "  Resultat: $pingResult" -ForegroundColor Gray
}

Write-Host "`n[1.4] Vérification des ports ZMQ (2000, 2001)..." -ForegroundColor Yellow
$zmqPortCheck = Test-NetConnection -ComputerName $publicIpCore -Port 2001 -WarningAction SilentlyContinue

if ($zmqPortCheck.TcpTestSucceeded) {
    Write-Host "  ✓ Port ZMQ 2001 accessible" -ForegroundColor Green
    $testsPassedCount++
} else {
    Write-Host "  ⚠ Port ZMQ 2001 non accessible (peut être normal selon config firewall)" -ForegroundColor Yellow
}

# =============================================================================
# TEST 2: Connexion 4G (UE <-> eNodeB)
# =============================================================================

Write-Host "`n========================================================================"  -ForegroundColor Cyan
Write-Host "  TEST 2: Connexion UE vers eNodeB" -ForegroundColor Cyan
Write-Host "========================================================================"  -ForegroundColor Cyan

Write-Host "`n[2.1] Vérification des conteneurs sur Core VM..." -ForegroundColor Yellow
$coreContainersScript = @'
cd /home/srsran 2>/dev/null
if [ ! -d /home/srsran ]; then cd /home/azureuser; fi
if [ -f docker-compose.yml ]; then
    docker-compose ps 2>/dev/null
    if [ $? -ne 0 ]; then echo "Docker Compose non installe"; fi
else
    docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null
    if [ $? -ne 0 ]; then echo "Docker non installe"; fi
fi
'@

$coreContainers = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $CoreVM `
    --command-id RunShellScript `
    --scripts $coreContainersScript `
    --query 'value[0].message' -o tsv 2>&1

if ($coreContainers -match "srsran-epc" -and $coreContainers -match "srsran-enb" -and $coreContainers -match "Up") {
    Write-Host "  ✓ EPC et eNodeB en cours d'exécution" -ForegroundColor Green
    Write-Host $coreContainers -ForegroundColor Gray
    $testsPassedCount++
} else {
    Write-Host "  ✗ EPC ou eNodeB non démarrés" -ForegroundColor Red
    Write-Host $coreContainers -ForegroundColor Gray
}

Write-Host "`n[2.2] Vérification du conteneur UE..." -ForegroundColor Yellow
$ueContainersScript = @'
cd /home/srsran 2>/dev/null
if [ ! -d /home/srsran ]; then cd /home/azureuser; fi
if [ -f docker-compose.yml ]; then
    docker-compose ps 2>/dev/null
    if [ $? -ne 0 ]; then echo "Docker Compose non installe"; fi
else
    docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null
    if [ $? -ne 0 ]; then echo "Docker non installe"; fi
fi
'@

$ueContainers = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $UEVM `
    --command-id RunShellScript `
    --scripts $ueContainersScript `
    --query 'value[0].message' -o tsv 2>&1

if ($ueContainers -match "srsue" -and $ueContainers -match "Up") {
    Write-Host "  ✓ UE en cours d'exécution" -ForegroundColor Green
    Write-Host $ueContainers -ForegroundColor Gray
    $testsPassedCount++
} else {
    Write-Host "  ✗ UE non démarré" -ForegroundColor Red
    Write-Host $ueContainers -ForegroundColor Gray
}

Write-Host "`n[2.3] Vérification des logs EPC (authentification UE)..." -ForegroundColor Yellow
$epcLogsScript = @'
cd /home/srsran 2>/dev/null
if [ ! -d /home/srsran ]; then cd /home/azureuser; fi
docker-compose logs --tail 50 srsepc 2>/dev/null | grep -E "Attach|IMSI|Authentication|NAS" | tail -10
'@

$epcLogs = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $CoreVM `
    --command-id RunShellScript `
    --scripts $epcLogsScript `
    --query 'value[0].message' -o tsv 2>&1

if ($epcLogs -match "Attach" -or $epcLogs -match "IMSI") {
    Write-Host "  ✓ EPC a reçu des requêtes d'attachement" -ForegroundColor Green
    Write-Host $epcLogs -ForegroundColor Gray
    $testsPassedCount++
} else {
    Write-Host "  ⚠ Aucune requête d'attachement détectée" -ForegroundColor Yellow
    Write-Host "  Logs EPC:" -ForegroundColor Gray
    Write-Host $epcLogs -ForegroundColor Gray
}

Write-Host "`n[2.4] Vérification des logs eNodeB (connexion radio)..." -ForegroundColor Yellow
$enbLogsScript = @'
cd /home/srsran 2>/dev/null
if [ ! -d /home/srsran ]; then cd /home/azureuser; fi
docker-compose logs --tail 50 srsenb 2>/dev/null | grep -E "RACH|UE|RRC|Attach" | tail -10
'@

$enbLogs = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $CoreVM `
    --command-id RunShellScript `
    --scripts $enbLogsScript `
    --query 'value[0].message' -o tsv 2>&1

if ($enbLogs -match "RACH" -or $enbLogs -match "RRC") {
    Write-Host "  ✓ eNodeB détecte des connexions radio" -ForegroundColor Green
    Write-Host $enbLogs -ForegroundColor Gray
    $testsPassedCount++
} else {
    Write-Host "  ⚠ Aucune activité radio détectée" -ForegroundColor Yellow
    Write-Host "  Logs eNodeB:" -ForegroundColor Gray
    Write-Host $enbLogs -ForegroundColor Gray
}

Write-Host "`n[2.5] Vérification des logs UE (statut connexion)..." -ForegroundColor Yellow
$ueLogsScript = @'
cd /home/srsran 2>/dev/null
if [ ! -d /home/srsran ]; then cd /home/azureuser; fi
docker-compose logs --tail 50 srsue 2>/dev/null | grep -E "Searching|Cell|Attach|Connected|RSRP" | tail -10
'@

$ueLogs = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $UEVM `
    --command-id RunShellScript `
    --scripts $ueLogsScript `
    --query 'value[0].message' -o tsv 2>&1

if ($ueLogs -match "Attached" -or $ueLogs -match "Connected") {
    Write-Host "  ✓ UE connecté au réseau" -ForegroundColor Green
    Write-Host $ueLogs -ForegroundColor Gray
    $testsPassedCount++
} elseif ($ueLogs -match "Searching") {
    Write-Host "  ⚠ UE en recherche de cellule" -ForegroundColor Yellow
    Write-Host $ueLogs -ForegroundColor Gray
} else {
    Write-Host "  ✗ UE non connecté" -ForegroundColor Red
    Write-Host "  Logs UE:" -ForegroundColor Gray
    Write-Host $ueLogs -ForegroundColor Gray
}

# =============================================================================
# TEST 3: Performance
# =============================================================================

Write-Host "`n========================================================================"  -ForegroundColor Cyan
Write-Host "  TEST 3: Performance Réseau" -ForegroundColor Cyan
Write-Host "========================================================================"  -ForegroundColor Cyan

Write-Host "`n[3.1] Vérification de l'interface TUN sur UE..." -ForegroundColor Yellow
$tunScript = @'
docker exec srsran-ue ip addr show tun_srsue 2>/dev/null
if [ $? -ne 0 ]; then echo "Interface TUN non trouvee"; fi
'@

$tunCheck = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $UEVM `
    --command-id RunShellScript `
    --scripts $tunScript `
    --query 'value[0].message' -o tsv 2>&1

if ($tunCheck -match "tun_srsue" -and $tunCheck -match "inet") {
    Write-Host "  ✓ Interface TUN configurée" -ForegroundColor Green
    $tunIP = ($tunCheck | Select-String -Pattern "inet\s+(\d+\.\d+\.\d+\.\d+)").Matches.Groups[1].Value
    Write-Host "  Adresse IP TUN: $tunIP" -ForegroundColor Gray
    $testsPassedCount++
} else {
    Write-Host "  ✗ Interface TUN non trouvée" -ForegroundColor Red
    Write-Host $tunCheck -ForegroundColor Gray
}

# =============================================================================
# Résumé final
# =============================================================================

Write-Host "`n========================================================================"  -ForegroundColor Cyan
Write-Host "  RÉSUMÉ DES TESTS" -ForegroundColor Cyan
Write-Host "========================================================================"  -ForegroundColor Cyan

$successRate = [math]::Round(($testsPassedCount / $totalTests) * 100, 1)

Write-Host "`n  Tests réussis: $testsPassedCount / $totalTests ($successRate%)" -ForegroundColor White

if ($successRate -ge 80) {
    Write-Host "`n  ✓ Déploiement 4G opérationnel" -ForegroundColor Green
} elseif ($successRate -ge 50) {
    Write-Host "`n  ⚠ Déploiement partiel - Vérification nécessaire" -ForegroundColor Yellow
} else {
    Write-Host "`n  ✗ Déploiement non fonctionnel - Dépannage requis" -ForegroundColor Red
}

Write-Host "`n========================================================================`n" -ForegroundColor Cyan
