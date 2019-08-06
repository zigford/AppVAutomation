[CmdLetBinding(SupportsShouldProcess)]
Param()
#VLC
#Check for new versions of VLC.
#
#1. Get old versions
#2. Compare with current version
#3. Queue package as nessecary
# Settings
# PackageDest = Where packages end up in production. We scan this location
#     to see if we have the latest
# PackageSource = A UNC Path where the package will be uploaded to for
#     processing after either sequencing or downloading
# PackageQueue = A filepath (local or remote), where a sequencer script
#     should be deposited for processing. This tells the sequencer how
#     to make the package and is the primary responsibility of this script
# PackageName = Vendor_Application_Latest_APPV_WKS. Used to help determine 
#     resulting package name, and find if a previous version already
#     exists, or if the current version is still the latest
#
#     
Import-Module "$PSScriptRoot\..\..\Functions\InstallFunctions.psm1" `
    -Verbose:$False
Import-Settings | Set-Variable Settings
$PackageProperties = @{
    Settings = $Settings
    InstallScript = 
@'
start /wait msiexec.exe /I "<DLFILE>" /qb REBOOT=REALLYSUPPRESS'
del "C:\Users\Public\Desktop\VLC media player.lnk"
'@
    <# FixList = "DisableObjects" -- Example #>
    <# PreReq = 'notepad.exe' -- Example #>
    URL = 'http://download.videolan.org/pub/videolan/vlc'
    URLFunction = 'Get-VLCDownloadLink -Type MSI'
}

$PackageProperties | Select-NewerPackageVersion | New-SequencerScript |
Start-VMSequencer

Remove-Module InstallFunctions
