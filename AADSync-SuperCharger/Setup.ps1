param()

$LOG_SOURCES_FOR_REGISTRATION = @(
    "AADSuperCharger"
    "AADSuperCharger-SETUP"
)

function Write-LogEntry(
    [string] $Message,
    [int] $ID,
    [System.Diagnostics.EventLogEntryType] $Type = [System.Diagnostics.EventLogEntryType]::Information,
    [string] $SourceName = "AADSuperCharger-SETUP"
) {
    New-LogSource -Name $SourceName
    Write-EventLog -LogName "Application" -Source $SourceName -EntryType $Type -EventId $ID -Message $Message | Out-Null
}

function New-LogSource([string] $Name) {
    if ((-not ([System.Diagnostics.EventLog]::Exists("Application"))) -or (-not ([System.Diagnostics.EventLog]::SourceExists($Name)))) {
        New-EventLog -LogName "Application" -Source $Name
        Write-EventLog -LogName "Application" -Source $Name -EntryType Information -EventId 100 -Message "Source $Name Created"
    }
}


function Main() {
    # register log sources
    $LOG_SOURCES_FOR_REGISTRATION | ForEach-Object { New-LogSource -Name $_ }
}
$ErrorActionPreference = "Continue"
$InformationPreference = "Continue"
Main
