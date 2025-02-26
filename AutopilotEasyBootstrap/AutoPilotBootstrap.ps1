param()

# before the script runs, internet connectivity is tested using this host
$NET_CONNECTIVITY_TARGET = "8.8.8.8"

# the suffix that all users of your organisation share. this is validated when entering the assigned user
$USER_SUFFIX = "contoso.com"

function Main() {
    # prompt to connect network if no connectivity is detected
    while (-not (Test-Connection $NET_CONNECTIVITY_TARGET -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Information "could not validate internet connectivity! Please connect to a network and confirm once you're connected." 
        Start-Process ms-settings:network
        Read-Host "press enter once you're connected to the internet"
    }

    # prepare scripts
    Write-Information "Preparing... Please confirm any prompts with 'yes'"
    Set-ExecutionPolicy -Scope Process Bypass
    Install-Script Get-WindowsAutoPilotInfo -Confirm:$false -Force 

    # gather assignment information
    # first, get the assigned user name
    Write-Information "`n`nnow, you'll have to enter information for device assignment. `nPlease follow the example values given in parentheses carefully. `n"
    $assignedUser = Read-Host -Prompt "Please enter the Assigned User ('someone@$($USER_SUFFIX)')"
    if (-not $assignedUser.EndsWith("@$($USER_SUFFIX)")) {
        if (-not $assignedUser.Contains("@")){
            $assignedUser += "@$($USER_SUFFIX)"
        } else {
            Write-Information "Assigned User does not end in $($USER_SUFFIX), but has a differnt suffix. assuming you know what you're doing."
        }
    }

    # second, choose a group tag for the device
    Write-Information "`n Enter the group tag to assign to the device:"
    $groupTag = Read-Host -Prompt "Group Tag"

    # choose between online and offline (csv) mode
    $onlineMode = Read-Host -Prompt "`n Do you wish to use Get-WindowsAutoPilotInfo in online mode? [yes/NO]"
    $onlineMode = $onlineMode -ieq "yes"
    $modeStr = if ($onlineMode) { "Online" } else { "Offline" }

    # validate the info entered
    Clear-Host
    Write-Information @"

This device will be imported as follows:
Assigned User: $($assignedUser)
Group Tag:     $($groupTag)

Will run Get-WindowsAutoPilotInfo in $($modeStr) mode.

"@
    $infoValidateAnswer = Read-Host -Prompt "Is this information correct? [yes/NO]"
    if ($infoValidateAnswer -ine "yes") {
        Write-Information "aborted by user"
        Exit 0
        return
    }

    # import device into autopilot
    if ($onlineMode) {
        Write-Information "`ncalling Get-WindowsAutoPilotInfo in Online mode"
        Write-Information "please enter your credentials when prompted"
        Get-WindowsAutoPilotInfo.ps1 -Online -Assign -AssignedUser "$assignedUser" -GroupTag "$groupTag" -Reboot
    } else {
        Write-Information "`ncalling Get-WindowsAutoPilotInfo in Offline mode"
        Get-WindowsAutoPilotInfo.ps1 -OutputFile "$PSScriptRoot\autopilot.csv" -Append -AssignedUser "$assignedUser" -GroupTag "$groupTag"
    }
}
$InformationPreference = "Continue"
Start-Transcript -Path "C:/AutoPilotBootstrap.log"
Main
Stop-Transcript
