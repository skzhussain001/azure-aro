
To add required permissions in the token, you need to first copy the Client ID (aka App ID) that you are using in your request to get the Access Token and then navigate to:

Azure Portal > Azure Active Directory > App Registration > All Applications > Search with the ClientID/AppID copied earlier.

In that application Navigate to:

Api Permissions > Add a permission > Microsoft Graph > Delegated permissions > Expand User > Select required permissions as shown below. Once the permissions are added, click on Grant Admin Consent for your_tenant button.

![20210930164053](https://i.imgur.com/bvdUN10.png)

### Links:
* https://docs.microsoft.com/en-us/answers/questions/197819/34insufficient-privileges-to-complete-the-operatio.html
