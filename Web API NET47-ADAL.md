# Accessing MC4S data via Dataverse API with .Net Framework with Azure Active Directory Authentication Library (ADAL)
> MSAL is recommended over ADAL. This scenario is only meant for legacy scenarios. Please consider following [this other lab](/Web%20API%20NET6-MSAL.md) which uses MSAL. 


## Steps
### Find the endpoint of your dataverse environment
1. Go to http://make.powerplatform.com
1. Make sure that you are in the right environment (check the `Environment` badge on the top right)
1. Click on the settings icon on the top right and select `Developer resources`.
    ![Screenshot](/assets/PowerApps%20Dev%20Settings.png)
1. Take note of the Web API endpoint (you will need this later in this lab). Copy only the part of the URL from "https:" through ".com" **leaving off the /api/data/v9.x**
    ![Screenshot](/assets/PowerApps%20Dev%20Settings2.png)

### Create the AAD App Registration
In this step we will create the App registration (and underlying service principal) that your app will use to run the Azure Active Directory delegate authentication. In other words, we will need this to get the user authenticate with their credentials and use the resulting authentication token to access the dataverse.
1. Go to https://portal.azure.com
1. Navigate to `Azure Active Directory`
1. Navigate to `App registrations`
1. Click `New registration`
1. Fill in the form as following
    - Enter an arbitrary name (for example "my-mc4s-integrated-app")
    - As Supported account types leave it as single tenant
    - As Redirect URI, select `Public client/native (mobile & desktop)` and enter `http://localhost`
    ![Screenshot](/assets/AppRegistration-MSAL-1.png)
1. Click `Register`. The app registration will be created and you will be taken to its Overview tab
1. Take note of the `Application (client) ID` (you will need it later in this lab)
    ![Screenshot](/assets/AppRegistration-MSAL-2.png)
1. Navigate to `API permissions`, click `Add a permission`, select `APIs my organization uses`, type `dataverse` in the search box and select the `Dataverse` item from the list
    ![Screenshot](/assets/AppRegistration-MSAL-APIPermission1.png)
1. Ensure the `user_impersonation` permission is checked and click `Add permission`
    ![Screenshot](/assets/AppRegistration-MSAL-APIPermission2.png)
1. At this point you should see the user_impersonation permission in the permissions list
    ![Screenshot](/assets/AppRegistration-MSAL-APIPermission3.png)
    > The last three steps are necessary to allow your app to impersonate the logged in user to access the MC4S data in the dataverse.

### Create a .Net Framework console app to query the emissions table
1. Open Visual Studio 2019 (or newer) and create a new C# .Net Framework Console App (choose at least .Net Framework 4.7)
2. Open the `Program.cs` file and replace the entire content with the following code:



```C#
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;

namespace MyMC4SApps
{
    class Program
    {
        static void Main()
        {
            // TODO Specify the Dataverse environment name to connect with.
            string resource = "Enter dataverse environment endpoint here";
            // TODO Specify the AAD app registration id.
            var clientId = "Enter App ID here";
            var redirectUri = new Uri("http://localhost");

            #region Authentication

            // The authentication context used to acquire the web service access token
            var authContext = new AuthenticationContext(
                "https://login.microsoftonline.com/common", false);

            // Get the web service access token. Its lifetime is about one hour after
            // which it must be refreshed. For this simple sample, no refresh is needed.
            // See https://docs.microsoft.com/powerapps/developer/data-platform/authenticate-oauth
            var token = authContext.AcquireTokenAsync(
                resource, clientId, redirectUri,
                new PlatformParameters(
                    PromptBehavior.SelectAccount   // Prompt the user for a logon account.
                ),
                UserIdentifier.AnyUser
            ).Result;
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
            headers.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));
            #endregion Client configuration

            var response = client.GetAsync("msdyn_emissions?$top=10").Result;

            if (response.IsSuccessStatusCode)
            {
                using (var stream = response2.Content.ReadAsStreamAsync().Result)
                using (var streamReader = new StreamReader(stream))
                using (var jsonReader = new JsonTextReader(streamReader))
                { 
                    var jsonSerializer = new JsonSerializer();
                    var result = jsonSerializer.Deserialize<DataverseQueryResult<Emission>>(jsonReader);
                    foreach (var emission in result.value)
                        Console.WriteLine($"{emission.msdyn_activityname} activity on {emission.msdyn_transactiondate} emitted {emission.msdyn_co2e} CO2 Equivalent");
                }
            }
            else
            {
                Console.WriteLine("Web API call failed");
                Console.WriteLine("Reason: " + response.ReasonPhrase);
            }

            Console.ReadKey();
        }
    }
    public class DataverseQueryResult<T>
    {
        public IEnumerable<T> value { get; set; }
    }
    public class Emission
    {
        public string msdyn_activityname { get; set; }
        public DateTime msdyn_transactiondate { get; set; }
        public decimal msdyn_co2e { get; set; }
    }
}

```
1. Replace the placeholder `Enter dataverse environment endpoint here` with the url retrieved earlier in this lab
1. Replace the placeholder `Enter App ID here` with the app registration id copied earlier in this lab
1. Add the following NuGet packages:
    - Microsoft.IdentityModel.Clients.ActiveDirectory (please notice this package is deprecated. Consider the lab that uses MSAL instead)
    - Newtonsoft.Json
1. Run the console app
1. A popup box will prompt you toauthenticate
1. After you authenticate, the console app should list the first 10 records of the Emissions table
    ![Screenshot](/assets/WebApi-NET6-result.png)