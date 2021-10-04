
To add required permissions in the token, you need to first copy the Client ID (aka App ID) that you are using in your request to get the Access Token and then navigate to:

> Azure Portal > Azure Active Directory > App Registration > All Applications > Search with the ClientID/AppID copied earlier.

In that application Navigate to:

> Api Permissions > Add a permission > Microsoft Graph > Delegated permissions > Expand User > Select required permissions as shown below. Once the permissions are added, click on Grant Admin Consent for your_tenant button.
![20211004131658](https://i.imgur.com/fXiMo7j.png)
![20210930164053](https://i.imgur.com/bvdUN10.png)
![20211004101214](https://i.imgur.com/ZewBVap.png)

[How can I grant roleAssignement/write permission to azure devops service connection](https://stackoverflow.com/questions/55593312/how-can-i-grant-roleassignement-write-permission-to-azure-devops-service-connect)
```
$role = Get-AzRoleDefinition "Virtual Machine Contributor"
$role.Id = $null
$role.Name = "Assign permissions role"
$role.Description = "Allow to assign permissions"
$role.Actions.Clear()
$role.Actions.Add("Microsoft.Authorization/roleAssignments/write")
$role.AssignableScopes.Clear()

Get-AzSubscription | ForEach-Object {
    $scope = "/subscriptions/{0}" -f $_.Id
    $role.AssignableScopes.Add($scope)
}
$def = New-AzRoleDefinition -Role $role
```

Virtual Machine Contributor

### Links:
* https://docs.microsoft.com/en-us/answers/questions/197819/34insufficient-privileges-to-complete-the-operatio.html

