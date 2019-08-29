Describe 'CheckPackages.ps1' {
    # Checkpackages runs other scripts relative to its invocation path.
    # The only way I could think to test was to copy CheckPackages.ps1 to Testdrive
    # and create mocks for the 3 different cases of package scripts, at the appropriate
    # relative folder locations in Testdrive.
    $RootFolder = split-path -parent $PSCommandPath | split-path -parent
    $OrchestrationRoot = "$RootFolder\Orchestration"
    $PackageCheckerCmdlet = "$OrchestrationRoot\PackageChecker.ps1"

    $Testdrive = "TestDrive:\"
    Copy-Item $PackageCheckerCmdlet $Testdrive
    New-Item -Path "$TestDrive" -Name "Packages" -ItemType "directory"
    New-Item -Path "$TestDrive" -Name "Functions" -ItemType "directory"

    function GetFullPath {
      Param(
         [string]$Path
      )
      return $Path.Replace('TestDrive:', (Get-PSDrive TestDrive).Root)
    }

    # Case 1: Packages/APPNAME containing a checkpackage.ps1 script
    New-Item -Path "$TestDrive\Packages" -Name "app1" -ItemType "directory"
    $App1TestString = "Result of app1 checkpackage"
    "write-output '$App1TestString'" > "$Testdrive\Packages\app1\checkpackage.ps1"
    It 'Runs checkpage script in any app definition folder' {
       & "$Testdrive\PackageChecker.ps1" | Should be $App1TestString
    }
    Remove-item "$Testdrive\Packages\app1\checkpackage.ps1"

    # Case 2: Packages/APPNAME contains a manifest file
    $TestManifest = GetFullPath "$($Testdrive)Packages\app1\Manifest.xml"
    write-host $TestManifest
    '<tag></tag>' > $TestManifest
    'write-output $args' > "Testdrive:\Functions\Start-ManifestProcess.ps1"
    It 'Runs checkpackage script in any app definition folder' {
      & "$Testdrive\PackageChecker.ps1" | Should be @("-Manifest", $TestManifest, "-Verbose")
    }
    Remove-item $TestManifest
    Remove-item "Testdrive:\Functions\Start-ManifestProcess.ps1"

    # Case 3: Packages/APPNAME is an executable powershell script
    $TestAppScript = GetFullPath "$($Testdrive)Packages\app1.ps1"
    'write-output $args' > $TestAppScript
    It 'Runs any standalone app script in the packages folder' {
      & "$Testdrive\PackageChecker.ps1" | Should be "-Verbose"
    }
    Remove-Item $TestAppScript

  }