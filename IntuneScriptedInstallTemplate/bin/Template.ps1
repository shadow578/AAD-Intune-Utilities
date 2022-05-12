param(
    #TODO: add custom installation parameters here

    <# Install the program #>
    [Parameter()]
    [switch]
    $Install,

    <# Uninstall the program #>
    [Parameter()]
    [switch]
    $Remove
)

function DoInstall() {
    #TODO: add your custom install logic here
}

function DoUninstall() {
    #TODO: add your custom uninstall logic here
}

if ($Install) {
    DoInstall
}
elseif ($Remove) {
    DoUninstall
}
