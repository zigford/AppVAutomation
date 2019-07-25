<#

Each supported package needs 2 functions
1. Get-AppNameLatestVersion
   This function returns a [Version] object of the latest version
2. Get-AppNameDownloadLink
   This function returns a URL from which to download a file

#>

#region Common

<#
    Functions commonly used to implement a package checker
#>

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

function Get-DownloadFromLink {
    [CmdLetBinding(SupportsShouldProcess)]
    Param($Link,$Outpath,$Outfile)
    If (!$Outfile) {
        $Outfile = ($Link.Split("/") | Select -Last 1).Replace('%20',' ')
    }
    $Output = "$Outpath\$Outfile"
    If ($PSCmdlet.ShouldProcess($Output, "Download file to")) {
        Invoke-WebRequest -Uri $Link -OutFile $Output -UseBasicParsing
        $OutFile = Get-Item -Path $Output
        If ($OutFile) {
            Write-Host -ForegroundColor Green "Download Success"
            return $OutFile
        } Else {
            Write-Host -ForegroundColor Red "Download Failed"
        }
    }
}

function Set-DefaultApp{

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

#endregion
