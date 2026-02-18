// ============================================================================
// Web App Application Settings Module
// Configures app settings with Azure AI Services connection details
// ============================================================================

@description('The name of the existing Web App.')
param webAppName string

@description('The Azure AI Services endpoint URL.')
param aiServicesEndpoint string

@secure()
@description('The Azure AI Services API key.')
param aiServicesKey string

@secure()
@description('The Flask secret key for session management.')
param flaskSecretKey string

resource webApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: webAppName
}

resource appSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    AZURE_OPENAI_ENDPOINT: aiServicesEndpoint
    AZURE_OPENAI_API_KEY: aiServicesKey
    FLASK_SECRET_KEY: flaskSecretKey
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
    WEBSITE_RUN_FROM_PACKAGE: '0'
  }
}
