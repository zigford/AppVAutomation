########################
#Setuping enviironments#
#and Variables         #
########################
#Dot Source Queries and functions
Set-Location $env:SystemDrive
. $PSScriptRoot\SMSFunction.ps1
If (Test-Path -Path 'D:\Program Files') {
    $ProgramFiles = 'D:\Program Files'
} ElseIf (Test-Path -Path 'C:\Program Files (x86)') {
    $ProgramFiles = 'C:\Program Files (x86)'
} Else {
    $ProgramFiles = 'C:\Program Files'
}
$ConfigMgrModules = "$ProgramFiles\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
Import-Module $ConfigMgrModules
Import-Module ActiveDirectory
$ErrorActionPreference = "Stop"
$SiteCode = 'SC1'
$SiteServer = 'wsp-configmgr01.usc.internal'
#Setup PSDrive
If (-Noe (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer
}
$PackageRoot = "\\usc.internal\usc\appdev\General\Packaging\SourcePackages"
$PackageDest = "\\usc.internal\usc\appdev\SCCMPackages"
$CompletedRoot = "\\usc.internal\usc\appdev\General\Packaging\CompletedPackages"
$RetiredRoot = "\\usc.internal\usc\appdev\General\Packaging\RetiredPackages"

#Select all packages to be imported
Get-ChildItem -Path $PackageRoot | Where-Object {Get-ChildItem -Path $_.FullName -Include @("*.sprj","*.appv","*.apppackage") -Recurse} | ForEach-Object {
   
    Set-Location C:
    #Get all the info about the package
    $SplitName = $_.Name -split "_"
    $Publisher = $SplitName[0]
    $Name = $SplitName[1]
    $Version = $SplitName[2]
    $PkgType = $SplitName[3]
    $Description = $SplitName[4]
    $QueryType = $SplitName[5]
    $CustomGroup = $SplitName[6]
    $PackageName = "$Name $Version"
    $SourceFolder = $_
    Start-Transcript -Path "\\usc.internal\usc\appdev\General\Logs\AppImport-$PackageName.log"
    #Verify Name
    If (-Not $Publisher) {
        Write-Host "Please specify a valid publisher"
        return
    }
    If (-Not $Name) {
        Write-Host "Please specify a valid Name"
        return
    }
    Switch ($PkgType) {
        APPV {}
        MSI {}
        EXE {}
        VBS {}
        PS1 {}
        default { 
            Write-Host "Please specify a valid Package Type"
            return
        }
    }

    Switch ($Description) {
        Site {}
        Open {}
        Restricted {}
        default {
            Write-Host "Please specify a valid Package Type"
            return
        }
    }
    Write-Host "Working on $Publisher $Name $Version $QueryType"
    #Start-Sleep -Seconds 5
    #Test if source Path Exists
    $BadSource = 0
    If (!(Test-Path -Path $SourceFolder.FullName)) {
        $BadSource++
        Write-Host -ForegroundColor Red $SourceFolder.FullName
        return
    }
    #Does it need to be converted?
    If ((Get-ChildItem -Path $SourceFolder.FullName -Filter *.sprj) -and (!(Test-Path -Path "$($SourceFolder.FullName)\APPV5"))) {
        Write-Host -ForegroundColor Red "$Name needs to be converted first"
        Write-Host -ForegroundColor Gray "Testing for conversion support"
        If (Get-Module -List -Name AppvPkgConverter) {
            Write-Host "Package conversion tools exist, testing and converting"
            $Result = Test-AppvLegacyPackage -Path $SourceFolder.FullName
            If ($Result.information -match "no major errors") {
                Write-Host -ForegroundColor green "Package is ripe for conversion. Converting..."
                $AppV5Path = New-Item -Path $PackageRoot -Name "$($SourceFolder.Name)-APPV5" -ItemType Directory -Force
                $ConvertResult = ConvertFrom-AppvLegacyPackage -SourcePath $SourceFolder.FullName -DestinationPath $AppV5Path
                If ($ConvertResult.Errors.Count -eq 0 -and $ConvertResult.Warnings.Count -eq 0) {
                    Write-Host -ForegroundColor Green "Package Upgraded Succesfully"
                    Write-Host -ForegroundColor Cyan "Retiring old APPV4 Package"
                    Move-Item -Path $SourceFolder.FullName -Destination $RetiredRoot -Force
                    Rename-Item -Path $AppV5Path.FullName $SourceFolder.Name
                } Else {
                    Write-Host -ForegroundColor Red "Package failed, aborting"
                    $ConvertResult
                    exit 1
                }
            } Else {
                Write-Host -ForegroundColor red "Testing upgrade failed"
                return $Result.Errors
            }
        } Else {
            Write-Host -ForegroundColor Red "Packaging modules not found"
            return
        }
    }
#}
    #Create Package
    Write-Host -ForegroundColor Cyan "Checking application $Name"
    Get-ChildItem -Path $SourceFolder.FullName -Recurse | Where-Object {$_.BaseName -match ","} | ForEach-Object {Rename-Item -Path $_.FullName -NewName $_.Name.Replace(",","-")}
    Switch ($PkgType)
		{
			APPV {            
                New-AppV5Package -Source $SourceFolder -Publisher $Publisher -Name $PackageName -Version $Version -Description $Description -PackageDest $PackageDest\APPV5Packages
                If ($? -ne $True) {
                    Write-Host -ForegroundColor Red "Failed to create application"
                    return
                }
            }
            MSI {
                [xml]$AppPackageXML = (Get-ChildItem -Path $SourceFolder.FullName -Filter *.apppackage | ForEach-Object {Get-Content -Path $_.FullName})
                If ($AppPackageXML) {
                    #Found app descriptor, creating MSI Application
                    New-MSIPackage -Source $SourceFolder -Publisher $Publisher -Name $PackageName -Version $Version -Description $Description -PackageDest $PackageDest\MSI -Descriptor $AppPackageXML
                    If ($? -ne $True) {
                        Write-Host -ForegroundColor Red "Failed to create application"
                        return
                    }
                } Else {
                    Write-Host -ForegroundColor Red "XML file application descriptor .apppackage not found."
                    return
                }
            }
        }
                
    Start-Sleep -Seconds 10
    Set-Location SC1:\
    $QueryType -split "," | ForEach-Object {
        $CollectionName = "$Publisher $Name $Version $PkgType $_"
        $UninstallCollectionName = "$Publisher $Name $Version $PkgType $_-Uninstall"
        Write-Host -ForegroundColor Cyan "Checking collection $CollectionName"
        #Create Collection
        New-Collection -Type $_ -ColName $CollectionName
        Write-Host -ForegroundColor Cyan "Sleeping..."
        Start-Sleep -Seconds 10
        #Create Each Deployment
        Write-Host -ForegroundColor Cyan "Checking deployment"
        Try {
            Start-CMContentDistribution -Application (Get-CMApplication -Name $PackageName) -DistributionPointGroupName "Full Site" -EA SilentlyContinue
        } Catch {
            Write-Host "Content distribution failed. Might already be distributed"
        }
        Write-Host -ForegroundColor Cyan "Sleeping..."
        Start-Sleep -Seconds 10
        Write-Host -ForegroundColor Green "Distributed content for $PackageName"
        $Deployment = Get-CMDeployment -CollectionName $CollectionName
        If (!$Deployment) {
            Write-Host -ForegroundColor Cyan "Creating deployment of $PackageName to $CollectionName"
            Start-CMApplicationDeployment -CollectionName $CollectionName -Comment "SD_" -DeployAction Install -DeployPurpose Required -Name $PackageName -UserNotification HideAll -OverrideServiceWindow $True -TimeBaseOn LocalTime
            Write-Host -ForegroundColor Green "Created Deployment for $Name"
        }
    }
    Set-Location c:
    Write-Host -ForegroundColor Cyan "Moving source files to complete folder."
    If (Test-Path -Path "$CompletedRoot\$($SourceFolder.Name)") {
        #Package previously completed. Lets rename the old one
        Rename-Item -Path "$CompletedRoot\$($SourceFolder.Name)" -NewName "$($SourceFolder.Name)_Renamed_Duplicate"
    }
    Move-Item $SourceFolder.FullName $CompletedRoot -Force
    Stop-Transcript
}