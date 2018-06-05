#Package Checker - Check for new versions of each app defined
[CmdLetBinding()]
Param()
Start-Transcript -Path \\usc.internal\usc\appdev\General\Logs\AutoSequencer.log -Append
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$DefinedApps='PowerBI.ps1','Firefox-Quantum.ps1','VSCode.ps1','Git.ps1'
ForEach ($DefinedApp in $DefinedApps) {
    Write-Verbose "Running test for $DefinedApp at $(Get-Date)" -Verbose
    & "$Working\$DefinedApp" -Verbose
}

Stop-Transcript