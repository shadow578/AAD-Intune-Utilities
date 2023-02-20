#
# Configuration
#
$TeamViewerApiToken = "<TeamViewer API Token>"
$MSAutomationAccountName = "<Microsoft Automation Account Credential>"
$GraphApiClientId = "<Microsoft Graph API Client ID>"
$DeviceNamingPattern = '\[(.+)\]' 

<#
.SYNOPSIS
Use this function to obtain a auth token for the Graph REST API
Based on the example provided by Microsoft at https://github.com/microsoftgraph/powershell-intune-samples/blob/master/Authentication/Auth_From_File.ps1

.EXAMPLE
$Credential = Get-Credential
$ClientId = 'f338765e-1cg71-427c-a14a-f3d542442dd'
$AuthToken = Get-MSGraphAuthenticationToken -Credential $Credential -ClientId $ClientId

.EXAMPLE
$ClientId = 'f338765e-1cg71-427c-a14a-f3d542442dd'
$AuthToken = Get-MSGraphAuthenticationToken -ClientId $ClientId -Tenant domain.onmicrosoft.com 
#>
function Get-MSGraphAuthenticationToken(
    [Parameter(Mandatory = $true, ParameterSetName = 'PSCredential')]
    [PSCredential] $Credential,
    [Parameter(Mandatory = $true)]
    [String]$ClientId,
    [Parameter(Mandatory = $true, ParameterSetName = 'ADAL')]
    [String]$TenantId
) {
    # load AAD module
    try {
        Write-Verbose 'Importing prerequisite modules...'
        $AadModule = Import-Module -Name AzureAD -ErrorAction Stop -PassThru
    }
    catch {
        throw 'Prerequisites not installed (AzureAD PowerShell module not installed'
    }

    switch ($PsCmdlet.ParameterSetName) { 
        'ADAL' { $tenant = $TenantId } 
        'PSCredential' {
            $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $Credential.Username        
            $tenant = $userUpn.Host
        }
    }

    # get paths to ActiveDirectory assemblies and load them
    $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null


    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"
      
    try {
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
      
        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
            $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($Credential.Username, "OptionalDisplayableId")
            $userCredentials = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential -ArgumentList $Credential.Username, $Credential.Password
            $authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, $resourceAppIdURI, $clientid, $userCredentials);

            if ($authResult.Result.AccessToken) {
                # Creating header for Authorization token
                $authHeader = @{
                    'Content-Type'  = 'application/json'
                    'Authorization' = "Bearer " + $authResult.Result.AccessToken
                    'ExpiresOn'     = $authResult.Result.ExpiresOn
                }

                return $authHeader
            }
            elseif ($authResult.Exception) {
                throw "An error occured getting access token: $($authResult.Exception.InnerException)"
            }
        }
        else {
            $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Always"
            $authResult = ($authContext.AcquireTokenAsync($resourceAppIdURI, $ClientID, $RedirectUri, $platformParameters)).Result

            if ($authResult.AccessToken) {                
                # Creating header for Authorization token
                $authHeader = @{
                    'Content-Type'  = 'application/json'
                    'Authorization' = "Bearer " + $authResult.AccessToken
                    'ExpiresOn'     = $authResult.ExpiresOn
                }

                return $authHeader
            }
        }
    }
    catch {
        throw $_.Exception.Message
    }
}

<#
.SYNOPSIS
Download teamviewer device list
#>
function Get-TVDevice() {
    $ContentType = 'application/json; charset=utf-8'
    $Uri = 'https://webapi.teamviewer.com/api/v1/devices/'
            
    Write-Verbose -Message "[GET] RestMethod: [$Uri]"                        
    $Result = Invoke-RestMethod -Method Get -Uri $Uri -Headers $header -ContentType $ContentType -ErrorVariable TVError -ErrorAction SilentlyContinue
             
    if ($TVError) {
        $JsonError = $TVError.Message | ConvertFrom-Json
        $HttpResponse = $TVError.ErrorRecord.Exception.Response
        Throw "Error: $($JsonError.error) `nDescription: $($JsonError.error_description) `nErrorCode: $($JsonError.error_code) `nHttp Status Code: $($HttpResponse.StatusCode.value__) `nHttp Description: $($HttpResponse.StatusDescription)"
    }
    else {
        Write-Verbose -Message "Setting Device List to variable for use by other commands."
    }

    return $Result.devices
}

<#
.SYNOPSIS
rename teamviewer device
#>
function Rename-TVDevice(
    [string]$DeviceID,
    [string]$NewAlias
) {
    $ReqURI = 'https://webapi.teamviewer.com/api/v1/devices/' + $DeviceID
    $Jsonbody = @{
        'alias' = $NewAlias
    } | ConvertTo-Json

    try {
        $Response = Invoke-RestMethod -Header $header -Method PUT -ContentType 'application/json' -Uri $ReqURI -Body $Jsonbody -Verbose | Format-List *
        return $true
    }
    Catch {
        return "$_"
    }
}

<#
.SYNOPSIS
get intune primary user for a device
#>
function Get-IntuneDevicePrimaryUser(
    [parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()] 
    [string]$DeviceName
) {
    $graphApiVersion = "beta"
    $Ressource = "deviceManagement/managedDevices"
    $IntuneDeviceID = ($AllIntuneDevices | Where-Object { $_.devicename -eq $DeviceName } | Sort-Object -Descending -Property enrolledDateTime | select-object -First 1).id

    $uri = "https://graph.microsoft.com/$graphApiVersion/$Ressource/$IntuneDeviceID/users"
    $GraphToken = Get-MSGraphAuthenticationToken -Credential $creds -ClientId $GraphApiClientId
    $PrimaryUserID = (Invoke-RestMethod -Uri $uri -Headers $GraphToken -Method Get).value.id

    return (Get-AzureADUser -ObjectID $PrimaryUserID).displayname
}


function Main() {
    Import-Module -Name Microsoft.Graph.Intune
    Import-Module -Name AzureAD

    # get ms automation credentials
    try {
        $creds = Get-AutomationPSCredential -Name $MSAutomationAccountName
        Write-Output -inputobject "Got account creds for: [$MSAutomationAccountName]"
    }
    Catch {
        Write-Error -Message "Could not get creds for account: [$MSAutomationAccountName] $_"
        return
    }

    # connect to the ms-graph and aad api
    Connect-MSGraph -PSCredential $creds -ErrorAction Stop
    Connect-AzureAD -Credential $creds -ErrorAction Stop

    # authentificate teamviewer api
    $bearer = "Bearer", $TeamViewerApiToken
    $header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $header.Add("authorization", $bearer)

    # query all teamviewer devices
    $AllTVDevices = Get-TVDevice
    Write-Output -InputObject "[$($AllTVDevices.Count)] devices retrieved from Teamviewer API"

    # query all intune devices
    $AllIntuneDevices = Get-IntuneManagedDevice -ErrorAction Stop
    Write-Output -InputObject "[$($AllIntuneDevices.Count)] devices retrieved from Intune API"

    if ($AllIntuneDevices.Count -gt 0) {
        Write-Output -InputObject "[$($AllIntuneDevices.Count)] devices retrieved from Intune API"
        foreach ($TVDevice in $AllTVDevices) {
            $NewAlias = $null
            $Alias = $TVDevice.alias
            $DeviceID = $TVDevice.device_id
        
            Write-Output -InputObject "`nGetting Intune primary user for TV Device: [$Alias]...."
            If ($Alias -match $DeviceNamingPattern) {
                $TVDeviceName = $Alias.split(' ')[0]
            }
            else {
                $TVDeviceName = $Alias
            }

            # skip all devices not found in intune
            if (($AllIntuneDevices | Where-Object { $_.devicename -eq $TVDeviceName }).Count -eq 0) {
                Write-output "skip device $TVDeviceName bc not in intune"
                continue
            }

            $PrimaryUser = Get-IntuneDevicePrimaryUser -DeviceName $TVDeviceName
            If ($PrimaryUser) {
                Write-Information -MessageData "Primary user for device: [$TVDeviceName] retrieved: [$PrimaryUser]"
            
                If ($Alias -match $DeviceNamingPattern) {
                    $CurrentAssignedUser = $Matches[1]
                    write-output -InputObject "[$Alias] is currently assigned to: [$CurrentAssignedUser]. Will check if this is correct..."
                    If ($CurrentAssignedUser -eq $PrimaryUser) {
                        write-output -InputObject "[$Alias] is set correctly."
                    }
                    else {
                        write-output -InputObject "[$Alias] needs updating with: [$PrimaryUser]."
                        $NewAlias = $Alias -replace $CurrentAssignedUser, $PrimaryUser
                    }
                }
                else {
                    write-output -InputObject "No username in device alias. Will modify TV device alias to include a username...."
                    $NewAlias = $Alias + " [$PrimaryUser]"
                }

                # rename the device
                If ($NewAlias) {
                    write-output -InputObject "New alias specified: [$NewAlias]. Will now update in Teamviewer."
                    write-output -InputObject "Updating DeviceID: [$DeviceID]"
                    Try {
                        Rename-TVDevice -DeviceID $DeviceID -NewAlias $NewAlias
                        Write-Information -MessageData "Succesfully updated [$Alias] to [$NewAlias]"
                    }
                    Catch {
                        write-error -Message "Failed to rename device [$Alias]. $_"
                    }
                }
                else {
                    write-warning -Message "No new alias defined. Moving to next device."
                }
            }
            else {
                write-warning -Message "Could not retrieve Intune primary user for device: [$Alias]"
            }
        }
    }
    else {
        write-error -Message "Couldn't retrieve any devices from Intune. $_"
    }
}
Main
