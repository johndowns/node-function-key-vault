import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ManagedIdentityCredential } from "@azure/identity"

const credential = new ManagedIdentityCredential(); // Indicates that the function app's managed identity should be used when authenticating to the Graph API.

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');

    const token = await credential.getToken("https://graph.microsoft.com/.default");
    const responseMessage = "The token is: " + token.token;

    context.res = {
        body: responseMessage
    };

};

export default httpTrigger;
