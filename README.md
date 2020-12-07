# Azure Function and Key Vault network restrictions

This sample illustrates how to use a Node.js Azure Functions app to read a secret from a Key Vault,
where the Key Vault has been deployed with network restrictions.

The ARM template (see [`deploy/main.json`](deploy/main.json)) deploys all of the necessary
infrastructure, including a VNet, subnet, Azure Functions app, Key Vault, and a Key Vault secret.
The key vault has been configured to only accept requests from the subnet in the VNet. The function
app has been configured with a managed identity, and is deployed with VNet integration so that it
can access the key vault.

The function (see [`src/MyFunction/index.ts`](src/MyFunction/index.ts)) uses the Key Vault
`SecretClient` with a `ManagedIdentityCredential` to access the secret value without needing to
store any credentials.
