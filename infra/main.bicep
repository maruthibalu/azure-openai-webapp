// ============================================================================
// Main Bicep template for Azure OpenAI Web App
// Deploys: App Service Plan, Web App, Azure AI Services (OpenAI) with GPT-4o
// ============================================================================

targetScope = 'resourceGroup'

// ---- Parameters ----

@description('The Azure region for all resources.')
param location string = resourceGroup().location

@description('A unique suffix to ensure globally unique resource names.')
@minLength(3)
@maxLength(12)
param environmentName string

@description('Tags to apply to all resources.')
param tags object = {
  project: 'azure-openai-webapp'
  environment: environmentName
}

@description('The SKU name for the App Service Plan.')
@allowed([
  'F1'
  'B1'
  'B2'
  'S1'
  'P1v3'
])
param appServiceSkuName string = 'B1'

@description('The SKU for the Azure AI Services account.')
@allowed([
  'S0'
  'F0'
])
param aiServicesSkuName string = 'S0'

@description('The GPT model name to deploy.')
param gptModelName string = 'gpt-4o'

@description('The GPT model version.')
param gptModelVersion string = '2024-11-20'

@description('The capacity for the GPT model deployment (in thousands of tokens per minute).')
param gptDeploymentCapacity int = 10

@secure()
@description('The Flask secret key for session management.')
param flaskSecretKey string

// ---- Computed Names ----

var resourcePrefix = 'aoai-${environmentName}'
var appServicePlanName = '${resourcePrefix}-plan'
var webAppName = '${resourcePrefix}-webapp'
var aiServicesName = '${resourcePrefix}-ai'
var customSubDomainName = replace('${resourcePrefix}-ai', '-', '')

// ---- App Service Plan (Linux) ----

module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  params: {
    name: appServicePlanName
    location: location
    tags: tags
    kind: 'linux'
    reserved: true
    skuName: appServiceSkuName
    skuCapacity: 1
    zoneRedundant: false
  }
}

// ---- Azure AI Services (OpenAI) ----

module aiServices 'br/public:avm/res/cognitive-services/account:0.11.0' = {
  params: {
    name: aiServicesName
    kind: 'AIServices'
    location: location
    tags: tags
    sku: aiServicesSkuName
    customSubDomainName: customSubDomainName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    deployments: [
      {
        name: gptModelName
        model: {
          format: 'OpenAI'
          name: gptModelName
          version: gptModelVersion
        }
        sku: {
          name: 'Standard'
          capacity: gptDeploymentCapacity
        }
      }
    ]
  }
}

// ---- Web App ----

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.outputs.resourceId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: appServiceSkuName != 'F1'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appCommandLine: 'gunicorn --bind=0.0.0.0 --timeout 600 app:app'
      appSettings: [
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: aiServices.outputs.endpoint
        }
        {
          name: 'AZURE_OPENAI_API_KEY'
          value: aiServices.outputs.exportedSecrets.?accessKey1.?secretValue ?? ''
        }
        {
          name: 'FLASK_SECRET_KEY'
          value: flaskSecretKey
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
      ]
    }
  }
}

// Since AVM cognitive-services module has disableLocalAuth=true by default,
// we set it to false above and retrieve the key directly
resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesName
  dependsOn: [aiServices]
}

// Update web app settings with the actual API key
module webAppSettings 'modules/webapp-appsettings.bicep' = {
  params: {
    webAppName: webApp.name
    aiServicesEndpoint: aiServices.outputs.endpoint
    aiServicesKey: aiServicesAccount.listKeys().key1
    flaskSecretKey: flaskSecretKey
  }
}

// ---- Outputs ----

@description('The name of the deployed Web App.')
output webAppName string = webApp.name

@description('The default hostname of the Web App.')
output webAppHostname string = webApp.properties.defaultHostName

@description('The URL of the deployed Web App.')
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'

@description('The name of the Azure AI Services account.')
output aiServicesName string = aiServices.outputs.name

@description('The endpoint of the Azure AI Services account.')
output aiServicesEndpoint string = aiServices.outputs.endpoint

@description('The resource group name.')
output resourceGroupName string = resourceGroup().name
