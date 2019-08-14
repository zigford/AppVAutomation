<#

Each supported package needs 2 functions
1. Get-AppNameLatestVersion
   This function returns a [Version] object of the latest version
2. Get-AppNameDownloadLink
   This function returns a URL from which to download a file

#>

#region Package Makers

function New-SequencerScript {
    Param(
            [Parameter(ValueFromPipeline)]$Properties
         )
    If ($Properties -eq $Null) {return}
    $Properties['Version'] = Get-LatestVersionFromURL -URL $Properties.URL
    $PackageName = New-PackageName -Properties $Properties
    $PackageSource = $Properties.Settings.PackageSource
    $PackageQueue = $Properties.Settings.PackageQueue
    $SourcePath = Join-Path -Path $PackageQueue -ChildPath $PackageName
    New-Item -ItemType Directory $SourcePath -Force

    If ($Properties.FixList) {
        # Deposit the special module along with package source
        Copy-Item "..\..\Functions\USC-APPV.psm1" $SourcePath
        $Properties.FixList | ForEach-Object {
            $_ | Out-File -Append (Join-Path -Path $SourcePath `
                -ChildPath "FixList.txt")
        }
    }
    If ($Properties.PreReq) {
        New-Item -ItemType File -Path $SourcePath -Name "PreReq.bat" `
            -Value $Properties.PreReq -Force
    }

    If ($Properties.URLFunction) {
        $Link = Invoke-Expression $Properties.URLFunction
    } else {
        ## ToDo Implement Generic URL Downloader
    }
    $InstallFile = Get-DownloadFromLink -OutPath $SourcePath `
        -Link $Link
    $InstallScript = "cd `"%~dp0`"`n"
    $InstallScript += $Properties.InstallScript.Replace('<DLFILE>',$InstallFile.Name)
    New-Item -ItemType File -Path $SourcePath -Name "Install.bat" `
        -Value $InstallScript -Force

@"

Set-Location "`$HOME\Desktop"
New-Item -ItemType Directory -Name Source
Copy-Item -Path "$SourcePath" -Recurse Source
Set-Location Source
`$NewPackageName = "$PackageName"
If (Test-Path -Path `$NewPackageName) {
    Set-Location `$NewPackageName
}
If (Test-Path "PreReq.bat") { Start-Process -Wait -FilePath "PreReq.bat" }
`$SequencerOptions = @{
    Installer = '.\Install.bat'
    OutputPath = "`$env:USERPROFILE\Desktop"
    FullLoad = [switch]`$True
    Name = `$NewPackageName
}
`$AppVTemplate = Get-ChildItem -Filter *.appvt
If ( `$AppVTemplate ) {
    `$SequencerOptions['TemplateFilePath'] = `$(`$AppVTemplate.FullName)
}

New-AppvSequencerPackage @SequencerOptions
If (Get-ChildItem -Path "$($SequencerOptions.OutputPath)" *.appv) {
    If (Test-Path "FixList.txt") {
        Import-Module (Join-Path -Path . -ChildPath "USC-APPV.psm1")
        Get-Content "FixList.txt" | ForEach-Object {
            Start-AppVFix -Path `$PackagePath -Fix `$_
        }
    }
    Copy-Item `$env:USERPROFILE\Desktop\`$NewPackageName -Recurse "$PackageSource"
}
Remove-Item `$MyInvocation.MyCommand.Source
Remove-Item -Recurse -Force "$SourcePath"
"@ | Out-File (Join-Path -Path $PackageQueue `
    -ChildPath "$($PackageName).ps1")

    return $PackageName
}

function New-AppPackageBundle {
    <#
    .DESCRIPTION
        Downloads the required source, Produces a .apppackage manifest
        file that can be consumed by the SCCM ImportConvert System
    .SYNOPSIS
        Basicly, spit out everything needed to make and deploy a package
    .PARAMETER Properties
        A hashtable of things this function needs to know about how to
        make the package
    #>
    [CmdLetBinding()]
    Param([Parameter(ValueFromPipeline=$True)]$Properties)


}

#endregion

#region Helpers

<#
    Functions commonly used to implement a package checker
#>

function Import-Settings {
    $SettingsPath = "$(Split-Path -Path $PSScriptRoot -Parent)\settings.json"
    If (-Not (Test-Path -Path $SettingsPath)) {
        Write-Error "Unable to find $SettingsPath"
    }
    $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-JSon
    $Settings | Add-Member -MemberType NoteProperty -Name PackageName `
        -Value (Get-PackageName $MyInvocation.ScriptName)
    $Settings
}

function Get-PackageName {
    Param($ScriptName)
    #$PSScriptRoot
    #Get-Variable
    $ScriptFile = $ScriptName.Split('\')[-1]
    $ScriptDir = $ScriptName.Split('\')[-2]
    If ($ScriptFile -eq 'CheckPackage.ps1') {
        return $ScriptDir
    } else {
        return $ScriptFile.TrimEnd('\.ps1')
    }
}

function Get-OSArchitecture {
[cmdletbinding()]
param(
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$ComputerName = $env:computername
)            

begin {}            

process {            

    foreach ($Computer in $ComputerName) {
        if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {
            Write-Verbose "$Computer is online"
            $OS  = (Get-WmiObject -computername $computer -class Win32_OperatingSystem ).Caption
            if ((Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer -ea 0).OSArchitecture -eq '64-bit') {
                $architecture = "64-Bit"
            } else  {
                $architecture = "32-Bit"
            }            

            $OutputObj  = New-Object -Type PSObject
            $OutputObj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer.ToUpper()
            $OutputObj | Add-Member -MemberType NoteProperty -Name Architecture -Value $architecture
            $OutputObj | Add-Member -MemberType NoteProperty -Name OperatingSystem -Value $OS
            $OutputObj
        }
    }
}            

end {}            

}

function Get-RedirectedUrl {

    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )

    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()

    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
}

function Get-VersionFromString {
    Param($String)
    If ($String -match '(?<version>\d+\.\d+(\d+|\.)+)') {
        return [Version]$Matches['version']
    } else {
        return [Version]'0.0.0.0'
    }
}

function Get-DownloadFromLink {
    [CmdLetBinding(SupportsShouldProcess)]
    Param($Link,$OutPath,$Outfile)
    If (!$Outfile) {
        $Outfile = ($Link.Split("/") | Select -Last 1).Replace('%20',' ')
    }
    $Output = Join-Path -Path $OutPath -ChildPath $Outfile
    If (Test-Path $Output) { return (Get-Item $Output) }
    If ($PSCmdlet.ShouldProcess($Output, "Download file to")) {
        Invoke-WebRequest -Uri $Link -OutFile $Output -UseBasicParsing
        $OutFile = Get-Item -Path $Output
        If ($OutFile) {
            Write-Information "Download Success"
            return $OutFile
        } Else {
            Write-Error "Download Failed"
        }
    }
}

function Set-DefaultApp{

}

function New-PackageName {
    Param([Parameter(Mandatory=$True)]$Properties)
    $PackageName = $Properties.Settings.PackageName
    return ("{0}_{1}_{2}_{3}_{4}_{5}" -f
            (Get-AppVendor $PackageName),
            (Get-AppName $PackageName),
            $Properties.Version,
            "APPV",
            (Get-AppLicense $PackageName),
            (Get-AppTarget $PackageName)
    )
}

function Select-NewerPackageVersion {
    [CmdLetBinding()]
    Param (
        [Parameter(ValueFromPipeline=$True)]$Options
    )

    $URLVer = Get-LatestVersionFromURL $Options.URL
    $LocalVer = Get-LatestVersionFromPackages $Options.Settings.PackageName

    If ( $URLVer -gt $LocalVer) {
        Write-Verbose ("$URLVer newer than $LocalVer of {0}" -f `
            $Options.Settings.PackageName)
        return $Options
    }
}

function Get-AppVendor {
    Param($FullName)
    return $FullName.Split('_')[0]
}

function Get-AppName {
    Param($FullName)
    return $FullName.Split('_')[1]
}

function Get-AppType {
    Param($FullName)
    return $FullName.Split('_')[3]
}

function Get-AppLicense {
    Param($FullName)
    return $FullName.Split('_')[4]
}

function Get-AppTarget {
    Param($FullName)
    return $FullName.Split('_')[5]
}

function Get-DestDir {
    return (Import-Settings).PackageDest
}

function Get-PackageDestDir {
    Param($PackageType)

    $SubDir = Switch ($PackageType) {
        APPV {'APPV5Packages'}
        MSI {'MSI'}
        EXE {'EXE'}
        Script {'Script'}
    }
    $DestDir = Get-DestDir
    return Join-Path -Path $DestDir -ChildPath $SubDir
}

function New-PackageDirAndFilter {
    [CmdLetBinding()]
    Param($PackageName)

    $GCIParams = @{
        Filter = ("{0}_{1}_*" -f `
            (Get-AppVendor $PackageName),
            (Get-AppName $PackageName)
        )
        Path = Get-PackageDestDir (Get-AppType $PackageName)
    }
    return $GCIParams
}

function Get-LatestVersionFromPackages {
    [CmdLetBinding()]
    Param($PackageName)
    [array]$VerList = [Version]'0.0.0.0'
    $GCIParams = New-PackageDirAndFilter $PackageName
    Get-ChildItem @GCIParams |
    ForEach-Object {
        $VerString = $_.Name.Split('_')[2]
        If ($VerString -match '\.') {
            $VerList += New-Object System.Version ("{0:N2}" -f $VerString)
        } Else {
            $VerList += New-Object System.Version ("{0:N2}" -f [int]$VerString)
        }
    }
    $VerList | Sort-Object | Select-Object -Last 1
}

function Get-LatestVersionFromURL {
    Param(
            [Parameter(Mandatory=$True)]$URL
         )
    Invoke-WebRequest -Uri $url |
    Select-Object -ExpandProperty Links | ForEach-Object {
        [Version]$v = $null
        $s = $_.href.TrimEnd('/')
        if ([Version]::TryParse($s,[ref]$v)) {
            $v
        }
    } | Sort-Object | Select-Object -Last 1
} 

function Start-VMSequencer {
    [CmdLetBinding()]
    Param([Parameter(ValueFromPipeline=$True)]$PackageName)
    If (!$PackageName) {return}
    Write-Verbose "Running startvm sequencer for $PackageName"
    $Working = Split-Path -Path $PSScriptRoot -Parent
    & (Join-Path -Path $Working -ChildPath PackageOrchestrator.ps1) -Build -PackageName $PackageName
}

#endregion

#region FireFoxOnly

function Get-FirefoxDownloadLink {
    $LatestPath = Get-RedirectedUrl "https://download.mozilla.org/?product=firefox-latest&os=win&lang=en-US"
    return $LatestPath
}

# TODO Get-FireFoxLatestVersion

#endregion

#region JavaOnly

function Get-JavaDownloadLink {
    $LatestPath = "http://java.com/en/download/manual.jsp"
    $LatestVersion = (Invoke-WebRequest $LatestPath -UseBasicParsing).Links | ?{$_.outerText -match "Windows Offline"}
    return $LatestVersion.href
}

# TODO Get-JavaLatestVersion

#endregion

#region FlashOnly

function Get-FlashDownloadLink {
    $LatestPath = "http://www.adobe.com/au/products/flashplayer/distribution3.html"
    $LatestVersion = (Invoke-WebRequest $LatestPath -UseBasicParsing).Links | ?{$_.href -match "plugin.msi"} | Select -First 1
    return $LatestVersion.href
}

# TODO Get-FlashLatestVersion

#endregion

#region VSCodeOnly
function Get-VSCodeDownloadLink {
    return 'https://go.microsoft.com/fwlink/?Linkid=852157'
}

function Get-VSCodeLatestVersion {
    $URL = 'https://code.visualstudio.com/updates'
    $WebData = Invoke-WebRequest -Uri $URL
    $Regex = [regex]'.*url=/updates/v(?<version>\d+(_\d+)+).*'
    $VersionStringU = $Regex.Match($WebData.RawContent).Groups | Select-Object -Last 1 | Select-Object -Expand Value
    $VersionString = $VersionStringU.Replace('_','.')
    return [Version]::Parse($VersionString)
}

#endregion

#region PowerBiOnly

function Get-PowerBIDownloadLink {
    $LatestPath = Get-RedirectedUrl 'https://go.microsoft.com/fwlink/?LinkId=521662&clcid=0x409'
    return $LatestPath
}

function Get-PowerBIVersion {
    $VersionURL = 'https://www.microsoft.com/en-us/download/details.aspx?id=45331'
    $VersionWebReq = Invoke-WebRequest -Uri $VersionURL -UseBasicParsing
    [regex]$reg = '(?<Version>\d+\.\d+\.\d+\.\d+)'
    $VersionArray = $reg.Match($VersionWebReq.Content).Groups[1].Value
    Return $VersionArray
}

#endregion

#region GitForWindowsOnly
function Get-GitDownloadLink{
    Param([switch]$Prerelease)

    $token = Get-Content "$PSScriptRoot\api.key"
    $Base64Token = [System.Convert]::ToBase64String([char[]]$token)
    $Headers = @{
        "content-type" = "application/json"
        "Authorization" = 'Basic {0}' -f $Base64Token
    }

    function ConvertTo-GraphQL {
        [CmdLetBinding()]
        Param([string]$QueryString,$Type="Query")
        If ($Type -eq "Query") {
            @{
                query = $QueryString.Replace("`n","")
            }
        }
    }

    $ReleaseIDQuery = @'
    query { 
        repository(owner:"git-for-windows",name:"git") {
            url
            releases(last:10) {
                edges {
                    node {
                        isPrerelease
                        releaseAssets(first:20) {
                            edges {
                                node {
                                    name
                                    downloadUrl
                                }
                            }
                        }
                    }
                }
            }
        }
    }
'@ # Get first 20 downloads from the latest release
    $query = ConvertTo-GraphQL -QueryString $ReleaseIDQuery | ConvertTo-Json
    $uri = 'https://api.github.com/graphql'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ReleasesJSon = Invoke-RestMethod -Method Post -Uri $uri -Body $query -Headers $Headers
    $Releases = $ReleasesJSon.data.repository.releases.edges.node | Where-Object {
        $psItem.isPrerelease -eq $Prerelease.IsPresent
    } | Select-object -Last 1
    $DownloadURL = $Releases.releaseAssets.edges.node|Where-Object {
        $_.Name -match '^Git.*-64-bit\.exe$'
    }
    $DownloadURL.downloadUrl
}

function Get-GitVersionFromDownloadLink {
    [CmdLetBinding()]
    Param($DownloadLink)
    ([regex]'.*v(?<version>(\d+(\.|))+).*\.windows.*').Match($DownloadLink).Groups['version'].value
}

function Get-GitLatestVersion {
    Get-GitVersionFromDownloadLink -DownloadLink (Get-GitDownloadLink)
}
#endregion

#region python
function Get-PythonReleaseVersions {
    $url = 'https://www.python.org/ftp/python/'
    Invoke-WebRequest -Uri $url |
    Select-Object -ExpandProperty Links | ForEach-Object {
        [Version]$v = $null
        $s = $_.href.TrimEnd('/')
        if ([Version]::TryParse($s,[ref]$v)) {
            $v
        }
    }
}

function Get-PythonLatestVersion {
    [CmdLetBinding()]
    Param()
    $Versions = Get-PythonReleaseVersions | Sort-Object -Descending
    $BaseURL = 'https://www.python.org/ftp/python'
    $RCRelease = $True
    $CheckVer = 0
    While ($RCRelease -and $CheckVer -le $Versions.Count -1) {
        Write-Warning "CheckVer is $CheckVer"
        $VerString = $Versions[$CheckVer].ToString()
        $CheckUrl = "${BaseUrl}/${VerString}/"
        Write-Verbose "Checking $CheckUrl"
        Invoke-WebRequest -Uri $CheckUrl |
        Select-Object -ExpandProperty Links | ForEach-Object {
            If ($_.href -eq "python-$VerString-amd64.exe") {
                $RCRelease = $False
            } 
        }
        $CheckVer++
    }
    return $Versions[$CheckVer-1]
}

function Get-PythonDownloadLink {
    Param($Version)
    $v=$Version.ToString()
    return "https://www.python.org/ftp/python/$v/python-${v}-amd64.exe"
}
#endregion

#region VLC
function Get-VLCDownloadLink {
    Param([ValidateSet(
                'MSI',
                'EXE',
                'ZIP',
                '7Z'
                )
        ][Parameter(Mandatory=$True)]$Type
    )
    $url = 'http://download.videolan.org/pub/videolan/vlc/last/win64'
    $page = Invoke-WebRequest -Uri $url
    $hostedFile = $page.Links.href |
    Where-Object { $_ -match "-win64\.$Type$"}
    return "$url/$hostedFile"
}

function Get-VLCLatestVersion {
    [CmdLetBinding()]
    $DownloadURL = Get-VLCDownloadURL -Type MSI
    [Version]$v = $null
    $s = ([regex]'(\d+\.\d+\.\d+(\.\d+|))').Matches($DownloadURL).Value
    if ([Version]::TryParse($s,[ref]$v)) {
        $v
    }
}

function Test-NewerVLCVersion {
    Param (
        [Parameter(Mandatory=$True)]$URL
    )
    (Get-VLCLatestVersion $URL) -gt (Get-VersionStringsFromPackages)
}
#endregion

#region Zoom

function Get-ZoomClientDownloadLink {
    Param([ValidateSet('MSI','EXE')]$Type)

    $userAgent = 'Mozilla/5.0 (Windows NT; Windows NT 6.1; en-US) AppleWebKit/534.6 (KHTML, like Gecko) Chrome/7.0.500.0 Safari/534.6'
    $url = 'https://zoom.us/download'
    $WebObject = Invoke-WebRequest -Uri $url -UserAgent $userAgent
    $relativeLink = $WebObject.Links | Where-Object {
        $_ -match "ZoomInstallerFull.$Type"
    } | Select-Object -ExpandProperty href
    return "${url}${relativeLink}"
}

function Get-ZoomClientLatestVersion {
    Param($ClientFilter='Zoom Client for Meetings')
    $userAgent = 'Mozilla/5.0 (Windows NT; Windows NT 6.1; en-US) AppleWebKit/534.6 (KHTML, like Gecko) Chrome/7.0.500.0 Safari/534.6'
    $url = 'https://zoom.us/download'
    $WebObject = Invoke-WebRequest -Uri $url -UserAgent $userAgent
    $Strings = $WebObject -replace "`n","" -split "<.*?>" | Where-Object {
        $_ -match "^Zoom\s.*(Client|Plugin|Rooms)" -or $_ -match "^Version"
    }
    $ClientsAndVersions = $Strings | ForEach-Object {
        If ($_ -match 'Zoom' -and $Strings[$Index+1] -match 'Version') {
            [PSCustomObject]@{
                Client = $_
                Version = Get-VersionFromString $Strings[$Index+1]
            }
        }
        $Index ++
    }
    $ClientsAndVersions | Where-Object {$_.Client -match $ClientFilter} |
    Select-Object -ExpandProperty Version
}

#endregion


Export-ModuleMember *
