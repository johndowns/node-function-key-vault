param location string = resourceGroup().location
param runtime string = 'node'
param applicationName string = 'app-${uniqueString(resourceGroup().id)}'
param storageAccountName string = 'fn${uniqueString(resourceGroup().id)}'
param storageAccountType string {
  default: 'Standard_LRS'
  allowed: [
    'Standard_LRS'
    'Standard_GRS'
    'Standard_RAGRS'
  ]
}
param vnetName string = 'MyVNet'
param subnetName string = 'MySubnet'
param serverFarmTier string {
  default: 'EP1'
  allowed: [
    'EP1'
    'EP2'
    'EP3'
  ]
}
param keyVaultSku string = 'Standard'
param keyVaultName string = 'keyvault-${uniqueString(resourceGroup().id)}'
param secretName string = 'MySecret'
param secretValue string {
  secure: true
  default: 'my-secret-value'
}

var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

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

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource appInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: applicationName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: applicationName
  location: location
  sku: {
    name: serverFarmTier
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: function.identity.tenantId
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    accessPolicies: [
      {
        tenantId: function.identity.tenantId
        objectId: function.identity.principalId
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

resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/${secretName}'
  location: location
  properties: {
    value: secretValue
  }
}

resource function 'Microsoft.Web/sites@2020-06-01' = {
  name: applicationName
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
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
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
          value: toLower(applicationName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
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
  name: '${function.name}/virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subnetName)
    swiftSupported: true
  }
}
