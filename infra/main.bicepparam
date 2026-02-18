using 'main.bicep'

param environmentName = 'dev'
param location = 'eastus2'
param appServiceSkuName = 'B1'
param aiServicesSkuName = 'S0'
param gptModelName = 'gpt-4o'
param gptModelVersion = '2024-11-20'
param gptDeploymentCapacity = 10
param flaskSecretKey = readEnvironmentVariable('FLASK_SECRET_KEY', '')
