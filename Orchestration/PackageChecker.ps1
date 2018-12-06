#Package Checker - Check for new versions of each app defined
[CmdLetBinding(SupportsShouldProcess)]
Param()
Start-Transcript -Path \\usc.internal\usc\appdev\General\Logs\AutoSequencer.log -Append
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$DefinedApps='PowerBI.ps1','Firefox-Quantum.ps1','VSCode.ps1','Git'
ForEach ($DefinedApp in $DefinedApps) {
    Write-Verbose "Running test for $DefinedApp at $(Get-Date)" -Verbose
    If ((Get-Item "$Working\$DefinedApp").PSIsContainer) {
        & "$Working\$DefinedApp\CheckPackage.ps1" -Verbose
    } else {
        & "$Working\$DefinedApp" -Verbose
    }
}

Stop-Transcript -EA SilentlyContinue