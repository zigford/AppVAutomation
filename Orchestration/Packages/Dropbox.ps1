[CmdletBinding()]
Param()
#Dropbox.ps1
#Check for new versions of Dropbox.
#
#1. Get old versions
#2. Compare with current version
#3. Queue package as nessecary
. \\usc.internal\usc\appdev\SCCMSoftware\Dropbox\Dropbox\Latest\InstallFunctions.ps1
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\APPV5Packages'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter Dropbox*
$NewestPackage = $OldVersions | Select-Object Name,FullName,@{label='Version';expression={new-object System.Version ($_.Name.Split('_')[2])}} | Sort-Object -Property Version | Select -Last 1
$CurrentVersion = New-Object System.version ((Get-DropboxDownloadLink) -split '%20' -split 'data.exe')[1]
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $CurrentVersion"
If ($CurrentVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $CurrentVersion, staging queue"
    $DropboxQueue = @"
Set-Location \\usc.internal\usc\appdev\SCCMSoftware\Dropbox\Dropbox\Latest
#Get-Existing Package and Make a copy
`$NewPackageName = "Dropbox_Dropbox_$($CurrentVersion)_APPV_Open_USR"
`$CopiedPackage = Copy-Item -Path $($NewestPackage.FullName) `$env:USERPROFILE\Desktop -Recurse
`$CopiedAPPVFile = gci `$env:USERPROFILE\Desktop *.appv -recurse
Update-AppvSequencerPackage -InputPackagePath `$CopiedAPPVFile.FullName -Installer .\Install.bat -OutputPath `$env:USERPROFILE\Desktop -FullLoad -Name `$NewPackageName
If (Get-ChildItem -Path `$env:USERPROFILE\Desktop\`$NewPackageName *.appv) {
    #Package updated
    Copy-Item `$env:USERPROFILE\Desktop\`$NewPackageName -Recurse \\usc.internal\usc\appdev\General\Packaging\SourcePackages
}
"@

$DropboxQueue | Out-File -FilePath \\usc.internal\usc\appdev\General\Packaging\PackageQueue\Dropbox.ps1
$PackageVM = & "$Working\PackageOrchestrator.ps1" -Build -Verbose
Do {
    Write-Verbose "Waiting for package to be built..."
    Start-Sleep -Seconds 20
} While (Test-Path -Path \\usc.internal\usc\appdev\General\Packaging\PackageQueue\Dropbox.ps1)
    Write-Verbose "Package complete. Destroying VM"
# & "$Working\PackageOrchestrator.ps1" -Destroy -PackageVM $PackageVM

} else { "Not happening" 
$NewestPackage }
