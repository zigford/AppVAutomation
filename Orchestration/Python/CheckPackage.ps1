[CmdLetBinding(SupportsShouldProcess)]
Param()
#Python3.ps1
#Check for new versions of Python.
#
#1. Get old versions
#2. Compare with current version
#3. Download latest source into staging directory
#4. Generate .AppPackage xml file for importing into config manager
#5. Move staging folder into SourcePackages for importing using importconvert
. "$PSScriptRoot\InstallFunctions.ps1"
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$PackageName = (Get-Item "$PSScriptRoot").BaseName
$PackagePath = '\\usc.internal\usc\appdev\SCCMPackages\EXE'
$OldVersions = Get-ChildItem -Path $PackagePath -Filter "Python_Python*"
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
$LatestVersion = Get-PythonLatestProdVersion
#"Newest Package = $($NewestPackage.Version)"
#"Current download version = $LatestVersion"
If ($LatestVersion -gt $NewestPackage.Version) {
    "Ready to upgrade from $($NewestPackage.Version) to $LatestVersion, staging queue"
    $NewPackageName = "Python_Python_$($LatestVersion)_EXE_Open_USR"
    $PathToSource = "\\usc.internal\usc\appdev\General\Packaging\Testing\$NewPackageName"
    $LatestDownloadLink = Get-PythonLatestDownloadUrl -Version $LatestVersion
    $LatestDownloadFileName = "Python-$($LatestVersion).exe"
    If (-Not (Test-Path -Path $PathToSource)) {
        New-Item -ItemType Directory $PathToSource -Force
    }
    $DownloadedFiles = (Get-ChildItem -Path $PathToSource -Filter *Python*)
    If ($LatestDownloadFileName -in $DownloadedFiles.Name) {
        $PythonInstaller = $DownloadedFiles | ?{$_.Name -match $LatestDownloadFileName}
        $Version = $LatestVersion
        Write-Host -ForegroundColor Green "Found Python installer version $Version already downloaded"
    } Else { 
        Write-Host -ForegroundColor Red "Could not find latest Python installer. Downloading"
        $PythonInstaller = Get-DownloadFromLink -Link $LatestDownloadLink -Outpath $PathToSource -Outfile $LatestDownloadFileName
    }
    $PackageManifest = @"
<Application Name="Python" Version="$LatestVersion" Vendor="Python">
	<Type Name="EXE">
		<File>$LatestDownloadFileName</File>
		<Args>/quiet InstallAllUsers=1 TargetDir="%ProgramFiles%\Python"</Args> <!-- Options: arguments for the exe to install -->
        <UnFile>$LatestDownloadFileName</UnFile>
        <UnArgs>/quiet /uninstall</UnArgs>
        <ConfigManager>
            <AddDetectionClause>
                <DetectionClause Type="File">
                    <File FileName="python.exe" 
                        Path="C:\Program Files\Python"
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
    If ($PSCmdlet.ShouldProcess("$LatestVersion", "Create $PackageName version ")) {
        $PackageManifest | Out-File -FilePath "$PathToSource\$PackageName.AppPackage" -Force
        Move-Item $PathToSource "\\usc.internal\usc\appdev\General\Packaging\SourcePackages"
    }

} else {
    Write-Verbose "Newest $PackageName already packaged: $($NewestPackage.Version)"
}
