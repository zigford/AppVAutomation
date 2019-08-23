# Package Checker - For each package definition in 'packages' check if new dist avalable, if so create a package
# Cases:
# (1) Package definition is a folder with checkpackage.ps1 script
# (2) Package definition is a folder with a Manifest.xml definition
# (3) Package definition is a standalone PACKAGE.ps1 script

[CmdLetBinding(SupportsShouldProcess)]
Param()
#Start-Transcript -Path \\usc.internal\usc\appdev\General\Logs\AutoSequencer.log -Append
$Working = $PSScriptRoot

#$DefinedApps='VSCode.ps1','Git','Python'
Get-ChildItem -Path (Join-Path -Path $Working -ChildPath "Packages") | ForEach-Object {
    $DefinedApp = $_.Name
    $DefinedAppPath = $_.FullName

    Write-Verbose "Checking for updated version of app $DefinedApp at $(Get-Date)" -Verbose
    If ((Get-Item $DefinedAppPath).PSIsContainer) {
        $CheckPackage = Join-Path -Path $DefinedAppPath -ChildPath "CheckPackage.ps1"
        $Manifest = Join-Path -Path $DefinedAppPath -ChildPath "Manifest.xml"
        If (Test-Path $CheckPackage) {
            & "$CheckPackage" -Verbose
        } elseif (Test-Path $Manifest) {
            & "$Working\Functions\Start-ManifestProcess.ps1" -Manifest $Manifest -Verbose
        }
    } else {
        & "$DefinedAppPath" -Verbose
    }
}

#Stop-Transcript -EA SilentlyContinue
