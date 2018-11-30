#Git.ps1
#Check for new versions of Git.
#
#1. Get old versions
#2. Compare with current version
#3. Download latest source into staging directory
#4. Generate .AppPackage xml file for importing into config manager
#5. Move staging folder into SourcePackages for importing using importconvert
. '.\InstallFunctions.ps1'
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$PackageName = (Get-Item (Get-Location).Path).BaseName
$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\EXE'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter "Git_Git for Windows*"
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
$LatestVersion = Get-GitLatestVersion
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $LatestVersion"
If ($LatestVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $LatestVersion, staging queue"
    $NewPackageName = "Git_Git for Windows_$($LatestVersion)_EXE_Open_USR"
    $PathToSource = "\\usc.internal\usc\appdev\General\Packaging\Testing\$NewPackageName"
    $LatestDownloadLink = Get-GitDownloadLink
    $LatestDownloadFileName = "Git_$($LatestVersion).exe"
    If (-Not (Test-Path -Path $PathToSource)) {
        New-Item -ItemType Directory $PathToSource -Force
    }
    $DownloadedFiles = (Get-ChildItem -Path $PathToSource -Filter *Git*)
    If ($LatestDownloadFileName -in $DownloadedFiles.Name) {
        $GitInstaller = $DownloadedFiles | ?{$_.Name -match $LatestDownloadFileName}
        $Version = $LatestVersion
        Write-Host -ForegroundColor Green "Found Git installer version $Version already downloaded"
    } Else { 
        Write-Host -ForegroundColor Red "Could not find latest Git installer. Downloading"
        $GitInstaller = Get-DownloadFromLink -Link $LatestDownloadLink -Outpath $PathToSource -Outfile $LatestDownloadFileName
    }
    $PackageManifest = @"
<Application Name="Git for Windows" Version="$LatestVersion" Vendor="Git">
	<Type Name="EXE">
		<File>$LatestDownloadFileName</File>
		<Args>/VERYSILENT /MERGETASKS=!runcode</Args> <!-- Options: arguments for the exe to install -->
        <UnFile>C:\Program Files\Git\unins000.exe</UnFile>
        <UnArgs>/VERYSILENT /LOG=C:\Windows\AppLog\GitWinUninstall.log /NORESTARTM</UnArgs>
        <ConfigManager>
            <AddDetectionClause>
                <DetectionClause Type="File">
                    <File FileName="git.exe" 
                        Path="C:\Program Files\Git\bin"
                    />
                    <Properties PropertyType="Version"
                        ExpectedValue="$LatestVersion"
                        ExpressionOperator="GreaterEquals"
                    />
                </DetectionClause>
            </AddDetectionClause>
            <RebootBehavior>BasedOnExitCode</RebootBehavior>
            <LogonRequirementType>WhetherOrNotUserLoggedOn</LogonRequirementType> 
            <InstallationBehaviorType>InstallForSystem</InstallationBehaviorType>
            <!-- <WhatIf>True</WhatIf> -->
        </ConfigManager>
	</Type>
</Application>
"@
    $PackageManifest | Out-File -FilePath "$PathToSource\$PackageName.AppPackage" -Force
    Move-Item $PathToSource "\\usc.internal\usc\appdev\General\Packaging\SourcePackages"

} else {
    Write-Verbose "Newest $PackageName already packaged: $($NewestPackage.Version)"
}
