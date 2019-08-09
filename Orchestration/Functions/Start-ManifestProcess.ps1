[CmdLetBinding()]
Param($Manifest)

Get-Module InstallFunctions | Remove-Module
Import-Module (Join-Path $PSScriptRoot "InstallFunctions.psm1")
$Settings = Import-Settings

$XML = [xml](Get-Content $Manifest)

$Downloads = $XML.Application.Downloads.Download
$Installer = $Downloads | Where-Object {$_.Name -eq 'Installer'}
$VersionFunction = $Installer.VersionFunction

$AppVendor = $XML.Application.Vendor
$AppName = $XML.Application.Name
$AppLicense = $XML.Application.License
$AppTarget = $XML.Application.Target

$AppVersion = Invoke-Expression $VersionFunction

$Settings.PackageName = "${AppVendor}_${AppName}_${AppVersion}_${AppLicense}_${AppTarget}"

$PackageProperties = @{
    Settings = $Settings
    $XML = $XML
}

$PackageProperties | Select-NewerPackageVersion | New-AppPackageBundle
