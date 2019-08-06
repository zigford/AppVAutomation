[CmdLetBinding()]
Param($File)

$Destination = 'C:\Users\jpharris\OneDrive - University of the Sunshine Coast\Powershell\AppVAutomation\Orchestration\'

If ($File) {
    Copy-Item $File $Destination
} else {

    Get-ChildItem -Exclude 'settings.json' | %{
        Copy-Item $_.FullName $Destination -Recurse -Force
    }
}