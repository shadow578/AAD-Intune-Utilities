[Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs", "")]
[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingPlainTextForPassword", "")]
Param()

###################
## Configuration ##
###################
$RSA_PUBLIC_KEY = ""
$REGISTRY_KEYS_PATH = "HKLM:\SOFTWARE\IntuneLAPS"
$LAPS_LAST_CHANGE_KEY = "LastChangeTime"
$LOCAL_ADMIN_NAME = "Administrator"
$GET_LOCAL_ADMIN_DYNAMICALLY = $true
$DO_NOT_RUN_ON_SERVERS = $true
$CHANGE_PASSWORD_INTERVAL = 14
$PASSWORD_CONFIG = @{
    Length       = 12
    Numbers      = 4
    Specials     = 2
    NormalChars  = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    NumberChars  = "0123456789"
    SpecialChars = "!$%&()=}][{@#+"
}

function Write-Log(
    [string] $Message,
    [int] $ID,
    [System.Diagnostics.EventLogEntryType] $Type = [System.Diagnostics.EventLogEntryType]::Information,
    [string] $Source = "IntuneLAPS"
) {
    if ((-not ([System.Diagnostics.EventLog]::Exists("Application"))) -or (-not ([System.Diagnostics.EventLog]::SourceExists($Source)))) {
        New-EventLog -LogName "Application" -Source $Source | Out-Null
    }
    Write-EventLog -LogName "Application" -Source $Source -EntryType $Type -EventId $ID -Message $Message | Out-Null
}

function Exit-WithResult($Data, [int] $Code) {
    Write-Log -ID 10999 -Message "exit with code $Code `n$($Data | ConvertTo-Json)"
    Write-Host ($Data | ConvertTo-Json -Compress)
    Exit $Code
}

function Test-RunningOnServerOs() {
    $isOnServer = $false

    # detect using Get-ComputerInfo
    try {
        $isOnServer = $isOnServer -or ((Get-ComputerInfo).OsProductType -ine "workstation")
    }
    catch {
        Write-Log -ID 20091 -Message ($_ | Out-String) -Type Error
    }

    # skip fallback if first check determined we are running on a server
    if ($isOnServer) {
        return $isOnServer
    }

    # detect using CimInstance (fallback)
    try {
        $isOnServer = $isOnServer -or ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1)
    }
    catch {
        Write-Log -ID 20092 -Message ($_ | Out-String) -Type Error
    }
    return $isOnServer
}

function Get-RandomString([int] $Count, [string] $Characters) {
    return (1..$Count | ForEach-Object {
            $Characters[(Get-Random -Minimum 0 -Maximum ($Characters.Length))]
        }) -join ""
}

function Get-RandomPassword() {
    # build base password
    $p = Get-RandomString -Count ($PASSWORD_CONFIG.Length - $PASSWORD_CONFIG.Numbers - $PASSWORD_CONFIG.Specials) -Characters $PASSWORD_CONFIG.NormalChars
    $p += Get-RandomString -Count $PASSWORD_CONFIG.Numbers -Characters $PASSWORD_CONFIG.NumberChars
    $p += Get-RandomString -Count $PASSWORD_CONFIG.Specials -Characters $PASSWORD_CONFIG.SpecialChars

    # scramble password
    # do not allow the password to start with a special char or number
    do {
        $p = -join ($p.ToCharArray() | Get-Random -Count $p.Length)
    } while ($PASSWORD_CONFIG.NormalChars.ToCharArray() -notcontains $p[0])
    return $p
}

function Encrypt-Password([string] $PasswordString) {
    # initialize RSA provider
    $RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
    $RSA.ImportCspBlob([System.Convert]::FromBase64String($RSA_PUBLIC_KEY))

    # convert password to bytes using UTF8, encrypt with the public key, and convert the result to base64
    $data = $RSA.Encrypt([System.Text.Encoding]::UTF8.GetBytes($PasswordString), $false)
    return [System.Convert]::ToBase64String($data);
}

function Get-LocalAdminAccount() {
    # get local admin dynamically
    $adminAccount = $null
    try {
        if ($GET_LOCAL_ADMIN_DYNAMICALLY) {
            $adminAccount = (Get-LocalUser | Where-Object { $_.SID -like "S-1-5-*-500" })
        }
    }
    catch {
        Write-Log -ID 10021 -Message ($_ | Out-String) -Type Error
        $adminAccount = $null
    }
    
    # fallback to getting account by name
    if (-not $adminAccount) {
        $adminAccount = Get-LocalUser -Name $LOCAL_ADMIN_NAME
    }

    # fail if we still dont have a account
    if (-not $adminAccount) {
        throw "could not find the local administrator account. `n GET_LOCAL_ADMIN_DYNAMICALLY = $GET_LOCAL_ADMIN_DYNAMICALLY `n LOCAL_ADMIN_NAME = $LOCAL_ADMIN_NAME"
    }

    return $adminAccount
}

function ShouldChangePassword() {
    # get time of last password change from registry entry
    $lastChangeProp = Get-ItemProperty -Path $REGISTRY_KEYS_PATH -Name $LAPS_LAST_CHANGE_KEY
    
    # if last change key is not set, this is the first run
    # on the first run, we change the password
    if (-not $lastChangeProp) {
        Write-Log -ID 10031 -Message "did not find key $($REGISTRY_KEYS_PATH)\$($LAPS_LAST_CHANGE_KEY) `nthis is probably the first run, requesting password change"
        return $true
    }
    
    # parse last change time
    # if parsing fails, log the error and force a password change
    $lastChangeStr = $lastChangeProp.$LAPS_LAST_CHANGE_KEY
    $lastChange = $null
    try {
        $lastChange = [datetime]::ParseExact($lastChangeStr, "yyyy-MM-ddTHH:mm:ss", $null)
    }
    catch {
        Write-Log -ID 10039 -Message "$($_ | Out-String)" -Type Error
        return $true
    }
    
    # get time since the last password change
    $now = Get-Date
    $timeSince = $now - $lastChange
    $timeSinceDays = [System.Math]::Floor($timeSince.TotalDays)
        
    # if time since last change is more than N days, change password
    Write-Log -ID 10032 -Message "password was last changed on $($lastChange.ToString()) ($timeSinceDays) days ago)"
    if (($timeSinceDays -gt $CHANGE_PASSWORD_INTERVAL) -or ($timeSinceDays -lt 0)) {
        Write-Log -ID 10033 -Message "last password change was $timeSinceDays days ago, request password change"
        return $true
    }
    
    # password is ok
    return $false
}

function PerformPasswordChange($AdminAccount) {
    $now = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    $hostname = $env:COMPUTERNAME
    
    # generate new password
    $pwdPlainText = Get-RandomPassword
    $pwdSecure = ConvertTo-SecureString -String $pwdPlainText -AsPlainText -Force
    $pwdEncrypted = Encrypt-Password -PasswordString $pwdPlainText
    $pwdPlainText = $null
    
    # write password to event log
    # we do this first in case something in the script fails. Otherwise, we might lock ourself out
    # password in eventlog is not a problem since it is encrypted. 
    # You can disable this tho
    Write-Log -ID 10041 -Message "the password for $($AdminAccount.Name) on $hostname was changed to '$($pwdEncrypted)'"
    
    # enable and update the local administrator account
    $AdminAccount | Enable-LocalUser
    $AdminAccount | Set-LocalUser -Password $pwdSecure -AccountNeverExpires -PasswordNeverExpires $true
 
    # write password change time to registry
    New-Item -Path $REGISTRY_KEYS_PATH -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $REGISTRY_KEYS_PATH -Name $LAPS_LAST_CHANGE_KEY -Value $now

    # exit with change information
    Exit-WithResult -Code 1 -Data @{
        account_name        = ($AdminAccount.Name)
        computer_name       = $hostname
        password            = $pwdEncrypted
        changed_at          = $now
        did_change_password = $true
    }
}

function Main() {
    try {
        Write-Log -ID 10011 -Message "IntuneLAPS running"

        # stop if on a server
        if ($DO_NOT_RUN_ON_SERVERS) {
            if (Test-RunningOnServerOs) {
                Write-Log -ID 10012 -Message "You are running this script on a server, but DO_NOT_RUN_ON_SERVERS is set! `nscript execution was stopped, and nothing was changed.`nplease adjust your configuration to not run this script on a server, or disable DO_NOT_RUN_ON_SERVERS" -Type Error
                Exit-WithResult -Code 2 -Data @{
                    error = "you are running this script on a server, but DO_NOT_RUN_ON_SERVERS is set"
                }
            }
        }

        # ensure public key is set
        if ([string]::IsNullOrWhiteSpace($RSA_PUBLIC_KEY)) {
            throw "RSA_PUBLIC_KEY is not set"
        }

        # get local administrator, stop if not found
        $localAdmin = Get-LocalAdminAccount

        # check if we should change the password
        if (ShouldChangePassword) {
            Write-Log -ID 10013 -Message "changing the password of $($localAdmin.Name)"
            PerformPasswordChange -AdminAccount $localAdmin
        }
        else {
            Exit-WithResult -Code 0 -Data @{
                account_name        = ($localAdmin.Name)
                computer_name       = ($env:COMPUTERNAME)
                did_change_password = $false
            }
        }
    }
    catch {
        Write-Log -ID 10019 -Message "$($_ | Out-String)" -Type Error
        Exit-WithResult -Code 1 -Data @{
            computer_name       = ($env:COMPUTERNAME)
            did_change_password = $false
            error               = $true
        }
    } 
}
Main | Out-Null
