# Deploys the Azure OpenAI Web App infrastructure using Bicep
# Usage: .\deploy.ps1 -EnvironmentName "dev" -ResourceGroupName "rg-openai-webapp" -Location "eastus2"

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvironmentName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory=$false)]
    [string]$FlaskSecretKey
)

$ErrorActionPreference = "Stop"

# Generate a Flask secret key if not provided
if (-not $FlaskSecretKey) {
    $FlaskSecretKey = [System.Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]])
    Write-Host "Generated Flask secret key." -ForegroundColor Yellow
}

# Set environment variable for bicepparam
$env:FLASK_SECRET_KEY = $FlaskSecretKey

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group '$ResourceGroupName' exists in '$Location'..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location --output none

# Deploy Bicep template
Write-Host "Deploying infrastructure..." -ForegroundColor Cyan
$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "infra/main.bicep" `
    --parameters "infra/main.bicepparam" `
    --parameters environmentName=$EnvironmentName `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed!"
    exit 1
}

Write-Host ""
Write-Host "=== Deployment Successful ===" -ForegroundColor Green
Write-Host "Web App Name:     $($deploymentResult.webAppName.value)" -ForegroundColor White
Write-Host "Web App URL:      $($deploymentResult.webAppUrl.value)" -ForegroundColor White
Write-Host "AI Services:      $($deploymentResult.aiServicesName.value)" -ForegroundColor White
Write-Host "AI Endpoint:      $($deploymentResult.aiServicesEndpoint.value)" -ForegroundColor White
Write-Host "Resource Group:   $($deploymentResult.resourceGroupName.value)" -ForegroundColor White
Write-Host ""

# Deploy the application code
$webAppName = $deploymentResult.webAppName.value
Write-Host "Deploying application code to '$webAppName'..." -ForegroundColor Cyan

# Create a zip of the application
$zipPath = Join-Path $env:TEMP "webapp-deploy.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

Compress-Archive -Path "app.py", "requirements.txt", "templates" -DestinationPath $zipPath -Force

az webapp deploy `
    --resource-group $ResourceGroupName `
    --name $webAppName `
    --src-path $zipPath `
    --type zip `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "Application deployed successfully!" -ForegroundColor Green
    Write-Host "Visit: $($deploymentResult.webAppUrl.value)" -ForegroundColor Cyan
} else {
    Write-Warning "Application code deployment had issues. You can manually deploy using:"
    Write-Host "  az webapp deploy --resource-group $ResourceGroupName --name $webAppName --src-path <zip-path> --type zip"
}

# Cleanup
Remove-Item $zipPath -ErrorAction SilentlyContinue
$env:FLASK_SECRET_KEY = $null
