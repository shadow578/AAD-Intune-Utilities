# IntuneLAPS

[Microsoft LAPS](https://www.microsoft.com/en-us/download/details.aspx?id=46899), but with Intune using [Proactive Remediations](https://docs.microsoft.com/en-us/mem/analytics/proactive-remediations)

## Requirements

- You'll need a Intune Administrator account that can create Proactive Remediations
- To use Proactive Remediations, you may need an appropriate License
- Clients must run at least Windows 10 1903


## Setup

Follow these steps to setup IntuneLAPS

### Prepare The Scripts

1. Generate a keypair by running the `Generate-KeyPair.ps1` script
2. Copy your public key and paste it into the `IntuneLAPS-Detection.ps1` script where it says `$RSA_PUBLIC_KEY`
3. Optionally change the settings in `IntuneLAPS-Detections.ps1` as explained below
4. Rename the `private_key_***.key` file to `private.key`
5. Ensure that `AdminUI.ps1` and `private.key` are in the same directory when you run them \*

> \* Ensure that the private key is kept in a safe space. <br>
> While it should be OK to give your Administrators and IT Support Staff access to the private key (you have to to let them read passwords), you should ensure that only staff that needs access has access. <br>
> Also, make a backup of the key or something.

### Create Proactive Remediation Script In Endpoint Manager

1. Go to Endpoint Manager > `Reports` > `Endpoint Analytics` > `Proactive remediations`
2. Click `Create script package`
3. Give the script any name (for example 'IntuneLAPS') and optionally add a description
4. Select `IntuneLAPS-Detection.ps1` under `Detection script file`
5. Select `IntuneLAPS-Remediation.ps1` under `Remediation script file`
6. Set the following options:
    - `Run this script using the logged-on credentials` : No
    - `Enforce script signature check` : No
    - `Run script in 64-bit PowerShell` : Yes
7. Do not set a Scope tag (unless you know what you're doing)
8. On Assignments, set the assignments you'd like to use (e.g. all users). Set the Schedule to run at least every 24 hours
   - please note that assigning the script to all users or all devices includes privately owned devices (BYOD). Please ensure that you exclude those devices

### Configure Admin UI

1. Run `Get-RemediationScriptIDs.ps1` and login if prompted
2. In the Output, find the line that starts with 'IntuneLAPS' and copy the id behind it
3. Paste the ID into the `LAPS_REMEDIATION_SCRIPT_ID` in `AdminUI.ps1`


## Configuration Options

### IntuneLAPS-Detection.ps1

| Name                        | Description                                                                                                                           |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| RSA_PUBLIC_KEY              | Public Key used for password encryption                                                                                               |
| REGISTRY_KEYS_PATH          | Path to registry key used to keep track of last password change                                                                       |
| LAPS_LAST_CHANGE_KEY        | Name of registry key used to keep track of last password change                                                                       |
| LOCAL_ADMIN_NAME            | Name of the (builtin) local administrator account. Adjust this to match your locale                                                   |
| GET_LOCAL_ADMIN_DYNAMICALLY | Enable dynamically querying the local administrator account. If this fails (or is diabled), the account from LOCAL_ADMIN_NAME is used |
| DO_NOT_RUN_ON_SERVERS       | Enable a check if the script is running on a Windows server. Recommended to keep enabled                                              |
| CHANGE_PASSWORD_INTERVAL    | How many days between password changes. If you change this, you'll also have to change the value in `AdminUI.ps1`                     |
| PASSWORD_CONFIG             | Password generator configuration. See below                                                                                           |


### PASSWORD_CONFIG

| Name         | Description                                     |
| ------------ | ----------------------------------------------- |
| Length       | total length of generated passwords             |
| Numbers      | how many numbers are in the password            |
| Specials     | how many special characters are in the password |
| NormalChars  | a string with all normal characters             |
| NumberChars  | a string with all number characters             |
| SpecialChars | a string with all special characters            |

### AdminUI.ps1

| Name                       | Description                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------- |
| LAPS_REMEDIATION_SCRIPT_ID | script id of the remediation script. use `Get-RemediationScriptIds.ps1` to get this     |
| CHANGE_PASSWORD_INTERVAL   | Password change interval. Used to calculate 'next change in' value                      |
| GRAPH_API_BASE_URL         | Base URL to the graph api                                                               |
| RSA_PRIVATE_KEY            | Private key for password decryption. By default, this is loaded from `private.key` file |
