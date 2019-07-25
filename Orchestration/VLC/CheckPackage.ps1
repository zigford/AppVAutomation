[CmdLetBinding(SupportsShouldProcess)]
Param()
#VSCode.ps1
#Check for new versions of VSCode.
#
#1. Get old versions
#2. Compare with current version
#3. Queue package as nessecary
. '.\InstallFunctions.ps1'
$PackageQueueDir = "\\usc.internal\usc\appdev\General\Packaging\PackageQueue"
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$PackageName = Split-Path -Path $PSScriptRoot -Leaf
$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\APPV5Packages'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter "VideoLAN_VLC Media Player_*"
$NewestPackage = $OldVersions | Select-Object Name,FullName,@{
    label='Version';expression={
        $VerString = $_.Name.Split('_')[2]
        If ($VerString -match '\.') {
            New-Object System.Version ("{0:N2}" -f $VerString)
        } Else {
            New-Object System.Version ("{0:N2}" -f [int]$VerString)
        }
    }
} | Sort-Object -Property Version | Select-Object -Last 1
$LatestVersion = Get-VLCLatestVersion
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $LatestVersion"
If ($LatestVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $LatestVersion, staging queue"
    $PackageQueue = @"
Set-Location "`$HOME\Desktop"
New-Item -ItemType Directory -Name Source
Copy-Item -Path "$PackageQueueDir\VLC" -Recurse Source
Set-Location Source
`$NewPackageName = "VideoLAN_VLC Media Player_$($LatestVersion)_APPV_Open_USR"
New-AppvSequencerPackage -Installer .\Install.bat -OutputPath `$env:USERPROFILE\Desktop -FullLoad -Name `$NewPackageName -TemplateFilePath .\vscode.appvt
Import-Module "\\usc.internal\usc\appdev\General\SCCMTools\Scripts\Modules\USC-APPV"
`$PackagePath = "`$env:USERPROFILE\Desktop\`$NewPackageName"
If (Get-ChildItem -Path `$PackagePath *.appv) {
    #Package updated
    #Set-AppvXML -Path `$PackagePath -DisableObjects -StripComments
    Copy-Item `$env:USERPROFILE\Desktop\`$NewPackageName -Recurse \\usc.internal\usc\appdev\General\Packaging\SourcePackages
}
Remove-Item `$MyInvocation.MyCommand.Source
Remove-Item -Recurse -Force "$PackageQueueDir\VLC"
"@

    If ($PSCmdlet.ShouldProcess("$LatestVersion", "Create VLC version ")) {
        New-Item -ItemType Directory -Path $PackageQueueDir -Name "VLC"
        $InstallFile = Get-DownloadFromLink -Link (Get-VLCDownloadURL -Type MSI) -OutPath "$PackageQueueDir\VLC"
        $InstallScript = @"
start /wait msiexec.exe /I "%~dp0$($InstallFile.Name)" /qb REBOOT=REALLYSUPPRESS
"@
        $PackageQueue | Out-File -FilePath \\usc.internal\usc\appdev\General\Packaging\PackageQueue\$PackageName.ps1 -Force
        $InstallScript | Out-File "$PackageQueueDir\VLC\Install.bat"
        $PackageVM = & "$Working\PackageOrchestrator.ps1" -Build -PackageName $PackageName
    } else {
        $PackageQueue
        $InstallScript
    }
} else {
    Write-Verbose "Newest $PackageName already packaged: $($NewestPackage.Version)"
}
