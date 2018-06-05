function Get-PackageList {
    Set-Location \\usc.internal\usc\appdev\SCCMPackages
    Get-ChildItem | ForEach-Object { 
        $Extensions = Get-ChildItem -Path $_.Name | Select -ExpandProperty Extension
        If ($Extensions -contains '.sft') {$PkgType = 'APPV4'} 
        ElseIf ($Extensions -contains '.appv') {$PkgType = 'APPV5'}
        ElseIf ($Extensions -contains '.msi') {$PkgType = 'MSI'}
        ElseIf ($Extensions -contains '.exe') {$PkgType = 'EXE'}
        ElseIf ($Extensions -contains '.vbs') {$PkgType = 'vbs'}
        Else {$PkgType = 'Other'}
        <#Switch ($Extensions) {
            {$_ -contains '.sft'} {$PkgType = 'APPV4'}
            {$_ -contains '.appv'} {$PkgType = 'APPV5'}
            {$_ -contains '.msi'} {$PkgType = 'MSI'}
            {$_ -contains '.exe'} {$PkgType = 'EXE'}
            Default {$PkgType = 'Other'}
        }#>
        [pscustomobject]@{
            'PackageName' = $_.Name
            'PackageType' = $PkgType
            'PackageSizeMB' = "{0:#0}" -f ((Get-ChildItem -Path $_.Name -Recurse | Measure-Object -Sum Length).Sum /1mb)
        }
    }
}