#Firefox.ps1
#Check for new versions of Firefox.
#
#1. Get old versions
#2. Compare with current version
#3. Queue package as nessecary
. '\\usc.internal\usc\appdev\SCCMSoftware\Mozilla\Firefox\Latest\Working Files\InstallFunctions.ps1'
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$PackageName = "$((Get-Item $MyInvocation.MyCommand.Source).BaseName)"
$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\APPV5Packages'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter "Mozilla_Firefox Quantum_*"
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
$LatestFireFox = Get-FirefoxDownloadLink
$LatestFireFoxFile = ($LatestFireFox.Split("/") | Select-Object -Last 1).Replace('%20',' ')
$CurrentVersion = New-Object System.version (($LatestFireFox -split '%20' -split ' ')[2] -split '.exe')[0]
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $CurrentVersion"
If ($CurrentVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $CurrentVersion, staging queue"
    $FirefoxQueue = @"
#Start-Process -FilePath "\\usc.internal\usc\appdev\SCCMSoftware\AutoItScript\CustomizeIE8.exe" -Wait
Set-Location "\\usc.internal\usc\appdev\SCCMSoftware\Mozilla\Firefox\Latest\Working Files"
#Get-Existing Package and Make a copy
`$NewPackageName = "Mozilla_Firefox Quantum_$($CurrentVersion)_APPV_Open_USR"
New-AppvSequencerPackage -Installer .\Install.bat -OutputPath `$env:USERPROFILE\Desktop -FullLoad -Name `$NewPackageName -TemplateFilePath .\Firefox.appvt
If (Get-ChildItem -Path `$env:USERPROFILE\Desktop\`$NewPackageName *.appv) {
    #Package updated
    Copy-Item `$env:USERPROFILE\Desktop\`$NewPackageName -Recurse \\usc.internal\usc\appdev\General\Packaging\SourcePackages
}
Get-Date | Write-Output | OutFile \\usc.internal\usc\appdev\General\Packaging\FireFox.Package
"@

    $FirefoxQueue | Out-File -FilePath \\usc.internal\usc\appdev\General\Packaging\PackageQueue\$PackageName.ps1 -Force
    $PackageVM = & "$Working\PackageOrchestrator.ps1" -Build -PackageName $PackageName
    <#Do {
        Write-Verbose "Waiting for package to be built..."
        Start-Sleep -Seconds 20
    } While (Test-Path -Path \\usc.internal\usc\appdev\General\Packaging\PackageQueue\Firefox-Quantum.ps1)
        Write-Verbose "Package complete. Destroying VM"
        #& "$Working\PackageOrchestrator.ps1" -Destroy -PackageVM $PackageVM
        #>
} else {
    Write-Verbose "Newest Firefox Quantum already packaged: $($NewestPackage.Version)"
}
