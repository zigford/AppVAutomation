#[CmdLetBinding()]
#Param()

########################
#Setuping enviironments#
#and Variables         #
########################
#Dot Source Queries and functions
Set-Location $env:SystemDrive
. $PSScriptRoot\SMSFunction.ps1
. $PSScriptRoot\Orchestration\Functions\Send-EmailMessage.ps1
If (Test-Path -Path 'D:\Program Files') {
    $ProgramFiles = 'D:\Program Files'
} ElseIf (Test-Path -Path 'C:\Program Files (x86)') {
    $ProgramFiles = 'C:\Program Files (x86)'
} Else {
    $ProgramFiles = 'C:\Program Files'
}
$InstallDir = "$ProgramFiles\Microsoft Configuration Manager"
$ConfigMgrModules = "$InstallDir\AdminConsole\bin\ConfigurationManager.psd1"
$LogDir = "\\usc.internal\usc\appdev\General\Logs"
Import-Module $ConfigMgrModules
$ErrorActionPreference = "Stop"
$SiteCode = 'SC1'
$SiteServer = 'wsp-configmgr01.usc.internal'
#Setup PSDrive
If (-Not (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer
}
$PackageRoot = "\\usc.internal\usc\appdev\General\Packaging\SourcePackages"
$PackageDest = "\\usc.internal\usc\appdev\SCCMPackages"
$CompletedRoot = "\\usc.internal\usc\appdev\General\Packaging\CompletedPackages"
$RetiredRoot = "\\usc.internal\usc\appdev\General\Packaging\RetiredPackages"

#Select all packages to be imported
Get-ChildItem -Path $PackageRoot | Where-Object {
    Get-ChildItem -Path $_.FullName `
        -Include @("*.sprj","*.appv","*.apppackage") `
        -Recurse
} | ForEach-Object {

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
    Start-Transcript -Path "$LogDir\$PackageName.log"
    #Verify Name
    If (-Not $Publisher) {
        Write-Error "Please specify a valid publisher"
        return
    }
    If (-Not $Name) {
        Write-Error "Please specify a valid Name"
        return
    }
    Switch ($PkgType) {
        APPV {}
        MSI {}
        EXE {}
        VBS {}
        PS1 {}
        default {
            Write-Error "Please specify a valid Package Type"
            return
        }
    }

    Switch ($Description) {
        Site { $Target = 'AllMachines' }
        Open { $Target = 'AllMachines' }
        Restricted { $Target = 'StaffApproval' }
        default {
            Write-Error "Please specify a valid Package Type"
            return
        }
    }
    Write-Output "Working on $Publisher $Name $Version"
    #Start-Sleep -Seconds 5
    #Test if source Path Exists
    $BadSource = 0
    If (!(Test-Path -Path $SourceFolder.FullName)) {
        $BadSource++
        Write-Error $SourceFolder.FullName
        return
    }
    #Create Package
    Write-Information "Checking application $Name"
    Get-ChildItem -Path $SourceFolder.FullName -Recurse | Where-Object {$_.BaseName -match ","} | ForEach-Object {Rename-Item -Path $_.FullName -NewName $_.Name.Replace(",","-")}
    Switch ($PkgType)
		{
			APPV {            
                New-AppV5Package -Source $SourceFolder -Publisher $Publisher -Name $Name -Version $Version -Description $Description -PackageDest $PackageDest\APPV5Packages
                If ($? -ne $True) {
                    Write-Error "Failed to create application"
                    return
                }
            }
            MSI {
                [xml]$AppPackageXML = (Get-ChildItem -Path $SourceFolder.FullName -Filter *.apppackage | ForEach-Object {Get-Content -Path $_.FullName})
                If ($AppPackageXML) {
                    #Found app descriptor, creating MSI Application
                    New-MSIPackage -Source $SourceFolder -Publisher $Publisher -Name $Name -Version $Version -Description $Description -PackageDest $PackageDest\MSI -Descriptor $AppPackageXML
                    If ($? -ne $True) {
                        Write-Error "Failed to create application"
                        return
                    }
                } Else {
                    return
                }
            } Else {
                Write-Error "XML file .apppackage not found."
                return
            }
            Default {
                [xml]$AppPackageXML = (Get-ChildItem -Path $SourceFolder.FullName -Filter *.apppackage | ForEach-Object {Get-Content -Path $_.FullName})
                If ($AppPackageXML) {
                    #Found app descriptor, creating Custom Application
                    New-CustomPackage -Source $SourceFolder -Publisher $Publisher -Name $Name -Version $Version -Description $Description -PackageType $_ `
                        -PackageDest $PackageDest -Descriptor $AppPackageXML
                    If ($? -ne $True) {
                        Write-Error "Failed to create application"
                        return
                    }
                } Else {
                    return
                }
            } Else {
                Write-Error "XML file .apppackage not found."
                return
            }
        }
    }
    Start-Sleep -Seconds 10
    Set-Location SC1:\

    #region ContentDistribution
    Try {
        Start-CMContentDistribution -Application (Get-CMApplication -Name $PackageName) -DistributionPointGroupName "Full Site" -EA SilentlyContinue
    } Catch {
        Write-Warning "Content distribution failed. Might already be distributed"
    }
    Write-Output "Sleeping..."
    Start-Sleep -Seconds 10
    Write-Output "Distributed content for $PackageName"
    #endregion

    #region CreateDeploymentSettings

    function New-DeployHT {
        @{
            Name = $PackageName
            CollectionName = "All USC Windows 10 Devices"
            ApprovalRequired = $False
            DeployAction = 'Install'
            Comment = "JPH - Scripted"
            DeployPurpose = 'Available'
            UserNotification = 'DisplayAll'
            OverrideServiceWindow = $True
            TimeBaseOn = 'LocalTime'
            AvailableDateTime = (Get-Date).AddDays(14)
            DeadlineDateTime = (Get-Date).AddDays(28)
        }
    }
    Write-Output "Checking collections"
    Switch ($Target) {
        AllMachines {
            $DeploymentSettings = (New-DeployHT),(New-DeployHT)
            $DeploymentSettings[0].CollectionName = "$Publisher $Name Pilot Machines"
            $DeploymentSettings[0].AvailableDateTime = (Get-Date)
            $DeploymentSettings[0].DeadlineDateTime = (Get-Date).AddDays(7)
            $DeploymentType = 'WKS'
        }
        StaffApproval {
            $DeploymentSettings = (New-DeployHT),(New-DeployHT)
            $DeploymentSettings[0].CollectionName = "$Publisher $Name Pilot Users"
            $DeploymentSettings[0].AvailableDateTime = (Get-Date)
            $DeploymentSettings[0].DeadlineDateTime = (Get-Date).AddDays(7)
            $DeploymentSettings[1].CollectionName = "All USC Staff Users"
            $DeploymentSettings[1].ApprovalRequired = $True
            $DeploymentType = 'USR'
        }
    } 

    #endreion

    #region CreateCollection

    New-Collection -Type $DeploymentType -ColName $DeploymentSettings[0].CollectionName # Createh pilot collection
    Write-Verbose "Sleeping..."
    Start-Sleep -Seconds 10

    #endregion

    #region CreateDeployments

    # Package Deployment Code
    # Create Each Deployment
    Write-Verbose "Checking deployment"
    $DeploymentSettings | ForEach-Object {
        $CollectionName = $psItem.CollectionName
        $Deployment = Get-CMDeployment -CollectionName $CollectionName -SoftwareName $PackageName
        If (!$Deployment) {
            New-CMApplicationDeployment @psItem 
            Write-Verbose "Creating deployment of $($psItem.Name) to $CollName"
            Write-Verbose "Created Deployment for $($psItem.Name)"
        }

    }
    #endregion

    Set-Location c:
    Write-Verbose "Moving source files to complete folder."
    If (Test-Path -Path "$CompletedRoot\$($SourceFolder.Name)") {
        #Package previously completed. Lets rename the old one
        Rename-Item -Path "$CompletedRoot\$($SourceFolder.Name)" -NewName "$($SourceFolder.Name)_Renamed_Duplicate"
    }
    Move-Item $SourceFolder.FullName $CompletedRoot -Force
    Send-EmailMessage -Message "$Publisher $Name $Version has been auto imported to SCCM! Check the logs at General\Logs\PackageOrchestrator.log" -EmailAddress '3b7f44bd.usceduau.onmicrosoft.com@apac.teams.ms' -Subject "$Name $Version"
    Stop-Transcript
}