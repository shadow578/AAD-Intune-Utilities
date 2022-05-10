# AADSync-SuperCharger

a small (-ish) script that makes syncing users and devices from a on-premise AD to Azure a lot faster. 

## Installation

The AADSync-SuperCharger script must be installed on the server that the AAD Connector is installed on. 
The server must also have the ActiveDirectory powershell module installed and must be able to query user and computer objects (test by running `Get-ADUser` and `Get-ADComputer`)

to install, first run the `Setup.ps1` script in an elevated powershell. 
After this, create a new scheduled task to run the `AADSyncSuperCharger.ps1` script and set it to run every 5 Minutes. 

## Configuration

configuration happens in the `$CONFIG` variable set at the top of `AADSyncSuperCharger.ps1`.
See the comments on the values for details.

## Principle of Operation

__User Objects:__
on every run, the script queries all new users since the last script run. If there are any, an AADSync is started.

__Computer Objects:__
on every run, the script queries all modified computers since the last run, and checks if their `userCertificate` attribute is set. 
If any computer that meets these conditions is found, an AADSync is started.
