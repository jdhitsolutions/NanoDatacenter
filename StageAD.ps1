#Requires -version 5.1
#requires -module ActiveDirectory

<#
StageAD.ps1
stage Nano server accounts
#>

1..20 | foreach {
    $name = "N-SRV$_"
Try {
    Get-ADComputer -Identity $name -ErrorAction Stop
    Write-host "AD account for $Name already exists" -ForegroundColor Magenta
}
Catch {
    Write-Host "Creating AD Account for $Name" -ForegroundColor Green
    New-ADComputer -Name $Name
}

}