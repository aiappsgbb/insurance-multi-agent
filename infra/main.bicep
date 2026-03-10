targetScope = 'resourceGroup'

@description('The environment name')
param environmentName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('The backend container image to deploy')
param backendContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('The frontend container image to deploy')
param frontendContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('The project name for resource naming')
param projectName string = 'shadcn-fastapi'

@description('Azure OpenAI endpoint URL')
param azureOpenAIEndpoint string = ''

@description('Azure OpenAI deployment name')
param azureOpenAIDeploymentName string = 'gpt-4o'

@description('Azure OpenAI API version')
param azureOpenAIApiVersion string = '2025-04-01-preview'

@description('Azure OpenAI embedding model')
param azureOpenAIEmbeddingModel string = 'text-embedding-3-large'

@description('Resource ID of the Azure OpenAI account for RBAC (e.g. /subscriptions/.../resourceGroups/.../providers/Microsoft.CognitiveServices/accounts/...)')
param azureOpenAIResourceId string = ''

// Generate a short unique suffix for resource naming
var uniqueSuffix = take(uniqueString(resourceGroup().id), 6)

// Common tags for all resources
var commonTags = {
  Environment: environmentName
  Project: projectName
  Location: location
  ManagedBy: 'Bicep'
}

// Simple, short resource names that stay within limits
var containerAppsEnvironmentName = 'env-${uniqueSuffix}'
var containerRegistryName = 'cr${uniqueSuffix}'
var managedIdentityName = 'id-${uniqueSuffix}'
var backendContainerAppName = 'backend-${uniqueSuffix}'
var frontendContainerAppName = 'frontend-${uniqueSuffix}'

// Create managed identity for container registry access
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: commonTags
}

// Deploy container apps stack (environment + registry)
module containerAppsStack 'modules/container-apps-stack.bicep' = {
  name: 'container-apps-stack'
  params: {
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    location: location
    tags: commonTags
    projectName: projectName
    environmentName: environmentName
  }
}

// Assign AcrPull role to managed identity
module roleAssignment 'modules/role-assignment.bicep' = {
  name: 'role-assignment'
  params: {
    registryId: containerAppsStack.outputs.containerRegistryId
    managedIdentityPrincipalId: managedIdentity.properties.principalId
    resourcePrefix: uniqueSuffix
  }
  dependsOn: [
    containerAppsStack
    managedIdentity
  ]
}

// Assign Cognitive Services OpenAI User role on the Azure OpenAI resource.
// The AOAI resource may live in a different resource group (or even subscription);
// we extract both subscription and RG from the full resource ID so the module
// deploys into the correct scope.
module openaiRoleAssignment 'modules/openai-role-assignment.bicep' = if (!empty(azureOpenAIResourceId)) {
  name: 'openai-role-assignment'
  scope: resourceGroup(split(azureOpenAIResourceId, '/')[2], split(azureOpenAIResourceId, '/')[4])
  params: {
    openAIResourceId: azureOpenAIResourceId
    principalId: managedIdentity.properties.principalId
  }
  dependsOn: [
    managedIdentity
  ]
}

// Deploy backend container app
module backendContainerApp 'modules/containerapp.bicep' = {
  name: 'backend-container-app'
  params: {
    name: backendContainerAppName
    location: location
    environmentId: containerAppsStack.outputs.containerAppsEnvironmentId
    containerImage: backendContainerImage
    containerPort: 8000
    registryServer: containerAppsStack.outputs.containerRegistryLoginServer
    managedIdentityResourceId: managedIdentity.id
    managedIdentityClientId: managedIdentity.properties.clientId
    tags: commonTags
    resourcePrefix: uniqueSuffix
    environmentVariables: [
      {
        name: 'ENVIRONMENT'
        value: 'production'
      }
      {
        name: 'FRONTEND_ORIGIN'
        value: 'https://${frontendContainerAppName}.${containerAppsStack.outputs.containerAppsEnvironmentDefaultDomain}'
      }
      {
        name: 'AZURE_OPENAI_ENDPOINT'
        value: azureOpenAIEndpoint
      }
      {
        name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
        value: azureOpenAIDeploymentName
      }
      {
        name: 'AZURE_OPENAI_API_VERSION'
        value: azureOpenAIApiVersion
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_MODEL'
        value: azureOpenAIEmbeddingModel
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: managedIdentity.properties.clientId
      }
    ]
  }
  dependsOn: [
    containerAppsStack
    roleAssignment
  ]
}

// Deploy frontend container app
module frontendContainerApp 'modules/containerapp.bicep' = {
  name: 'frontend-container-app'
  params: {
    name: frontendContainerAppName
    location: location
    environmentId: containerAppsStack.outputs.containerAppsEnvironmentId
    containerImage: frontendContainerImage
    containerPort: 3000
    registryServer: containerAppsStack.outputs.containerRegistryLoginServer
    managedIdentityResourceId: managedIdentity.id
    managedIdentityClientId: managedIdentity.properties.clientId
    tags: commonTags
    resourcePrefix: uniqueSuffix
    environmentVariables: [
      {
        name: 'API_URL'
        value: 'https://${backendContainerApp.outputs.fqdn}'
      }
    ]
  }
  dependsOn: [
    containerAppsStack
    roleAssignment
    backendContainerApp
  ]
}

// Outputs
output backendContainerAppFqdn string = backendContainerApp.outputs.fqdn
output frontendContainerAppFqdn string = frontendContainerApp.outputs.fqdn
output containerRegistryLoginServer string = containerAppsStack.outputs.containerRegistryLoginServer
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output resourceGroupName string = resourceGroup().name

