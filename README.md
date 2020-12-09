# Azure Function, managed identities, and Key Vault network restrictions (Node.js)

This sample illustrates how to use a Node.js Azure Functions app to read a secret from a Key Vault,
where the Key Vault has been deployed with network restrictions. It also illustrates how to use the
function app's managed identity to obtain a token for an arbitrary resource/API.

The ARM template (see [`deploy/main.json`](deploy/main.json)) deploys all of the necessary
infrastructure, including a VNet, subnet, Azure Functions app, Key Vault, and a Key Vault secret.
The key vault has been configured to only accept requests from the subnet in the VNet. The function
app has been configured with a managed identity, and is deployed with VNet integration so that it
can access the key vault.

The first function (see [`src/MyFunction/index.ts`](src/MyFunction/index.ts)) uses the Key Vault
`SecretClient` with a `ManagedIdentityCredential` to access the secret value without needing to
store any credentials.

The second function (see
[`src/GetTokenForArbitraryResource/index.ts`](src/GetTokenForArbitraryResource/index.ts)) retrieves
a token using the `ManagedIdentityCredential`. In this function, the token could be generated for
any API that the function app's managed identity is authorised to access through Azure AD. The
sample uses the Microsoft Graph API as an example.