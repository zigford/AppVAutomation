$OrchestrationDir = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath Orchestration)
$FunctionsDir = (Join-Path $OrchestrationDir -ChildPath "Functions")
$InstallFunctions = (Join-Path -Path $FunctionsDir -ChildPath "InstallFunctions.psm1")

Import-Module $InstallFunctions
Import-Module Pester

$TestPackageName =  'VideoLAN_VLC Media Player__APPV_Open_WKS,USR'
$TestPackageProperties = @{
    Settings = @{
        PackageName = 'VideoLAN_VLC Media Player__APPV_Open_WKS,USR'
        PackageSource = "${env:temp}\PackageSource"
        PackageQueue = "${env:temp}\PackageQueue"
    }
    URL = 'http://download.videolan.org/pub/videolan/vlc'
    InstallScript = 'Nothing'
    URLFunction = 'Get-VLCDownloadLink -Type MSI'
}

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

Describe "Select-NewerPackageVersion" {

    Context "Get-ChildItem mocked to return older package folder names" {

        Mock -ModuleName InstallFunctions Get-ChildItem {
            @(
                'VideoLAN_VLC Media Player_2.4.1_APPV_Open_WKS,USR', 
                'VideoLAN_VLC Media Player_2.8.4_APPV_Open_WKS,USR' |
                ForEach-Object { New-Object System.IO.DirectoryInfo($_) }
            )
        }

        It "Selects package when available online is newer" {
            Select-NewerPackageVersion $TestPackageProperties | Should BeExactly $TestPackageProperties
        }
    }

    Context "Get-ChildItem mocked to return newer package folder names" {

        Mock -ModuleName InstallFunctions Get-ChildItem {
            @(
                'VideoLAN_VLC Media Player_2.4.1_APPV_Open_WKS,USR', 
                'VideoLAN_VLC Media Player_4.2.8_APPV_Open_WKS,USR', 
                'VideoLAN_VLC Media Player_2.8.4_APPV_Open_WKS,USR' |
                ForEach-Object { New-Object System.IO.DirectoryInfo($_) }
            )
        }

        It "Does not select package available online is older" {
            Select-NewerPackageVersion $TestPackageProperties | Should BeExactly $null
        }
    }
}

Describe "New-SequencerScript" {
    Context 'Properties is $null' {
        It "Should return without doing anything when nothing in the pipeline" {
            $null | New-SequencerScript | Should BeExactly $null
        }
    }
    Context 'Properties is a valid package properties' {
        Mock -ModuleName InstallFunctions New-Item {}
        Mock -ModuleName InstallFunctions Out-File {}
        Mock -ModuleName InstallFunctions Invoke-WebRequest {}
        Mock -ModuleName InstallFunctions Get-Item {([System.IO.FileInfo]'file.exe')}
        It "returns a package name for the sequencer to begin sequencing" {

            $TestPackageProperties | New-SequencerScript |
            Should -BeLike 'VideoLAN_VLC Media Player_*_APPV_Open_WKS,USR'

            Assert-MockCalled New-Item -Times 2 -ModuleName InstallFunctions
            Assert-MockCalled Invoke-WebRequest -Times 1 -ModuleName InstallFunctions
        }

    }
        
}


Remove-Module InstallFunctions
