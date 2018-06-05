Param($VM)
function Get-VM {
Param([Parameter(Mandatory=$True)]$ComputerName,$VMName)

    If ($VMName) { 
        Get-WMIObject -ComputerName $ComputerName -Namespace root\virtualization\v2 -Class msvm_computersystem -Filter "ElementName = '$VMName'"| Select-Object -Property @{label='VMName';expression={$_.ElementName}},@{label='VMID';expression={$_.Name}}
    } Else {
        Get-WMIObject -ComputerName $ComputerName -Namespace root\virtualization\v2 -Class msvm_computersystem | Select-Object -Property @{label='VMName';expression={$_.ElementName}},@{label='VMID';expression={$_.Name}}
    }
}

$ErrorActionPreference = "Stop"
If (!(Test-WSMan -ComputerName $VM.ComputerName)) {
        Write-Error "Could not connect to WMF on $VM.ComputerName"
        exit 1
}

#Check if running and stop if so
Invoke-Command -ComputerName $VM.ComputerName -ScriptBlock {Param($VM) If ((Get-VM $VM.VMName).State -eq "Running") {Stop-VM $VM.VMName -Force} } -ArgumentList $VM
#Now Delete
Invoke-Command -ComputerName $VM.ComputerName -ScriptBlock {Param($VM) Remove-VM $VM.VMName -Force} -ArgumentList $VM
#Remove Contents
Invoke-Command -ComputerName $VM.ComputerName -ScriptBlock {Param($VM) $VMPath = Split-Path -Path $VM.Path -Parent; Remove-Item -Path $VMPath -Recurse -Force} -ArgumentList $VM