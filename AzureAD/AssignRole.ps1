<#
.SYNOPSIS
Gives a custom role on a App Registration in Azure AD to a Managed Service Identity.

.Description
In Azure AD an application can register any number of custom roles that a user or client application can be assigned for that particular application. 
These roles will then be reflected under a "roles" claim when the user or client application fetches a OAuth2 token from Azure AD. 
This script simplifies the process of giving these custom roles to a Managed Service Identity, which is autogenerated internal identities you can get 
on many services in Azure now. 

Remember to run "Connect-AzureAD" before this script

.PARAMETER resourceApplicationName
Name (or start of a name) that can give one search result in your Azure AD for the Application that owns the custom role.

.PARAMETER roleName
Full name of the custom role you want to assign.

.PARAMETER msiServicePrincipalName
Name (or start of a name) that can give one search result in your Azure AD for the Managed Service Identity that is the client. 

.EXAMPLE
.\AssignRole.ps1 -msi "MyMSIClient1" -resource "MyAwesomeApiApp" -role "Account.Read"
.\AssignRole.ps1 -msi "MyMSIClient1" -resource "MyAwesomeApiApp" -role "Admin"
#>
param(
    [parameter(mandatory = $true)][string] $resourceApplicationName, 
    [parameter(mandatory = $true)][string] $roleName,
    [parameter(mandatory = $true)][string] $msiServicePrincipalName
)

# get application registration
Write-Host "Searching for Role named '$roleName' on application registration '$resourceApplicationName'"
$applications = Get-AzureADApplication -SearchString $resourceApplicationName

if ($applications.count -ne 1) {
    throw "Could not find only one application from your search string"
}

$roleId = $null

foreach ($role in $applications.AppRoles) {
    if ($role.Value -eq $roleName) {
        $roleId = $role.Id
        Write-Host "Found role id $roleId"
        break
    }
}

if ($role -eq $null) {
    throw "Could not find the role specified."
}

# get application app registration
Write-Host "Searching for app registration for application named '$resourceApplicationName'"
$appSP = Get-AzureADServicePrincipal -SearchString $resourceApplicationName | Where-Object {$_.ServicePrincipalType -eq "Application"}

if ($appSP.count -ne 1) {
    $count = $appSp.count
    throw "Could not find application service principal. Number of SP found: $count"
}

$resourceId = $appSP.ObjectId
Write-Host "Found app service id $resourceId"

# get msi service principal registration
Write-Host "Searching for service principal registration for msi user named '$msiServicePrincipalName'"
$msiSP = Get-AzureADServicePrincipal -SearchString $msiServicePrincipalName | Where-Object {$_.ServicePrincipalType -eq "ManagedIdentity"}

if ($msiSp.count -ne 1) {
    throw "Could not find msi service principal."
}

$msiPrincipalId = $msiSP.ObjectId
Write-Host "Found msi service id $msiPrincipalId"

# add new role
# Note: This command will fail 90% of the times, but still do everything correct. 
#       It's a problem with the api, and thats why the assignment is checked further down for actuall failure to add role. 
try {
    New-AzureADServiceAppRoleAssignment -ObjectId $msiPrincipalId -PrincipalId $msiPrincipalId -ResourceId $resourceId -Id $roleId
}
catch {
    # ignore
}

$assignments = Get-AzureADServiceAppRoleAssignedTo -ObjectId $msiPrincipalId 

if (-not $assignments.Id -contains $roleId) {
    throw "Doesn't seem like the msi service principal got the role assigned to itself."
}
else {
    Write-Host "Found role on msi sp after assign."
}