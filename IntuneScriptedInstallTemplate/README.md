# Win32 Scripted Installation Template

allows for the creation of scripted installation for software, deployed over intune win32 apps. 
Before using, download `IntuneWinAppUtil.exe` from  (microsoft/Microsoft-Win32-Content-Prep-Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) and place it in the `bin` directory.

Below the line you'll find a template readme for use with your custom app

----

# Your App Name

say a few words about what this app does



# Program

| Option                   | Value                                                                                        |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| Install Command          | powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File install.ps1 -Install |
| Uninstall Command        | powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File install.ps1 -Remove  |
| Install Behaviour        | System                                                                                       |
| Device restart behavious | No specific action                                                                           |


## Return Codes

| Return code | Code Type | Description            |
| ----------- | --------- | ---------------------- |
| 0           | Success   | Everything went fine   |
| 500         | Failed    | Something bad happened |

# Requirements

| Option                               | Value            |
| ------------------------------------ | ---------------- |
| Operating System Architecture        | [32-bit, 64-bit] |
| Minimum Operating System             | Windows 10 1903  |
| Disk Space Required                  | N/A              |
| Physical Memory Required             | N/A              |
| Minimum Number of Logical Processors | N/A              |
| Minimum CPU speed Required           | N/A              |

# Detection Rules

Use the `Manually configure detection rules` rule format

| Option                                        | Value                    |
| --------------------------------------------- | ------------------------ |
| Rule type                                     | File                     |
| Path                                          | C:\Program Files\YourApp |
| File or folder                                | install.marker           |
| Detection method                              | File or folder exists    |
| Associate with a 32-bit app on 64-bit clients | No                       |

__AND__

| Option                                        | Value                       |
| --------------------------------------------- | --------------------------- |
| Rule type                                     | Registry                    |
| Key Path                                      | HKEY_LOCAL_MACHINE\SOME\KEY |
| Value Name                                    | MyValue                     |
| Detection method                              | Integer Comparison          |
| Operator                                      | Equals                      |
| Value                                         | 0                           |
| Associate with a 32-bit app on 64-bit clients | No                          |

__AND__

| Option                    | Value                                  |
| ------------------------- | -------------------------------------- |
| Rule type                 | MSI                                    |
| MSI Product code          | {12345678-1234-1234-1234-123456789012} |
| MSI product version check | No                                     |
