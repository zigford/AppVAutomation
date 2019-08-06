[CmdLetBinding(SupportsShouldProcess)]
Param()
#VSCode.ps1
#Check for new versions of VSCode.
#
#1. Get old versions
#2. Compare with current version
#3. Queue package as nessecary
. '\\usc.internal\usc\appdev\SCCMSoftware\Microsoft\Visual Studio Code\Latest\Working Files\InstallFunctions.ps1'
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$PackageName = "$((Get-Item $MyInvocation.MyCommand.Source).BaseName)"
$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\APPV5Packages'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter "Microsoft_Visual Studio Code_*"
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
$LatestVersion = Get-VSCodeLatestVersion
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $LatestVersion"
If ($LatestVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $LatestVersion, staging queue"
    $PackageQueue = @"
Set-Location "\\usc.internal\usc\appdev\SCCMSoftware\Microsoft\Visual Studio Code\Latest\Working Files"
#Get-Existing Package and Make a copy
`$NewPackageName = "Microsoft_Visual Studio Code_$($LatestVersion)_APPV_Open_USR"
New-AppvSequencerPackage -Installer .\Install.bat -OutputPath `$env:USERPROFILE\Desktop -FullLoad -Name `$NewPackageName -TemplateFilePath .\vscode.appvt
Import-Module "\\usc.internal\usc\appdev\General\SCCMTools\Scripts\Modules\USC-APPV"
`$PackagePath = "`$env:USERPROFILE\Desktop\`$NewPackageName"
If (Get-ChildItem -Path `$PackagePath *.appv) {
    #Package updated
    Set-AppvXML -Path `$PackagePath -DisableObjects -StripComments
    Copy-Item `$env:USERPROFILE\Desktop\`$NewPackageName -Recurse \\usc.internal\usc\appdev\General\Packaging\SourcePackages
}
"@

    If ($PSCmdlet.ShouldProcess("$LatestVersion", "Create VSCode version ")) {
        $PackageQueue | Out-File -FilePath \\usc.internal\usc\appdev\General\Packaging\PackageQueue\$PackageName.ps1 -Force
        $PackageVM = & "$Working\PackageOrchestrator.ps1" -Build -PackageName $PackageName
    }
} else {
    Write-Verbose "Newest $PackageName already packaged: $($NewestPackage.Version)"
}
