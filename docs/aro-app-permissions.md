# Pipeline Permission requirements 

### Add the Application administrator to the pipeline service account
You will also need sufficient Azure Active Directory permissions (either a member user of the tenant, or a guest user assigned with role **Application administrator**) for the tooling to create an application and service principal on your behalf for the cluster. See Member and guest users and Assign administrator and non-administrator roles to users with Azure Active Directory for more details.

![20211005133838](https://i.imgur.com/Ishg5La.png)

### Add the api permissions to the pipeline service account 
To add required permissions in the token, you need to first copy the Client ID (aka App ID) that you are using in your request to get the Access Token and then navigate to:

> Azure Portal > Azure Active Directory > App Registration > All Applications > Search with the ClientID/AppID copied earlier.

In that application Navigate to:

> Api Permissions > Add a permission > Microsoft Graph > Delegated permissions > Expand User > Select required permissions as shown below. Once the permissions are added, click on Grant Admin Consent for your_tenant button.
![20211004131658](https://i.imgur.com/fXiMo7j.png)
![20210930164053](https://i.imgur.com/bvdUN10.png)
![20211004101214](https://i.imgur.com/ZewBVap.png)

### Increase the Quota count for the deployment 

Azure Red Hat OpenShift requires a minimum of 40 cores to create and run an OpenShift cluster. The default Azure resource quota for a new Azure subscription does not meet this requirement. To request an increase in your resource limit.

Standard quota: Increase limits by VM series - https://docs.microsoft.com/en-us/azure/azure-portal/supportability/per-vm-quota-requests

### Links:
* https://docs.microsoft.com/en-us/answers/questions/197819/34insufficient-privileges-to-complete-the-operatio.html
* [How can I grant roleAssignement/write permission to azure devops service connection](https://stackoverflow.com/questions/55593312/how-can-i-grant-roleassignement-write-permission-to-azure-devops-service-connect)
* https://github.com/ocpdude/aro-install/blob/main/README.md
