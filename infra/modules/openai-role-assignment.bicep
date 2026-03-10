@description('Full resource ID of the Azure OpenAI (Cognitive Services) account')
param openAIResourceId string

@description('Principal ID of the managed identity to grant access')
param principalId string

// Cognitive Services OpenAI User – allows inference calls (chat, embeddings)
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// Reference the existing Cognitive Services account by name (last segment of resource ID)
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: last(split(openAIResourceId, '/'))
}

resource openaiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIResourceId, principalId, cognitiveServicesOpenAIUserRoleId)
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = openaiRoleAssignment.id
