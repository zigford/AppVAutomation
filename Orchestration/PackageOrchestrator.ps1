[CmdletBinding()]
#AutoPackage Ochestrator
#BuildPackage.ps1 - Builds a new VM with APPV5 HF4 Sequencer installed. Auto startup and read for the packager queue
#
#1. Building a packager machine
#2. Wait for package output in a certain directory
#3. Destroy the VM
#
Param([switch]$Build,[switch]$Destroy,$PackageVM, $PackageName)

$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module $Working\MachineOrchestration.psm1

Write-Verbose "Package Orchestrator running from $Working"
If ($Build) {
    $PackageVM=(& "$Working\BuildPackager.ps1" -Verbose -PackageName $PackageName)

    return $PackageVM
}

If ($Destroy) {
    If ($PackageVM) {
        & "$Working\DestoryPackager.ps1" -VM $PackageVM
    }
}