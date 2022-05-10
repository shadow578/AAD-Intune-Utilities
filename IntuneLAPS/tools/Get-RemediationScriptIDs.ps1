function Initialize-MSGraph() {
    # load the module
    try {
        Import-Module Microsoft.Graph.InTune
    }
    catch {
        Write-Host @"
failed to import module 'Microsoft.Graph.InTune'. 
Please install it by running the following command in a admin shell:
   Install-Module Microsoft.Graph.InTune -Force

"@ -ForegroundColor Red
        Exit 1        
    }

    # login
    Write-Host "If prompted, please login with your credentials and allow access"
    $login = Connect-MSGraph
    if (-not $login) {
        Write-Host "login failed" -ForegroundColor Red
        Exit 1
    }

    Write-Host "Logged in as $($login.UPN)"
}

function Main() {
    # login
    Initialize-MSGraph

    # query all scripts
    $response = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts" -HttpMethod GET

    # list all scripts as <NAME> : <ID>
    Write-Host ""
    $($response.Value) | ForEach-Object {
        Write-Host "$($_.displayName) : $($_.id)"
    }
}
Main
