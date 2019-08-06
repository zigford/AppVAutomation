#Firefox.ps1
#Check for new versions of Firefox.
#
#1. Get old versions
#2. Compare with current version
#3. Queue package as nessecary
. '\\usc.internal\usc\appdev\SCCMSoftware\Microsoft\PowerBI\Latest\Working Files\InstallFunctions.ps1'
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$PackageName = "$((Get-Item $MyInvocation.MyCommand.Source).BaseName)"
$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\APPV5Packages'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter 'Microsoft_Power BI Desktop*'
$NewestPackage = $OldVersions | Select-Object Name,FullName,@{label='Version';expression={new-object System.Version ($_.Name.Split('_')[2])}} | Sort-Object -Property Version | Select -Last 1
$CurrentVersion = New-Object System.version (Get-PowerBIVersion)
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $CurrentVersion"
If ($CurrentVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $CurrentVersion, staging queue"
    $PackageQueue = @"
Set-Location "\\usc.internal\usc\appdev\SCCMSoftware\Microsoft\PowerBI\Latest\Working Files"
`$NewPackageName = "Microsoft_Power Bi Desktop x64_$($CurrentVersion)_APPV_Site_USR"
New-AppvSequencerPackage -Installer .\InstallSoftware.bat -OutputPath `$env:USERPROFILE\Desktop -FullLoad -Name `$NewPackageName
If (Get-ChildItem -Path `$env:USERPROFILE\Desktop\`$NewPackageName *.appv) {
    #Package updated
    Copy-Item `$env:USERPROFILE\Desktop\`$NewPackageName -Recurse \\usc.internal\usc\appdev\General\Packaging\SourcePackages
}
"@

$PackageQueue | Out-File -FilePath \\usc.internal\usc\appdev\General\Packaging\PackageQueue\$PackageName.ps1 -Force
$PackageVM = & "$Working\PackageOrchestrator.ps1" -Build -PackageName $PackageName
Write-Verbose "End custom execution"

} else { 
    Write-Verbose "No update needed for PowerBI $($NewestPackage.Version)"
}