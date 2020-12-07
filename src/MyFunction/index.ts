import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ManagedIdentityCredential} from "@azure/identity"
import {SecretClient} from "@azure/keyvault-secrets"

const vaultName = process.env.KeyVaultName;
const url = `https://${vaultName}.vault.azure.net`;
const credential = new ManagedIdentityCredential();
const client = new SecretClient(url, credential);
const secretName = process.env.SecretName

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');

    const secret = await client.getSecret(secretName);
    const responseMessage = "Your secret value is: " + secret.value;

    context.res = {
        body: responseMessage
    };

};

export default httpTrigger;
