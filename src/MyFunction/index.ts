import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ManagedIdentityCredential} from "@azure/identity"
import {SecretClient} from "@azure/keyvault-secrets"

const vaultName = process.env.KeyVaultName; // The name of the key vault. This is specified in the ARM template and is made accessible through an app setting.
const url = `https://${vaultName}.vault.azure.net`;
const credential = new ManagedIdentityCredential(); // Indicates that the function app's managed identity should be used when authenticating to Key Vault.
const client = new SecretClient(url, credential);
const secretName = process.env.SecretName // The name of the secret to read. This is specified in the ARM template and is made accessible through an app setting.

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');

    const secret = await client.getSecret(secretName);
    const responseMessage = "Your secret value is: " + secret.value;

    context.res = {
        body: responseMessage
    };

};

export default httpTrigger;
