Get-ChildItem -Exclude 'settings.json' | %{
    Copy-Item $_.FullName 'C:\Users\jpharris\OneDrive - University of the Sunshine Coast\Powershell\AppVAutomation\Orchestration\' -Recurse -Force
}