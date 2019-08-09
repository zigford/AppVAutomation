#Package Checker - Check for new versions of each app defined
[CmdLetBinding(SupportsShouldProcess)]
Param()
#Start-Transcript -Path \\usc.internal\usc\appdev\General\Logs\AutoSequencer.log -Append
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

#$DefinedApps='VSCode.ps1','Git','Python'
Get-ChildItem -Path (Join-Path -Path $Working -ChildPath "Packages") | ForEach-Object {
    [Array]$DefinedApps += Join-Path -Path "Packages" -ChildPath $_.Name
}

ForEach ($DefinedApp in $DefinedApps) {
    Write-Verbose "Running test for $DefinedApp at $(Get-Date)" -Verbose
    $DefinedAppPath = Join-Path -Path $Working -ChildPath $DefinedApp
    If ((Get-Item $DefinedAppPath).PSIsContainer) {
        $CheckPackage = Join-Path -Path $DefinedAppPath -ChildPath CheckPackage.ps1
        $Manifest = Join-Path -Path $DefinedAppPath -ChildPath Manifest.xml
        If (Test-Path $CheckPackage) {
            & "$CheckPackage" -Verbose
        } elseif (Test-Path $Manifest) {
            & "$Working\Functions\Start-ManifestProcess.ps1" -Manifest $Manifest -Verbose
        }
    } else {
        & "$Working\$DefinedApp" -Verbose
    }
}

#Stop-Transcript -EA SilentlyContinue
