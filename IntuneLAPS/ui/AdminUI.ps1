[Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs", "")]
[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingPlainTextForPassword", "")]
[CmdletBinding()]
param (
    <#
    call the adminui with this parameter set to a encrypted password to only decrypt it
    #>
    [Parameter()]
    [string]
    $DecryptPassword = $null
)

$LAPS_REMEDIATION_SCRIPT_ID = ""
$CHANGE_PASSWORD_INTERVAL = 14
$GRAPH_API_BASE_URL = "https://graph.microsoft.com/beta"
$RSA_PRIVATE_KEY = (Get-Content -Path "$PSScriptRoot\private.key" -First 1).Trim()

function Initialize-MSGraph() {
    # load the module
    try {
        Import-Module Microsoft.Graph.InTune
    }
    catch {
        Write-Host @"
failed to import module 'Microsoft.Graph.InTune'. 
Please install it by running the following command in a admin shell:
   Install-Module Microsoft.Graph.InTune -Force

"@ -ForegroundColor Red
        Exit 1        
    }

    # login
    Write-Host "$(Render-TextUIBox -Content @(
        "Login into MS Graph"
        "If prompted, please login with your credentials"
        "and allow access"
    ))"
    $login = Connect-MSGraph
    if (-not $login) {
        Write-Host "login failed" -ForegroundColor Red
        Exit 1
    }

    Write-Host "Logged in as $($login.UPN)"
}

function Get-LAPSDeviceInfo([string] $DeviceName) {
    try {
        # send request to graph
        # the request filters out all the runs where the password didn't change, and only returns the ones where the password was changed
        Write-Debug "query LAPS info for $DeviceName with SCRIPT_ID $LAPS_REMEDIATION_SCRIPT_ID"
        Write-Host "waiting for response..."
        $uri = "$GRAPH_API_BASE_URL/deviceManagement/deviceHealthScripts/$LAPS_REMEDIATION_SCRIPT_ID/deviceRunStates?`$expand=managedDevice(`$select=deviceName,operatingSystem,osVersion,emailAddress)&`$filter=(detectionState eq 'fail') and (managedDevice/deviceName eq '$DeviceName')&`$select=preRemediationDetectionScriptOutput"
        $response = Invoke-MSGraphRequest -Url ([uri]::EscapeUriString($uri)) -HttpMethod GET

        # there must be a response
        if (-not $response) {
            throw "response was empty"
        }

        # there must be at least one response item
        $itms = @($response.Value)
        if ($itms.Length -le 0) {
            throw "response had no items"
        }

        # parse items into a nicer format
        $r = @()
        foreach ($itm in $itms) {
            try {
                $r += [PSCustomObject] @{
                    # get intune MDM device info
                    managedDevice = $itm.managedDevice
                
                    # get remediation output and parse json
                    lapsInfo      = ($itm.preRemediationDetectionScriptOutput | ConvertFrom-Json)
                }
            }
            catch {
                Write-Host "Error for $($DeviceName): $_" -ForegroundColor Red  
                Write-Error ($_ | Out-String) -ErrorAction $DebugPreference
            }
        }

        return $r
    }
    catch {
        Write-Error ($_ | Out-String) -ErrorAction $DebugPreference        
        return @()  
    }
}

function Print-LAPSDeviceInfo([Object] $Item) {
    # parse change date
    $changedAt = "N/A"
    $nextChange = "N/A"
    $nextChangeInDays = 0
    try {
        $changeDate = [datetime]::ParseExact($Item.lapsInfo.changed_at, "yyyy-MM-ddTHH:mm:ss", $null)
        if ($null -ne $changeDate) {
            $nextChangeDate = $changeDate.AddDays($CHANGE_PASSWORD_INTERVAL)
            $changedAt = $changeDate.ToString()
            $nextChange = $nextChangeDate.ToString()
            $nextChangeInDays = [Math]::Floor(($nextChangeDate - (Get-Date)).TotalDays)
        }
    }
    catch {
        Write-Error ($_ | Out-String) -ErrorAction $DebugPreference        
    }

    # print info
    Write-Host @"

$(Render-TextUIBox -Content $(
    "Information for $($Item.managedDevice.deviceName)",
    "($($Item.managedDevice.emailAddress))"
))

Administrator Name     : $($Item.lapsInfo.account_name)
Administrator Password : $($Item.lapsInfo.password | Decrypt-Password) 
Last Changed On        : $($changedAt)
Next Change On         : $($nextChange) (in $nextChangeInDays days)
"@

    # check if MDM device name and LAPS device name match
    if ($Item.managedDevice.deviceName -ine $Item.lapsInfo.computer_name) {
        Write-Host "Name in MDM does not match LAPS name! MDM= $($Item.managedDevice.deviceName); LAPS= $($Item.lapsInfo.computer_name)" -ForegroundColor Red
    }
}

function Decrypt-Password([Parameter(ValueFromPipeline)] $EncryptedPasswordString) {
    # initialize RSA provider
    $RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
    $RSA.ImportCspBlob([System.Convert]::FromBase64String($RSA_PRIVATE_KEY))
    
    # convert encrypted string to bytes using Base64, decrypt with private key, and convert the result to UTF8 string
    $data = $RSA.Decrypt([Convert]::FromBase64String($EncryptedPasswordString), $false)
    return [System.Text.Encoding]::UTF8.GetString($data)
}

function Render-TextUIBox([string[]] $Content) {
    # find the longest line
    $maxLineLength = ($Content | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

    # render first / last line
    $firstLine = "+-$("-" * $maxLineLength)-+"

    # init box render target
    $render = @()
    $render += $firstLine

    # render content with box prefix and suffix
    $Content | ForEach-Object {
        $d = [Math]::Floor(($maxLineLength - $_.Length) / 2)
        $e = [Math]::Floor($maxLineLength - $_.Length - $d)
        $render += "| $(" " * $d)$($_)$(" " * $e) |"
    }

    # draw last line
    $render += $firstLine
    return ($render -join "`n")
}

function InteractiveMain() {
    # login
    Initialize-MSGraph

    # REPL loop
    while ($true) {
        # get info for device
        Write-Host @"

Enter intune device name to query admin password, or press CTRL+C to exit
"@
        $deviceName = Read-Host -Prompt "Device Name"

        # abort if empty response
        $lapsInfos = @(Get-LAPSDeviceInfo -DeviceName $deviceName)
        if ($lapsInfos.Length -le 0) {
            Write-Host "did not find any information for $deviceName" -ForegroundColor Red
            continue
        }

        # find the latest entry where the password was changed
        $latestLapsInfo = $lapsInfos | Where-Object { $true -eq $_.lapsInfo.did_change_password } | Sort-Object { $_.lapsInfo.changed_at } -Descending | Select-Object -First 1

        # print that entry
        Print-LAPSDeviceInfo -Item $latestLapsInfo
    }
}

function Main() {
    if ([string]::IsNullOrWhiteSpace($DecryptPassword)) {
        InteractiveMain
    }
    else {
        Write-Output ($DecryptPassword | Decrypt-Password)
    }
}
$DebugPreference = "SilentlyContinue"
Main
