[CmdLetBinding()]
Param($Manifest)

Get-Module InstallFunctions | Remove-Module
Import-Module (Join-Path $PSScriptRoot "InstallFunctions.psm1")
$Settings = Import-Settings $Manifest

$XML = [xml](Get-Content $Manifest)

$Downloads = $XML.Application.Downloads.Download
$Installer = $Downloads | Where-Object {$_.Name -eq 'Installer'}

# Validate XML
# Must have either Version or VersionFunction
If (
    -Not ($Installer.Version) -and
    -Not ($Installer.VersionFunction) -and
    -Not ($Installer.VersionURL)
    ) {
    throw "Invalid xml, missing version stuff"
}
# Must have either URL or URLFunction
If (-Not ($Installer.URL) -and -Not ($Installer.URLFunction)) {
    throw "Invalid xml, missing url stuff"
}

$PackageProperties = @{
    Settings = $Settings
    XML = $XML
    ManifestPath = $Manifest
}

If ($PackageProperties.XML.Application.Type.Name -eq 'APPV') {
    $PackageProperties | Select-NewerPackageVersion | New-SequencerScript
} else {
    $PackageProperties | Select-NewerPackageVersion | New-AppPackageBundle
}
