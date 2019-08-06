$OrchestrationDir = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath Orchestration)
$FunctionsDir = (Join-Path $OrchestrationDir -ChildPath "Functions")
$InstallFunctions = (Join-Path -Path $FunctionsDir -ChildPath "InstallFunctions.psm1")

Get-Module InstallFunctions | Remove-Module
Import-Module $InstallFunctions -Force
Import-Module Pester

$TestPackageName =  'VideoLAN_VLC Media Player__APPV_Open_WKS,USR'
$TestPackageProperties = @{
    Settings = @{
        PackageName = $TestPackageName
        PackageSource = "C:\PackageSource"
        PackageQueue = "C:\PackageQueue"
        PackageDest = "C:\PackageDest"
    }
    URL = 'http://download.videolan.org/pub/videolan/vlc'
    InstallScript = 'Nothing'
    URLFunction = 'Get-VLCDownloadLink -Type MSI'
}

Mock -ModuleName InstallFunctions Import-Settings {
    return @{
        PackageDest = 'PackageDest'
        PackageName = 'VideoLAN_VLC Media Player__APPV_Open_WKS,USR' 
    }
}

Describe "Import-Settings" {
    Context "Import-Settings is mocked" {
        It "imports settings" {
            Mock Import-Settings {
                $TestPackageProperties.Settings
            }
            $Settings = Import-Settings
            Assert-MockCalled Import-Settings -Times 1
            $Settings.PackageDest | Should -BeExactly `
                $TestPackageProperties.Settings.PackageDest
        }
    }
}

Describe "Get-DestDir" {
    Context "Import settings mocked to testpackageproperties" {

        $DestDir = Get-DestDir
        It "calls Import Settings" {
            Assert-MockCalled -ModuleName InstallFunctions Import-Settings `
                -Times 1
        }

        It "returns packagedest directory" {
            $DestDir | Should -Be "PackageDest"
        }
    }
}

Describe "Get-PackageDestDir" {
    Context "When PackageType is APPV" {

        $PackageDestDir = Get-PackageDestDir -PackageType APPV

        It "makes a call to import-settings" {
            Assert-MockCalled -ModuleName InstallFunctions `
                Import-Settings -Times 1
        }

        It "returns a full path to where APPV packages end up" {
            $PackageDestDir | Should -Match 'PackageDest(/|\\)APPV5Packages'
        } 
    }
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
            Assert-MockCalled Import-Settings -Times 1 -ModuleName InstallFunctions
            Assert-MockCalled Get-ChildItem -Times 1 -ModuleName InstallFunctions
        }
        It "returns the latest package version" {

            Get-LatestVersionFromPackages -PackageName $TestPackageName |
            Should Be ([Version]'2.8.4')

        }
    }
}

Describe "New-PackageDirAndFilter" {
    Context "Mock Import-Settings to return fake settings" {

        It "returns a hashtable for splatting at gci" {
            $Result = New-PackageDirAndFilter -PackageName $TestPackageName
            $Result.Filter | Should -Be 'VideoLAN_VLC Media Player_*'
            $Result.Path | Should -BeExactly (
                    Join-Path "PackageDest" -ChildPath 'APPV5Packages'
            )
        }
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
        Mock -ModuleName InstallFunctions Join-Path {return "fake.file"}
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

Describe "Start-VMSequencer" {
    Context 'PackageName is null' {
        It "Should return without doing anything when nothing in pipeline" {
            $null | Start-VMSequencer | Should -BeExactly $null
        }
    }
}
