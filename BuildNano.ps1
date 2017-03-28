#requires -version 5.0

Return "This is a demo file to walk through you fool!"

#https://github.com/jdhitsolutions/myNanoTools
Import-Module s:\MyNanoTools\MyNanoTools.psd1 -force

#region Basics
#parameters for New-MyNanoImage
$imgparam = @{
ComputerName = "NFoo"
Plaintext = "P@ssw0rd"
IPv4Address = "172.16.80.2"
DiskPath = "E:\VMdisks"
ConfigData = ".\NanoDefaults.psd1"
DomainName = "globomantics"
ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
Path = "E:\VMs" 
SwitchName = "DomainNet" 
MemoryStartupBytes = 1GB
start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam

#endregion

#region File server

$imgparam = @{
ComputerName = "N-SRV1"
Plaintext = "P@ssw0rd"
IPv4Address = "172.16.40.2"
DiskPath = "E:\VMdisks"
ConfigData = ".\nanoFile.psd1"
DomainName = "globomantics"
ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
Path = "E:\VMs" 
SwitchName = "DomainNet" 
MemoryStartupBytes = 1GB
start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam

Checkpoint-VM -Name $imgparam.ComputerName -SnapshotName "Baseline"

#DSC Configuration
psedit .\configurations\FileConfig.ps1

nanofile -Computername $imgparam.ComputerName -OutputPath C:\DSC\NanoFile
psedit C:\dsc\NanoFile\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xSMBShare"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s | select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\NanoFile -Verbose
Start-DscConfiguration -Path C:\dsc\NanoFile -Verbose -Wait

#verify
Get-SMBShare -CimSession n-srv1
dir \\n-srv1\Public 
Get-content \\n-srv1\public\readme.txt

dir \\n-srv1\IT$

Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv1 | Restore-VMSnapshot -confirm:$false

#endregion

#region Web server

$imgparam = @{
ComputerName = "N-SRV2"
Plaintext = "P@ssw0rd"
IPv4Address = "172.16.40.3"
DiskPath = "E:\VMdisks"
ConfigData = ".\nanoweb.psd1"
DomainName = "globomantics"
ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
Path = "E:\VMs" 
SwitchName = "DomainNet" 
MemoryStartupBytes = 1GB
start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam

Checkpoint-VM -Name $imgparam.ComputerName -SnapshotName "Baseline"

#DSC Configuration
psedit .\configurations\WebConfig.ps1

nanoweb -Computername $imgparam.ComputerName -OutputPath C:\DSC\NanoFile
psedit C:\dsc\NanoFile\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xSMBShare"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s| select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\NanoFile -Verbose
Start-DscConfiguration -Path C:\dsc\NanoFile -Verbose -Wait

#verify


Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv1 | Restore-VMSnapshot -confirm:$false


#endregion

#region DNS 

#endregion

#region DHCP

#endregion

#region Hyper-V host

#endregion

#region SQL server

#endregion

#region WSUS server

#endregion

#region Clustering?

#endregion

#region SMTP 

#endregion

#region IPAM

#endregion

#region Containers

#endregion

#region WDS

#endregion

#region Remote Access

#endregion

#region ADLS

#endregion

#region AD-Certificate server

#endregion

#region Network Policy Server

#endregion