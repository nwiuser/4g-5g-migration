# =============================================================================
# Déploiement de srsRAN 4G sur Azure Web App for Containers
# Supporte docker-compose.yml nativement
# =============================================================================

$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = "devops"
$APP_NAME = "srsran-4g-app"
$LOCATION = "francecentral"
$APP_SERVICE_PLAN = "srsran-plan"

Write-Host "🚀 Déploiement de srsRAN 4G sur Azure Web App" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Vérifier si le plan existe
Write-Host "`n📋 Vérification du App Service Plan..." -ForegroundColor Yellow
$planExists = az appservice plan show --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP 2>$null
if (!$planExists) {
    Write-Host "  Création du App Service Plan..." -ForegroundColor Yellow
    az appservice plan create `
        --name $APP_SERVICE_PLAN `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --is-linux `
        --sku B1
}

# Créer Web App
Write-Host "`n🌐 Création de la Web App..." -ForegroundColor Yellow
az webapp create `
    --resource-group $RESOURCE_GROUP `
    --plan $APP_SERVICE_PLAN `
    --name $APP_NAME `
    --multicontainer-config-type compose `
    --multicontainer-config-file docker-compose.yml

Write-Host "`n✅ Déploiement terminé !" -ForegroundColor Green
Write-Host "URL: https://${APP_NAME}.azurewebsites.net" -ForegroundColor Cyan
