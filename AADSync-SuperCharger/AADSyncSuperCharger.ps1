param()

$CONFIG = @{
    # OUs you'd like to monitor for users or computers to sync
    monitor_targets                = @(
        "OU=Autopilot-Clients,DC=contoso,DC=com",
        "OU=Users,DC=contoso,DC=com"
    )
    # for computer objects: maximum time delta between creation and modification
    # basically, this controls how long computers have time to write userCertificate (AAD enrollment)
    computer_max_creation_delta    = (5 * 60 * 60)

    # for computer objects: the identity of a group that all computers will be assigned to before getting synced
    # if you don't want to assign a group, set this value to null
    #computer_assign_group_identity = $null
    computer_assign_group_identity = "AADSC-AutoAssignedGroup"
}

$LAST_RUN_INFO_PATH = "$PSScriptRoot\last-run.json"

function Write-LogEntry(
    [string] $Message,
    [int] $ID,
    [System.Diagnostics.EventLogEntryType] $Type = [System.Diagnostics.EventLogEntryType]::Information,
    [string] $SourceName = "AADSuperCharger"
) {
    try {
        Write-EventLog -LogName "Application" -Source $SourceName -EntryType $Type -EventId $ID -Message $Message | Out-Null   
    }
    catch {}
}

function Get-LastRunInfo() {
    # ensure last run info exists
    if (Test-Path -Path $LAST_RUN_INFO_PATH) {
        # read last run
        $lri = Get-Content -Path $LAST_RUN_INFO_PATH | ConvertFrom-Json

        # ensure all values are present
        if ($null -ne $lri.time) {
            return $lri
        }    
    }

    # either last run does not exist or is invalid
    # fallback to a default last run
    return [PSCustomObject]@{
        time = [DateTime]::Now.AddMinutes(-10)
    }
}

function Main() {
    try {
        Import-Module ActiveDirectory
    }
    catch {
        Write-Error "load ActiveDirectory module failed: $($_ | Out-String)"
        Write-LogEntry -Message "load ActiveDirectory module failed: $($_ | Out-String)" -ID 500 -Type Error
        Exit 500
        return
    }

    # get last run info
    $lastrun = Get-LastRunInfo
    $lastrunTime = $lastrun.time.ToLocalTime()

    # figure out what users and computers should be synced
    $usersForSync = @()
    $computersForSync = @()
    foreach ($target in $CONFIG.monitor_targets) {
        try {
            # get new users in the target OU
            $usersForSync += @( Get-ADUser -Filter 'Created -ge $lastrunTime' -SearchBase $target -Properties UserPrincipalName, Created )

            # get modified computers in target OUs
            foreach ($computer in @( Get-ADComputer -Filter 'Modified -ge $lastrunTime' -SearchBase $target -Properties SamAccountName, Created, Modified, userCertificate )) {
                $deltaSinceCreation = $computer.Modified.Subtract($computer.Created)
                if (($deltaSinceCreation.TotalSeconds -le $CONFIG.computer_max_creation_delta) -and
                (!!$computer.userCertificate)) {
                    # this computer has a userCertificate and the delta since creation is NOT too large
                    # so we should sync it now
                    $computersForSync += $computer
                } 
            }
        }
        catch {
            Write-Error "error during fetch of ou $($target): $($_ | Out-String)"
            Write-LogEntry -Message "error during fetch of ou $($target): $($_ | Out-String)" -ID 503 -Type Error
            Exit 503
            return
        }


    }

    if ($true) {
        # write information about sync targets to log
        $syncLogMsg = @"
After scanning $($CONFIG.monitor_targets.Length) targets, got $($usersForSync.Length) users and $($computersForSync.Length) computers for sync:

monitor_targets = $($CONFIG.monitor_targets | ConvertTo-Json)
usersForSync = $($usersForSync | ConvertTo-Json)
computersForSync = $($computersForSync | ConvertTo-Json)
"@
        Write-Information $syncLogMsg
        Write-LogEntry -Message $syncLogMsg -ID 201 -Type Information
    }
    
    # add all computers to the group in config
    try {
        if (($null -ne $CONFIG.computer_assign_group_identity) -and
            ($null -ne $computersForSync) -and
            (0 -ne $computersForSync.Length)) {
            $targetGroup = Get-ADGroup -Identity "$($CONFIG.computer_assign_group_identity)"
            if ($null -ne $targetGroup) {
                Add-ADGroupMember -Identity $targetGroup -Members $computersForSync
            }
        }
    }
    catch {
        Write-Error "failed to assign computer group $($CONFIG.computer_assign_group_identity): $($_ | Out-String)"
        Write-LogEntry -Message "failed to assign computer group $($CONFIG.computer_assign_group_identity): $($_ | Out-String)" -ID 504 -Type Error
        Exit 504
        return
    }


    # wait a sec before sync to allow for replication across multiple DCs
    Write-Information "waiting 30 seconds for replication..."
    Start-Sleep -Seconds 30

    # if there are objects to sync, sync them
    # fail script if sync call fails
    if (($usersForSync.Length -gt 0) -or ($computersForSync -gt 0)) {
        try {
            Write-Information "starting AADSync SyncCycle in Delta mode"
            Write-LogEntry -Message "starting AADSync SyncCycle in Delta mode" -ID 202 -Type Information
            Start-ADSyncSyncCycle -PolicyType Delta
        }
        catch {
            Write-Error "error during AADSync SyncCyle: $($_ | Out-String)"
            Write-LogEntry -Message "error during AADSync SyncCyle: $($_ | Out-String)" -ID 505 -Type Error
            Exit 505
            return
        }
    }

    # ensure directory for lri does exist
    New-Item -Path ([System.IO.Path]::GetDirectoryName($LAST_RUN_INFO_PATH)) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    # write last run info
    $currentRunInfo = @{
        time = [DateTime]::Now.Add(-1)
    }
    $currentRunInfo | ConvertTo-Json | Out-File -FilePath $LAST_RUN_INFO_PATH -Force
}
$ErrorActionPreference = "Continue"
$InformationPreference = "Continue"
Main
