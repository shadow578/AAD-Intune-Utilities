param(
    <# MODE: init the project #>
    [Parameter()]
    [switch]
    $Init,

    <# MODE: build the project #>
    [Parameter()]
    [switch]
    $Build,

    <# in BUILD+INIT mode: directory that contains the package sources #>
    [Parameter()]
    [string]
    $SourceFilesDirectory = "$((Get-Item $PSScriptRoot).Parent.FullName)\src",

    <# in BUILD mode: name of the main installation script #>
    [Parameter()]
    [string]
    $MainScriptName = "install.ps1",

    <# in BUILD mode: directory the intunewin package is written to #>
    [Parameter()]
    [string]
    $BuildOutputDirectory = "$((Get-Item $PSScriptRoot).Parent.FullName)\dist"
) 

$TB_VERSION = "22W19a"
$PACKAGING_TOOL_PATH = "$PSScriptRoot\IntuneWinAppUtil.exe"
$SCRIPT_TEMPLATE_PATH = "$PSScriptRoot\Template.ps1"
$SUBVERSION_CHARS = "abcdefghijklmnopqrstuvwxyz".ToCharArray()

function New-Directory([string]$Path) {
    New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
}

function Get-VersionString() {
    $culture = Get-Culture
    $now = Get-Date

    $yearShort = $now.ToString("yy")
    $weekOfYear = $culture.Calendar.GetWeekOfYear(
        $now, 
        $culture.DateTimeFormat.CalendarWeekRule.value__, 
        $culture.DateTimeFormat.FirstDayOfWeek.value__
    )

    return "$($yearShort)W$($weekOfYear)"
}

function Get-ProjectName() {
    # search for a project_name.txt file in the project root
    $projectName = ""
    $projectNameInfoPath = "$((Get-Item $PSScriptRoot).Parent.FullName)\project_name.txt"
    if (Test-Path -Path $projectNameInfoPath -PathType Leaf) {
        $projectName = (Get-Content -Path $projectNameInfoPath).Trim()
    } 
    
    # fallback to the name of project root directory
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        $projectName = (Get-Item $PSScriptRoot).Parent.BaseName
    }

    return $projectName
}

function Init() {
    # ensure the project is not already initialized
    $mainScriptFullPath = "$($SourceFilesDirectory)\$($MainScriptName)"
    if (Test-Path -Path $mainScriptFullPath -PathType Leaf) {
        Write-Host "Project is already initialized"
        return
    }

    # create new install script from template
    New-Directory -Path $SourceFilesDirectory
    Get-Content -Path $SCRIPT_TEMPLATE_PATH | Out-File -FilePath $mainScriptFullPath -Encoding utf8 -Force

    # done
    Write-Host "Project was initialized in '$mainScriptFullPath'"
}

function Build() {
    # ensure the project was initialized
    $mainScriptFullPath = "$($SourceFilesDirectory)\$($MainScriptName)"
    if (-not (Test-Path -Path $mainScriptFullPath -PathType Leaf)) {
        Write-Host "Project was not initialized! Please initialize with the '-Init' option"
        return
    }

    # create output directory if needed
    New-Directory -Path $BuildOutputDirectory

    # build the filename to the intunewin package
    # and remove the previous build
    $intunewinPackagePath = "$($BuildOutputDirectory)\$([System.IO.Path]::GetFileNameWithoutExtension($MainScriptName)).intunewin" 
    Remove-Item -Path $intunewinPackagePath -Force -ErrorAction SilentlyContinue | Out-Null

    # build the filename with added version info
    $projectName = Get-ProjectName
    $versionString = Get-VersionString
    $subVersion = 0
    do {
        $versionedIntunewinPackageName = "$($projectName)_$($versionString)$($SUBVERSION_CHARS[$subVersion]).intunewin"
        $subVersion++
    }while (Test-Path -Path "$($BuildOutputDirectory)\$($versionedIntunewinPackageName)")

    # build the application package
    Write-Host "building package from '$MainScriptName'@'$SourceFilesDirectory' to '$BuildOutputDirectory'"
    & $PACKAGING_TOOL_PATH -c $SourceFilesDirectory -s $MainScriptName -o $BuildOutputDirectory

    # rename built package
    Rename-Item -Path $intunewinPackagePath -NewName $versionedIntunewinPackageName
    Write-Host "build finished for '$versionedIntunewinPackageName'"
}

# select the right mode
Write-Host "IntuneScriptedInstallTemplate BuildTool version $TB_VERSION"
if ($Init) {
    Init
}
elseif ($Build) {
    Build
}
else {
    Write-Host "no mode selected! Use either '-Init' or '-Build' option"
}

