#region Common

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
Function Get-RedirectedUrl {

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
    Param($Link,$Outpath,$Outfile)
    If (!$Outfile) {
        $Outfile = ($Link.Split("/") | Select -Last 1).Replace('%20',' ')
    }
    $Output = "$Outpath\$Outfile"
    Invoke-WebRequest -Uri $Link -OutFile $Output -UseBasicParsing
    $OutFile = Get-Item -Path $Output
    If ($OutFile) {
        Write-Host -ForegroundColor Green "Download Success"
        return $OutFile
    } Else {
        Write-Host -ForegroundColor Red "Download Failed"
    }
}

function Set-DefaultApp{

}

#endregion

#region FireFoxOnly

function Get-FirefoxDownloadLink {
    $LatestPath = Get-RedirectedUrl "https://download.mozilla.org/?product=firefox-latest&os=win&lang=en-US"
    #$LatestVersion = ((Invoke-WebRequest $LatestPath).Links | ?{$_.innerHTML -notmatch "stub" -and $_.innerHTML -match "exe"}).href
    return $LatestPath
}

function New-FireFoxAnswerFile {
    Param($Version)
    $AnswerINI = @"
[Install]
InstallDirectoryPath=C:\Program Files\Mozilla\Firefox
QuickLaunchShortcut=false
DesktopShortcut=false
StartMenuShortcuts=true
"@

$AnswerINI

}

function New-MozillaConfigFile {
    Param($Path)
    If ( ! (Test-Path (Split-Path -Parent $Path))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    }
    $Content = @"
// Config Lockdown for USC
lockPref("app.update.auto", false);
lockPref("app.update.enabled", false);
lockPref("app.update.service.enabled", false);
lockPref("browser.shell.checkDefaultBrowser", false);
"@

    Set-Content -Value $Content -Path $Path -Force
}

function Enable-MozillaConfigFile {
    param($InstallPath)
    $LocalPrefsFile = Join-Path -Path $InstallPath -ChildPath "defaults\pref\local-settings.js"
    If ( ! (Test-Path -Path (Split-Path -Path $LocalPrefsFile -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path -Path $LocalPrefsFile -Parent) -Force
    }
    $Content = @"
pref("general.config.obscure_value", 0);
pref("general.config.filename", "mozilla.cfg");
"@

    Set-Content -Path $LocalPrefsFile -Value $Content -Force
}

function New-MozillaPreference {
    Param($Path)
    If ( ! (Test-Path (Split-Path -Parent $Path))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    }
    $Content = @"
# Mozilla User Preferences

/* Do not edit this file.
 *
 * If you make changes to this file while the application is running,
 * the changes will be overwritten when the application exits.
 *
 * To make a manual change to preferences, you can visit the URL about:config
 * For more information, see http://www.mozilla.org/unix/customizing.html#prefs
 */

user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("app.update.service.enabled",false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("network.proxy.type", 4);
"@
    Set-Content -Path $Path -Value $Content -Force
}

function New-MozillaUIMod {
    Param($Path)
    If ( ! (Test-Path (Split-Path -Parent $Path))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    }
    $Content = @"
/* UserChrome.css for Mozilla Firefox */
/* Remove access to user interface elements that aren't suitable for application virtualization */


/* Options - Advanced - General - System Defaults */
#systemDefaultsGroup { display: none !important; }

/* Options / Advanced / Updates / Firefox checkbox */
#aboutDialog,#updateTab {display: none !important;}
/* - Depreciated #enableAppUpdate { display: none !important; } - */

/* Help - About - Check for Updates button */
#updateButton { display: none !important; }
"@
    Set-Content -Path $Path -Value $Content -Force
}

function Install-FireFoxExtension {
    Param($Path,$FireFoxPath)
    If ((Test-Path -Path $FireFoxPath) -and (Test-Path -Path $Path)) {
        $ExtName = (Get-Item -Path $Path).Name
        $InstallExtension = New-Item -Force -ItemType Directory -Path "$FireFoxPath\InstallExtension"
        Copy-Item $Path $InstallExtension -Recurse
        $ExtReg = New-Item -Path "HKLM:\Software\Wow6432Node\Mozilla\Firefox\extensions" -Force
        New-ItemProperty -Path $ExtReg.PSPath -Name $ExtName -Value "$InstallExtension\$ExtName"
    }
}
#endregion

#region JavaOnly

function Get-JavaDownloadLink {
    $LatestPath = "http://java.com/en/download/manual.jsp"
    $LatestVersion = (Invoke-WebRequest $LatestPath -UseBasicParsing).Links | ?{$_.outerText -match "Windows Offline"}
    return $LatestVersion.href
}

function Disable-JavaUpdates {
    $AllJavaReg = Get-ChildItem 'HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment' | ForEach-Object {$_.PSChildName}
    Foreach ( $JavaVersion in $AllJavaReg ) { 
        $JRegPaths = "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment\$($JavaVersion)\MSI", "HKLM:\SOFTWARE\WoW6432Node\JavaSoft\Java Runtime Environment\$($JavaVersion)\MSI"
        Foreach ( $JRegPath in $JRegPaths ) {
            If (Test-Path $JRegPath) {
                Set-ItemProperty -Path $JRegPath -Name AUTOUPDATECHECK -Value 0 -Force
                Set-ItemProperty -Path $JRegPath -Name JAVAUPDATE -Value 0 -Force
            }
        }
    }
    $JRegPaths = "HKLM:\SOFTWARE\JavaSoft", "HKLM:\SOFTWARE\WoW6432Node\JavaSoft"
    Foreach ( $JRegPath in $JRegPaths ) {
        If (Test-Path $JRegPath) {
            If ( ! (Test-Path ($JRegPath + "\Java Update\Policy")) ) {
                New-Item -Path ($JRegPath + "\Java Update\Policy") -Force
            }
            New-ItemProperty -Path ($JRegPath + "\Java Update\Policy") -Name EnableJavaUpdate -Type DWORD -Value 0 -Force
            New-ItemProperty -Path ($JRegPath + "\Java Update\Policy") -Name NotifyDownload -Type DWORD -Value 0 -Force
        }
    }
}

#endregion

#region FlashOnly

function Get-FlashDownloadLink {
    $LatestPath = "http://www.adobe.com/au/products/flashplayer/distribution3.html"
    $LatestVersion = (Invoke-WebRequest $LatestPath -UseBasicParsing).Links | ?{$_.href -match "plugin.msi"} | Select -First 1
    return $LatestVersion.href
}

function Disable-FlashUpdates {
    $FlashPaths = "$env:WinDir\System32\Macromed\Flash", "$env:WinDir\SysWOW64\Macromed\Flash"
    Foreach ($FlashPath in $FlashPaths) {
        If (Test-Path $FlashPath) {
            Set-Content -Path ($FlashPath + "\mms.cfg") -Value "AutoUpdateDisable=1"
        }
    }    
}
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
    #$LatestVersion = ((Invoke-WebRequest $LatestPath).Links | ?{$_.innerHTML -notmatch "stub" -and $_.innerHTML -match "exe"}).href
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

function Get-PythonLatestProdVersion {
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

function Get-PythonLatestDownloadUrl {
    Param($Version)
    $v=$Version.ToString()
    return "https://www.python.org/ftp/python/$v/python-${v}-amd64.exe"
}
#endregion
