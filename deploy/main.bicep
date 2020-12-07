// Parameters.
param location string = resourceGroup().location
param vnetName string = 'MyVNet'
param subnetName string = 'MySubnet'
param functionsAppRuntime string = 'node'
param functionsAppName string = 'app-${uniqueString(resourceGroup().id)}'
param functionsAppServicePlanTier string {
  default: 'EP1'
  allowed: [
    'EP1'
    'EP2'
    'EP3'
  ]
  metadata: {
    description: 'This must be an elastic premium plan since this sample shows how to use Key Vault network restrictions, which requires VNet integration on the function app.'
  }
}
param storageAccountName string = 'fn${uniqueString(resourceGroup().id)}'
param storageAccountType string {
  default: 'Standard_LRS'
  allowed: [
    'Standard_LRS'
    'Standard_GRS'
    'Standard_RAGRS'
  ]
}
param keyVaultSku string = 'Standard'
param keyVaultName string = 'keyvault-${uniqueString(resourceGroup().id)}'
param secretName string = 'MySecret'
param secretValue string {
  secure: true
  default: 'my-secret-value'
}

// Variables.
var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

// VNet and subnet.
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

// Storage account for the function app to store its metadata.
resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: functionsAppName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Function app hosting plan. This must be an elastic premium plan.
resource serverFarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: functionsAppName
  location: location
  sku: {
    name: functionsAppServicePlanTier
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
  }
}

// Azure Functions app.
resource functionsApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionsAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${applicationInsights.properties.InstrumentationKey}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listkeys(storageAccount.id, '2019-06-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listkeys(storageAccount.id, '2019-06-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionsAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionsAppRuntime
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~12'
        }
        {
          name: 'SecretName'
          value: secretName
        }
        {
          name: 'KeyVaultName'
          value: keyVaultName
        }
      ]
    }
  }
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${functionsApp.name}/virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subnetName)
    swiftSupported: true
  }
}

// Key vault, with an access policy to allow the function app to read secrets, and a network ACL to only allow requests from the subnet used by the function app.
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: functionsApp.identity.tenantId
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    accessPolicies: [
      {
        tenantId: functionsApp.identity.tenantId
        objectId: functionsApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subnetName)
        }
      ]
    }
  }
}

// Sample secret stored in the key vault.
resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/${secretName}'
  location: location
  properties: {
    value: secretValue
  }
}
