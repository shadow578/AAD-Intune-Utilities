param()

# before the script runs, internet connectivity is tested using this host
$NET_CONNECTIVITY_TARGET = "8.8.8.8"

# the suffix that all users of your organisation share. this is validated when entering the assigned user
$USER_SUFFIX = "contoso.com"

# group tags that are used in your organisation
$GROUP_TAGS = @(
    "AP-Notebooks",
    "AP-PersonalComputers"
)

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
        $assignedUser += "@$($USER_SUFFIX)"
    }

    # second, choose a group tag for the device
    Write-Information "`n Available Group Tags:"
    for ($i = 0; $i -lt $GROUP_TAGS.Count; $i++) {
        Write-Information " $($i+1) : $($GROUP_TAGS[$i])"
    }
    $groupTagIndex = Read-Host -Prompt "Please enter the group tag id (1 - $($GROUP_TAGS.Count))"
    $groupTag = $GROUP_TAGS[$groupTagIndex - 1]

    # validate the info entered
    Clear-Host
    Write-Information @"

This device will be imported as follows:
Assigned User: $($assignedUser)
Group Tag:     $($groupTag)

"@
    $infoValidateAnswer = Read-Host -Prompt "Is this information correct? [yes/NO]"
    if ($infoValidateAnswer -ine "yes") {
        Write-Information "aborted by user"
        Exit 0
        return
    }

    # import device into autopilot
    Write-Information "`ncalling Get-WindowsAutoPilotInfo with -Online"
    Write-Information "please enter your credentials when prompted"
    Get-WindowsAutoPilotInfo.ps1 -Online -Assign -AssignedUser "$assignedUser" -GroupTag "$groupTag" -Reboot
}
$InformationPreference = "Continue"
Start-Transcript -Path "C:/AutoPilotBootstrap.log"
Main
Stop-Transcript
