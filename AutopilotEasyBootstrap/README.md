# AutopilotEasyImport

A wrapper for [Get-WindowsAutopilotInfo](https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/) that guides administrators through choosing the right values.<br>
Using a guided script removes a lot of the jankyness of the normal procedure (starting powershell with the right executionpolicy, somehow connect to the internet before OOBE finished, figuring out the right parameters and so on). That way, even someone that is not knowlegeable in powershell / intune should be able to import new devices.

## Usage

After adjusting `AutoPilotBootstrap.ps1`, copy both `apbootstrap.bat` and `AutoPilotBootstrap.ps1` to the root of an USB- Stick. 
When you wish to import a device into autopilot, plug in the USB- Stick and press `SHIFT+F10` during device OOBE to open a command prompt. 
Now, navigate to your USB- Stick (it will probably be either the D: or E: drive) and start `apbootstrap.bat`. 
After this, just follow the instructions and you're done.

Alternatively, if you deploy a custom windows image, you could place the scripts in the `System32` folder and cut out the need for an USB- Stick.
