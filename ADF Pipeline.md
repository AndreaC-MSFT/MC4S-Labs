# Build an Azure Data Factory Pipeline to copy data from MC4S
In this lab, we will create an ADF pipeline that will connect to your dataverse environment and will copy three columns of the Emissions table into a json file in a blob storage.

## Prerequisites
- An Azure Subscription linked to the same tenant where your Microsoft Cloud for Sustainability environment is deployed.

## Steps
### Create an AAD App registration
The Azure Data Factory pipeline will use this app registration to gain access to your dataverse environment.
1. Go to https://portal.azure.com
1. Navigate to `Azure Active Directory`
1. Navigate to `App registrations`
1. Click `New registration`
1. Fill in the form as following
    - Enter an arbitrary name (for example "adf-mc4s")
    - As Supported account types leave it as single tenant
    - Leave the Redirect URI section blank
    ![Screenshot](/assets/ADF-AppRegistration1.png)
1. Click `Register`. The app registration will be created and you will be taken to its Overview tab
1. Take note of the `Application (client) ID` (you will need it later in this lab)
1. Click `Certificate & secrets` > `Client secrets` > `New client secret`
    ![Screenshot](/assets/ADF-AppRegistration2.png)
1. Enter an arbitrary description, leave the default expiration and click `Add`
1. Copy and take note of the secret as you will need it later in this lab. You will not be able to retrieve the secret from this page later so please copy it now.

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
1. From the list, select the app registration that you created previously (for example adf-mc4s) and click `Add`
1. In `Business unit` select the organization that matches the Environment URL of which you have taken note earlier
1. Click the edit icon on the right of `security roles`
1. Select `System administrator` from the list and click `Save` and then `Create`
    > For simplicity we are giving ADF the System Administrator role in this lab. However, in a production environment you would create a specific role with only the needed permissions.

### Create a storage account
In this section we will create the storage account to which ADF pipeline will write the output files
1. Go to http://portal.azure.com
1. Create a new Storage Account resource
    - Give an arbitrary name such as _samc4s_
    - Select a region (preferably the same where your MC4S environment is deployed)
    - As `Redundancy` select `Locally-reduntant storage (LRS)`
    - Leave everything else as default and create the resource
    ![Screenshot](/assets/ADF-Storage.png)
1. Once the storage account has been created, navigate to `Containers` and click to the `+ Container` button in the toolbar to create a new container
    - Name: `adf-output`
    - Access level: Private
    ![Screenshot](/assets/ADF-Storage-container.png)

### Create an Azure Data Factory resource
1. From the Azure portal, create a new Data Factory resource
    ![Screenshot](/assets/ADF-df1.png)
1. In the `Basic` tab enter a name (for example _adf-mc4s_) and select the same region you selected earlier for the storage account
    ![Screenshot](/assets/ADF-df2.png)
1. In the `Git configuration` tab check `Configure Git later`
    ![Screenshot](/assets/ADF-df3.png)
1. Leave all the other options as default and go ahead with creating the ADF resource
1. Once the resource is created, from the Overview tab, click `Open Azure Data Factory Studio`
    ![Screenshot](/assets/ADF-df4.png)

### Create the ADF Linked Services
In this section we will create the linked services to Dataverse (for the pipeline input) and to the storage account (for the pipeline output)
1. From the Azure Data Factory Studio click on _Manage_ icon (the last in the toolbar on the left) > `Linked services` > `New`
    ![Screenshot](/assets/ADF-LinkedService1.png)
1. Search for `dataverse`, select `Dataverse (Common Data Service for Apps)` and click `Continue`
1. Fill in the `New linked service` page as follows:
    - Name: `MC4S Dataverse Link`
    - Service Uri: enter the Environment URL of which you have taken note earlier in the lab
    - Service principal ID: enter the Application (client) ID of which you have taken note earlier in the lab
    - Service principal key: enter the secret key created earlier in the lab
    ![Screenshot](/assets/ADF-LinkedService2.png)
1. Click `Test connection` to validate the connection
1. Click `Create`
1. In the `Linked services` page, click again on `New` (we will now create the output connection to the storage account)
1. Search for `storage`, select `Azure Blob Storage` and click `Continue`
    ![Screenshot](/assets/ADF-LinkedService3.png)

1. Fill in the `New linked service` page as follows:
    - Name: `Blob storage link`
    - Storage account name: select from the list the storage account you have created earlier in this lab
    ![Screenshot](/assets/ADF-LinkedService4.png)
1. Click `Test connection` to validate the connection
1. Click `Create`
1. In the `Linked services` page you should now see the two linked services
    ![Screenshot](/assets/ADF-LinkedService5.png)

### Create the input dataset
1. In the left side tool bar select the Author icon (the second from the top). Click `+` and then `Dataset` to add a dataset
    ![Screenshot](/assets/ADF-Dataset1.png)
1. In the _New dataset_ page search for `dataverse`, select `Dataverse (Common Data Service for Apps)` and click `Continue`
1. In the _Set properties_ page, fill in the form as follows:
    - Name: `Emissions`
    - Linked service: Select `MC4S Dataverse Link` from the list
    - Entity name: Select `Emission (msdyn_emission)` from the list
    - Click `OK`
    ![Screenshot](/assets/ADF-Dataset2.png)
1. Test the connection and when all looks fine click `Publish all` and then `Publish`
    ![Screenshot](/assets/ADF-Dataset3.png)

### Create the output dataset
1. In the left side tool bar select the Author icon, click `+` and then `Dataset` to add a dataset
    ![Screenshot](/assets/ADF-Dataset1.png)
1. In the _New dataset_ page search for `storage`, select `Azure Blob Storage` and click `Continue`
1. In the _Select format_ page select `JSON` and click `Continue`
    ![Screenshot](/assets/ADF-Dataset4.png)    
1. In the _Set properties_ page, fill in the form as follows:
    - Name: `OutputEmissions`
    - Linked service: Select `Blob storage link` from the list
    - File path: `adf-output` / `mc4s` (leave the last box blank)
    - Import schema: `From sample file`
    - Download [this file](/assets/adf-sample-schema.json) locally and then select it with the `Browse` button
    - Click `OK`
    ![Screenshot](/assets/ADF-Dataset5.png)
1. Test the connection and when all looks fine click `Publish all` and then `Publish`
    ![Screenshot](/assets/ADF-Dataset6.png)

### Create the ADF pipeline
1. In the left side tool bar select the Author icon, click `+` > `Pipeline` > `Pipeline`
    ![Screenshot](/assets/ADF-Pipeline1.png)
1. Expand `Move & transform` and drag the `Copy data` activity into the design surface
    ![Screenshot](/assets/ADF-Pipeline2.png) 
1. In the `Source` tab select `Emissions` as source dataset
    ![Screenshot](/assets/ADF-Pipeline3.png) 
1. In the `Synk` tab select `OutputEmissions` as synk dataset and select `Array of objects` as file pattern
    ![Screenshot](/assets/ADF-Pipeline4.png) 
1. In the `Mapping` tab click `import schemas`
    ![Screenshot](/assets/ADF-Pipeline5.png)
1. Define the mapping as follows:
    ```
    msdyn_transactiondate > TransactionDate
    msdyn_activityname > Activity
    msdyn_co2e > CO2E
    ```
    ![Screenshot](/assets/ADF-Pipeline6.png)
1. Click `Debug` and wait for the pipeline to run
    ![Screenshot](/assets/ADF-Pipeline7.png)
1. Click `Publish all` > `Publish` to save the pipeline
    > If you want to run the pipeline again without debugging click `Add trigger` > `Trigger now`
1. Go back to the Azure portal and navigate to the storage account you have previously created
1. Click `Containers` and select the `adf-output` container
    ![Screenshot](/assets/ADF-Pipeline8.png)
1. Open the `mc4s` folder, click on `msdyn_emission.json` and click `Download`
    ![Screenshot](/assets/ADF-Pipeline9.png)
1. Open the json file and confirm you see the three mapped columns from the Emission table in json format
    ![Screenshot](/assets/ADF-Pipeline10.png)