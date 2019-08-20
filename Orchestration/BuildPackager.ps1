[CmdletBinding()]
Param($VMHost = 'appdev5',
  $VMName = 'AutoSequencer',
  $SoftwareSource = '\\usc.internal\usc\appdev',
  $WSUSServer = 'http://appdev3:8530',
  $MDTPackage = "$SoftwareSource\OSBuildUtilities\MDT\2013\Toolkit",
  $RAM = 2Gb,
  $DiskSize = 60Gb,
  $ScriptHost = $env:computername,
  $PackageName,
  [ValidateSet(1,2)]$Generation = 2,
  [ValidateSet("Windows10","Windows7")]$BaseOS = 'Windows10'
)

# Initialize variables and paths
$Working = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$FunctionsPath = (Join-Path -Path $PSScriptRoot -ChildPath Functions)
Import-Module (Join-Path -Path $FunctionsPath -ChildPath "InstallFunctions.psm1")
Import-Settings | Set-Variable Settings
$PackageScript = Join-Path -Path $Settings.PackageQueue -ChildPath "${PackageName}.ps1"

# Validation Code
# Test the ScriptHost. If the Script host is not a VM, only Gen2 VM will be available. If Windows7 is Selected. This will result in an error.

Write-Verbose "Running Building Packager Machine script"
$SystemModel = Get-WmiObject -Class Win32_ComputerSystem
If (( $SystemModel.Model -ne 'Virtual Machine') -and ($Generation -eq 1 ) -or $BaseOS -eq "Windows7") {
    Write-Error "Script must be run from a Virtual machine to create the Floppy for Generation 1 or Windows 7 OS" -Category DeviceError
} 
##########################
# Definitions
. "$Working\MachineOrchestration.ps1"
#
##########################

#######Script Part########
# 1. Check if VM Exists  #
# 2. 
If ($VMHost -eq $env:computername) {$SelfHost = $True}
#$Credentials = Get-Credential
$ErrorActionPreference = "Stop"
If (!$SelfHost -and (!(Test-WSMan -ComputerName $VMHost))) { 
    Write-Error "Could not connect to WMF on $VMHost"
    exit 1
}
$AutoSequencer = Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($VMName) Get-VM -VMName $VMName -ErrorAction SilentlyContinue} -ArgumentList $VMName
If ($AutoSequencer) {
    $Machine = $AutoSequencer
    Write-Verbose "Found existing VM. Checking for Snapshots"
    #"Machine Exists"
    #Find the latest snapshot and revert to it to build packages.
    $LastSnapshot = (Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($VMName,$CheckpointName) Get-VMSnapshot -VMName $VMName } -ArgumentList $VMName | Select -Last 1).Name
    If (-Not $LastSnapshot) {
        $ErrorMessage = 'There was a problem retrieving snapshots'
        Write-Output $ErrorMessage
        Write-Error $ErrorMessage
    } Else {
        Write-Verbose "Found snapshot $LastSnapshot, reverting"
        #Reverting to a snapshot. We may have to create another snapshot later. So lets check the datestamp of the Checkpoint file
        Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($VMName,$CheckpointName) Restore-VMSnapshot -VMName $VMName -Name $CheckpointName -Confirm:$false} -ArgumentList $VMName,$LastSnapshot
        Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($VMName) If ((Get-VM $VMName).State -eq "Running") {Restart-VM $VMName -Force} Else { Start-VM $VMName }} -ArgumentList $VMName
    }
} Else {
    Write-Verbose "Creating new machine"
    #"Lets create the machine"    
    #Build Script Block
    #Find Free Space
    $DestinationLogicalDrive = Invoke-Command -ComputerName $VMHost -ScriptBlock {Get-WMIObject -Class Win32_LogicalDisk | Sort-Object -Property FreeSpace -Descending | Select-Object -First 1}
    $SEQVM = Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($DestinationLogicalDrive,$VMName) Test-Path -Path "$($DestinationLogicalDrive.DeviceID)\$VMName"} -ArgumentList $DestinationLogicalDrive,$VMName
    If ($SEQVM) {
        $MachineName = $SEQVM.Name
        $MachinePath = $SEQVM.FullName
    } Else {
        $MachineName = $VMName
        $MachinePath = "$($DestinationLogicalDrive.DeviceID)\$VMName"
    }

    $VHDXPath = "$MachinePath\$MachineName.vhdx"
    $UNCMachinePath = "\\$VMHost\$($DestinationLogicalDrive.DeviceID.TrimEnd(':'))$\$VMName\"
    $UNCVHDXPath = "$UNCMachinePath\$MachineName.vhdx"
    #Test Generation
    If ($Generation -eq 1) {
        $VFDPath = "$MachinePath\$MachineName.vfd"
        $NewFloppy={
        Param($ScriptHostVM,$VMName)
            $VFDPath = "$($ScriptHostVM.Path)\$VMName.vfd"
            If (!(Test-Path $VFDPath)) { $NewVHDResult = New-vfd -Path $VFDPath } Else {
                #Lets check if the VFD is in user:
                #Is there a VM in MachinePath?
                If (Get-VMFloppyDiskDrive $ScriptHostVM.VMName) {
                    #Yes it is mounted, unmount
                    Set-VMFloppyDiskDrive $ScriptHostVM.VMName $null
                }
            }
            Set-VMFloppyDiskDrive $ScriptHostVM.VMName $VFDPath
        }

        Write-Verbose "VMName is $VMName"
        Write-Verbose "Machine path is $MachinePath"
        Write-Verbose "Creating new floppy at $VFDPath on host $ScriptHostVM"
        #Here we have to create and mount the floppy file to the machine running the script which could be on a different host
        Write-Verbose "Finding script host machine"
        $ScriptHostVM = Find-VM -VMName $ScriptHost -VMHost $VMHost
        Write-Verbose "Now we create and mount the floppy on that host"
        Invoke-Command -ComputerName $ScriptHostVM.ComputerName -ScriptBlock $NewFloppy -ArgumentList $ScriptHostVM,$VMName

    
       <# #Lets get a UNC Path to the $VFDPath
        Write-Verbose "ScriptHost found on $($ScriptHostVM.ComputerName)"

        If (Test-Path -Path $UNCVFD) {
            Write-Verbose "Floppy found at $UNCVFD"
        } Else {
            Write-Error "Could not find floppy at $UNCVFD"
            return
        }
        #Lets attach the floppy here
        Write-Verbose "Attaching Floppy"
        Invoke-Command -ComputerName $ScriptHostVM.ComputerName -ScriptBlock $AttachFloppy -ArgumentList $ScriptHost,$UNCVFD
        #>
        $FormatOutput = Start-Process -Wait -FilePath format.com -ArgumentList 'A: /v:unattend /q /y'
        Write-Output $FormatOutput.StandardOutput
        Start-Sleep -Seconds 5
        New-Item -Path A:\ -Name AutoUnattend.xml -ItemType file -Value $Unattend
        New-Item -Path A:\ -Name init.bat -ItemType file -Value $Init
        #Copy-Item -path \\usc.internal\usc\appdev\OSBuildUtilities\Untitled-hyper.xml A:\Autounattend.xml
        #Copy-Item -path \\usc.internal\usc\appdev\OSBuildUtilities\init.bat A:\
        #Now we are unmounting the floppy
        Write-Verbose "Unmounting floppy"
        Invoke-Command -ComputerName $ScriptHostVM.ComputerName -ScriptBlock {Param($ScriptHost) Set-VMFloppyDiskDrive $ScriptHost -Path $null } -ArgumentList $ScriptHost
        #Now we have to copy the floppy over via UNC
        $SourceVFDSplit = $ScriptHostVM.Path.Split(':')
        $SourceVFD = "\\$($ScriptHostVM.ComputerName)\$($SourceVFDSplit[0])$" + "$($SourceVFDSplit[1])\$VMName.vfd"
    } Else {
        Import-Module $Working\Convert-WindowsImage.ps1
        #Write Unattend file:
        $UnattendFile = "$UNCMachinePath\Unattend.xml"
        Get-Unattend -BaseOS $BaseOS | Out-File $UnattendFile
        Convert-WindowsImage -SourcePath (Get-ISO -BaseOS $BaseOS) -Edition Enterprise -VHDPath $UNCVHDXPath -SizeBytes $DiskSize -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -UnattendPath $UnattendFile
        #Gen 2
    }

    $NewVM={
    Param($MachineName,$RAM,$VHDXPath,$DiskSize,$MachinePath,$Generation)
        New-VM -Name $MachineName -MemoryStartupBytes $RAM -BootDevice CD -SwitchName bridged -NewVHDPath $VHDXPath -NewVHDSizeBytes $DiskSize -Path $MachinePath -Generation $Generation
        }
    If (!(Get-PATVM -ComputerName $VMHost -VMName $MachineName)) {
        #Create the VM
        $NewVMObject = Invoke-Command -ComputerName $VMHost -ScriptBlock $NewVM -ArgumentList $MachineName,$RAM,$VHDXPath,$DiskSize,$MachinePath
    }
    Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($VMName) Set-VM -Name $VMName -ProcessorCount 4 -DynamicMemory } -ArgumentList $VMName
    #Copy in and add the floppy disc for booting

    If ((Test-Path -Path $SourceVFD) -and $Generation -eq 1)  {
        Write-Verbose "Found floppy at $SourceVFD. Attempting Copy to $UNCMachinePath"
        $VFDCopy = Copy-Item -Path $SourceVFD -Destination $UNCMachinePath -PassThru -Force -EA SilentlyContinue
        If ($VFDCopy) {
            Write-Verbose "Successfully copied vfd to $UNCMachinePath"
            Remove-Item -Path $SourceVFD
        } Else {
            Write-Error "Failed to copy to $UNCMachinePath"
        }
    Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($MachineName,$VFDPath) Set-VMFloppyDiskDrive $MachineName $VFDPath } -ArgumentList $MachineName,$VFDPath
    Write-Verbose "ISO Destination path $UNCMachinePath"
    $ISO = Copy-Item -Path $PathToISO -Destination $UNCMachinePath -PassThru -Force
    Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($MachineName,$MachinePath,$ISO) Set-VMDvdDrive $MachineName -ControllerNumber 1 -controllerLocation 0 -Path "$MachinePath\$($ISO.Name)" } -ArgumentList $MachineName,$MachinePath,$ISO
    }
    #Add the ISO for builing
    #Lets Plant the ISO into the machine path
    #First Convert the Machinepath into a UNC path
    #Start or restart
    Invoke-Command -ComputerName $VMHost -ScriptBlock {Param($MachineName) If ((Get-VM $MachineName).State -eq "Running") {Restart-VM $MachineName -Force} Else { Start-VM $MachineName }} -ArgumentList $MachineName
    $Machine = $NewVMObject
    #Lets wait for the machine to build and then snapshot it.
    $Waiting = 0
    Do {
        Start-Sleep -Seconds 120
        $Waiting = $Waiting + 2
        Write-Verbose "Waiting for checkpoint file $Waiting minutes..."
    } 
    While ((! (Test-Path -Path "$SoftwareSource\General\Packaging\$VMName.Checkpoint")) -and (! (Test-Path -Path "$SoftwareSource\General\Packaging\$VMName.SkipCheckpoint")))
    If (Test-Path -Path "$SoftwareSource\General\Packaging\$VMName.Checkpoint") {
        If ($LastSnapshot) {
            $NewSnapshotName = "$($VMName)-$([Int]($LastSnapshot.Split('-')[1])+1)"
        } Else {
            $NewSnapshotName = "$VMName-1"
        }
        Write-Verbose "Shutting down VM for snapshot"
        Invoke-Command $VMHost -ScriptBlock {Param($VMName) Stop-VM -Name $VMName} -ArgumentList $VMName
        Start-Sleep -Seconds 15
        Write-Verbose "Creating Checkpoint $NewSnapshotName"
        Invoke-Command $VMHost -ScriptBlock {Param($VMName,$NewSnapshotName) Checkpoint-VM -Name $VMName -SnapshotName $NewSnapshotName} -ArgumentList $VMName,$NewSnapshotName
        Remove-Item -Path "$SoftwareSource\General\Packaging\$VMName.Checkpoint"
    } ElseIf (Test-Path -Path "$SoftwareSource\General\Packaging\$VMName.SkipCheckpoint") {
        Write-Verbose "New checkpoint not needed. Skipping"
        Remove-Item -Path "$SoftwareSource\General\Packaging\$VMName.SkipCheckpoint"
    }
}

Do {
    Write-Verbose "Waiting for $PackageName to be built..."
    Start-Sleep -Seconds 20
} While (Test-Path -Path $PackageScript)

Write-Verbose "Package $PackageName complete"
Send-EmailMessage -Message "$PackageName has been AutoSequenced! Check the logs at General\Logs\PackageOrchestrator.log" -EmailAddress '3b7f44bd.usceduau.onmicrosoft.com@apac.teams.ms' -Subject "$PackageName"

return $Machine