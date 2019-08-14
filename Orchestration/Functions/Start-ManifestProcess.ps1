[CmdLetBinding()]
Param($Manifest)

Get-Module InstallFunctions | Remove-Module
Import-Module (Join-Path $PSScriptRoot "InstallFunctions.psm1")
$Settings = Import-Settings

$XML = [xml](Get-Content $Manifest)

$Downloads = $XML.Application.Downloads.Download
$Installer = $Downloads | Where-Object {$_.Name -eq 'Installer'}

# Validate XML
# Must have either Version or VersionFunction
If (-Not ($Installer.Version) -and -Not ($Installer.VersionFunction)) {
    throw "Invalid xml, missing version stuff"
}
# Must have either URL or URLFunction
If (-Not ($Installer.URL) -and -Not ($Installer.URLFunction)) {
    throw "Invalid xml, missing url stuff"
}

$AppVersion = If ($Installer.Version) { $Installer.Version } else {
    Invoke-Expression $Installer.VersionFunction}
$URL = If ($Installer.URL) { $Installer.URL } else {
    Invoke-Expression $Installer.URLFunction}

$AppVendor = $XML.Application.Vendor
$AppName = $XML.Application.Name
$AppLicense = $XML.Application.License
$AppTarget = $XML.Application.Target

$Settings.PackageName = "${AppVendor}_${AppName}_${AppVersion}_${AppLicense}_${AppTarget}"

$PackageProperties = @{
    Settings = $Settings
    URL = $URL
    Version = $AppVersion
    $XML = $XML
}

$PackageProperties | Select-NewerPackageVersion | New-AppPackageBundle
