cls
$index = 0
$Results= gci | %{
    $_ | add-member -MemberType NoteProperty -Name index -Value $index -PassThru | Select Name,Index
    $index ++
}
$selectedUser = -1
$Results |%{Write-Host "$($_.Index) : $($_.Name)"}
$SelectedResult = Read-host "Enter a corresponding number to delete "

$Filename = ($Results | ?{$_.Index -eq $SelectedResult}).Name

Write-Host "You Choose $($Filename)" -ForegroundColor yellow