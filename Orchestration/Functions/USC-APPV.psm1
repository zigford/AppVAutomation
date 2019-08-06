function Set-AppvXML{
[CmdletBinding()]
Param($Path,
    [ValidateSet(
        "User",
        "Machine",
        "All"
    )]$Target,
    [switch]$DisableObjects,
    [switch]$StripComments,
    [switch]$SetIconsToEXE,
    [switch]$Test
)

    $Filter = Switch ($Target) {
        User {'*UserConfig.xml'}
        Machine {'*DeploymentConfig.xml'}
        Default {'*Config.xml'}
    }

    #Find XML
    Get-ChildItem -Path $Path -Filter $Filter | ForEach-Object {
        $XML = [xml](Get-Content $_.FullName -Raw)
        If ($XML.DeploymentConfiguration) {
            $WorkingXML = $XML.DeploymentConfiguration
        } else {
            $WorkingXML = $XML
        }
        If ($DisableObjects) {
            $WorkingXML.UserConfiguration.Subsystems.Objects.Enabled = 'false'
        }
        If ($StripComments) {
            $Comments = $XML.SelectNodes("//comments()")
            $Comments | ForEach-Object {$_.ParentNode.RemoveChild($_)}
        }
        If ($SetIconsToEXE) {
            ForEach ($Extension in $WorkingXML.UserConfiguration.Subsystems.Shortcuts.Extensions.Extension) {
                $Extension.Shortcut.Icon = $Extension.Shortcut.Target
            }
        }
        If ($Test) {
            $XML
        } else {
            $XML.Save($_.FullName)
        }
    }
}
