# Accessing MC4S data via Dataverse API with non-interactive authentication using .NET 6 and MSAL

> This tutorial implements the server-to-server single-tenant authentication flow with client secret. To use interactive authentication with delegation see [Accessing MC4S data via Dataverse API with interactive authentication on .NET 6 with Microsoft Authentication Library (MSAL)](/Web%20API%20NET6-MSAL.md)

## Steps
### Create the AAD App Registration
In this step we will create the App registration (and underlying service principal) that your app will use to run the Azure Active Directory non-interactive authentication. In other words, we will need this to get the app to authenticate with their client secret and use the resulting authentication token to access the dataverse.
1. Go to https://portal.azure.com
1. Navigate to `Azure Active Directory`
1. In the `Overview` pane, take note of the `Tenant ID` (you will need it later in this lab)
1. Navigate to `App registrations`
1. Click `New registration`
1. Fill in the form as following
    - Enter an arbitrary name (for example "my-mc4s-integrated-app")
    - As Supported account types leave it as single tenant
    - Leave Redirect URI blank
    ![Screenshot](/assets/AppRegistration-MSAL-1b.png)
1. Click `Register`. The app registration will be created and you will be taken to its Overview tab
1. Take note of the `Application (client) ID` (you will need it later in this lab)
    ![Screenshot](/assets/AppRegistration-MSAL-2.png)
1. Click `Certificate & secrets` > `Client secrets` > `New client secret`
    ![Screenshot](/assets/ADF-AppRegistration2.png)
1. Enter an arbitrary description, leave the default expiration and click `Add`
1. Copy and take note of the secret as you will need it later in this lab. You will not be able to retrieve the secret from this page later so please copy it now.

### Find the endpoint of your dataverse environment
1. Go to http://make.powerplatform.com
1. Make sure that you are in the right environment (check the `Environment` badge on the top right)
1. Click on the settings icon on the top right and select `Developer resources`.
    <br/><img alt="Screenshot" src="./assets/PowerApps%20Dev%20Settings.png" width="400" />
1. Take note of the Web API endpoint (you will need this later in this lab). Copy only the part of the URL from "https:" through ".com" **leaving off the /api/data/v9.x**
    <br/><img alt="Screenshot" src="./assets/PowerApps%20Dev%20Settings2.png" width="400" />

### Grant access to dataverse
In this section we will create an application user linked to the app registration and we will grant access to the dataverse

1. Go to https://admin.powerplatform.microsoft.com/
1. Navigate to `Environments` and select the environment where your Microsoft Cloud for Sustainability is installed
1. Take note of your `Environment URL` (you will need this later in this lab). The url will look something like _org12345.crm2.dynamics.com_.
1. Click `Settings` in the toolbar at the top
1. Expand `Users + permissions` and click `Application users`
    ![Screenshot](/assets/ADF-AppUser1.png)
1. Click `New app user`
1. Click `Add an app`
1. From the list, select the app registration that you created previously (for example my-mc4s-integrated-app) and click `Add`
1. In `Business unit` select the organization that matches the Environment URL of which you have taken note earlier
1. Click the edit icon on the right of `security roles`
1. Select `Sustainability all - Read only` from the list and click `Save` and then `Create`
    > For simplicity we are giving a generic reader role in this lab. However, in a production environment you would create a specific role with only the needed permissions.

### Create a .NET 6 console app to query the emissions table
1. Open Visual Studio or Visual Studio Code and create a new .NET 6 Console App
2. Open the `Program.cs` file and replace the entire content with the following code:

    ```C#
    using MyMC4SApp;
    using Microsoft.Identity.Client;  // Microsoft Authentication Library (MSAL)
    using System.Net.Http.Headers;
    using System.Text.Json;

    namespace MyMC4SApp
    {
        class Program
        {
            static async Task Main()
            {
                // TODO Specify the Dataverse environment name to connect with.
                string resource = "Enter dataverse environment endpoint here";
                // TODO Specify the AAD app registration id.
                var clientId = "Enter App ID here";
                var clientSecret = "Enter client secret here";
                var tenantId = "Enter tenant id here";

                #region Authentication
                var authBuilder = ConfidentialClientApplicationBuilder.Create(clientId)
                                .WithAuthority($"https://login.microsoftonline.com/{tenantId}")
                                .WithClientSecret(clientSecret)
                                .Build();
                var scope = resource + "/.default";
                string[] scopes = { scope };

                AuthenticationResult token =
                    authBuilder.AcquireTokenForClient(scopes).ExecuteAsync().Result;
                #endregion Authentication

                #region Client configuration

                var client = new HttpClient
                {
                    // See https://docs.microsoft.com/powerapps/developer/data-platform/webapi/compose-http-requests-handle-errors#web-api-url-and-versions
                    BaseAddress = new Uri(resource + "/api/data/v9.2/"),
                    Timeout = new TimeSpan(0, 2, 0)    // Standard two minute timeout on web service calls.
                };

                // Default headers for each Web API call.
                // See https://docs.microsoft.com/powerapps/developer/data-platform/webapi/compose-http-requests-handle-errors#http-headers
                HttpRequestHeaders headers = client.DefaultRequestHeaders;
                headers.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);
                headers.Add("OData-MaxVersion", "4.0");
                headers.Add("OData-Version", "4.0");
                headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                #endregion Client configuration

                #region Web API call

                var response = await client.GetAsync("msdyn_emissions?$top=10");

                if (response.IsSuccessStatusCode)
                {
                    using (var stream = response.Content.ReadAsStreamAsync())
                    {
                        var result = await JsonSerializer.DeserializeAsync<DataverseQueryResult<Emission>>(await stream)!;
                        await foreach (var emission in result!.value!)
                            Console.WriteLine($"{emission.msdyn_activityname} activity on {emission.msdyn_transactiondate} emitted {emission.msdyn_co2e} CO2 Equivalent");
                    }
                }
                else
                    Console.WriteLine($"Web API call failed with reason {response.ReasonPhrase}");
                #endregion Web API call

                Console.ReadKey();
            }
        }
        public class DataverseQueryResult<T>
        {
            public IAsyncEnumerable<T> value { get; set; }
        }
        public class Emission
        {
            public string? msdyn_activityname { get; set; }
            public DateTime msdyn_transactiondate { get; set; }
            public decimal msdyn_co2e { get; set; }
        }
    }
    ```
1. Replace the placeholder `Enter dataverse environment endpoint here` with the url retrieved earlier in this lab
1. Replace the placeholder `Enter App ID here` with the app registration id copied earlier in this lab
1. Replace the placeholder `Enter client secret here` with the client secret created during the app registration earlier in this lab
1. Replace the placeholder `Enter tenant id here` with the Azure Active Directory ID retrieved earlier in this lab
1. Add the following NuGet packages:
    - Microsoft.Identity.Client
    - Newtonsoft.Json
    <br/><img alt="Screenshot" src="./assets/MSAL-Packages.png" width="400" />
1. Run the console app
1. The console app should list the first 10 records of the Emissions table
    ![Screenshot](/assets/WebApi-NET6-result-non-interactive.png)