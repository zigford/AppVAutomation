$OrchestrationDir = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath Orchestration)
$FunctionsDir = (Join-Path $OrchestrationDir -ChildPath "Functions")
$InstallFunctions = (Join-Path -Path $FunctionsDir -ChildPath "InstallFunctions.psm1")

Import-Module $InstallFunctions
Import-Module Pester

$TestPackageName =  'VideoLAN_VLC Media Player__APPV_Open_WKS,USR'

Describe "Get-LatestVersionFromPackages" {
    Context "Get-ChildItem mocked to return some package folder names" {

        Mock -ModuleName InstallFunctions Get-ChildItem {
            @(
                'VideoLAN_VLC Media Player_2.4.1_APPV_Open_WKS,USR', 
                'VideoLAN_VLC Media Player_2.8.4_APPV_Open_WKS,USR' |
                ForEach-Object { New-Object System.IO.DirectoryInfo($_) }
            )
        }

        It "reads a directory of packages" {

            Get-LatestVersionFromPackages -PackageName $TestPackageName

            Assert-MockCalled Get-ChildItem -Times 1 -ModuleName InstallFunctions
        }
        It "returns the latest package version" {

            Get-LatestVersionFromPackages -PackageName $TestPackageName |
            Should Be ([Version]'2.8.4')

        }
    }
}

Describe "New-PackageDirFilter" {
    It "transforms a packge name to a filter to find all package versions" {
        New-PackageDirFilter -PackageName $TestPackageName |
        Should be 'VideoLAN_VLC Media Player_*'
    }
}

Remove-Module InstallFunctions
