#requires -version 5.0

Return "This is a demo file to walk through you fool!"

#https://github.com/jdhitsolutions/myNanoTools
Import-Module s:\MyNanoTools\MyNanoTools.psd1 -force

#https://github.com/jdhitsolutions/DSCResourceTools
Import-Module S:\DscResourceTools -force

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

psedit .\nanoweb.psd1

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

nanoweb -Computername $imgparam.ComputerName -OutputPath C:\DSC\Nanoweb
psedit C:\dsc\Nanoweb\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xWebAdministration"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s| select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\NanoWeb -Verbose
Start-DscConfiguration -Path C:\dsc\NanoWeb -Verbose -Wait

Remove-DscConfigurationDocument -Stage Pending -CimSession n-srv2

#configuration works on server core
standardweb -Computername chi-test01 -OutputPath C:\dsc\stdweb
Start-DscConfiguration -Wait -Verbose -Path c:\dsc\stdweb -force
start http://chi-test01

#add DNS record is using host names
#Add-DnsServerResourceRecordA -Name Bakery -IPv4Address $imgparam.IPv4Address -ZoneName "GLOBOMANTICS.local" -ComputerName chi-dc04 -PassThru
# Resolve-DnsName bakery.globomantics.local

#check features on nano
Get-WindowsFeature -ComputerName n-srv2

#other issues:
Enter-PSSession $s
gmo -ListAvailable
get-command stop-website
get-command -module IISAdministration
get-IISSite

#look at resources with my module
$r = Get-DscResource windowsfeature -Module psdesiredstateconfiguration | Get-DSCResourceDetail
$r.Commands | sort modulename

Get-DSCResourceCommands -Name xwebsite | Sort Module,Name
get-dscresource xwebsite | Get-DscResourceReport

<#
stop-iissite "default web site" -confirm:$false
$bind = "*:80:"
New-IISSite -Name Bakery -PhysicalPath C:\inetpub\wwwroot -BindingInformation $bind
#>

exit

Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv2 | Restore-VMSnapshot -confirm:$false

#endregion

#region DNS 

psedit .\Nanodns.psd1

$imgparam = @{
ComputerName = "N-SRV3"
Plaintext = "P@ssw0rd"
IPv4Address = "172.16.40.4"
DiskPath = "E:\VMdisks"
ConfigData = ".\nanodns.psd1"
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

#look at current state
get-service dns* -comp $imgparam.ComputerName
Get-WindowsFeature -ComputerName $imgparam.computername
Add-WindowsFeature DNS -ComputerName $imgparam.computername
get-service dns* -comp $imgparam.ComputerName

#Open DNS Manager
dnsmgmt.msc

#DSC Configuration
psedit .\configurations\DNSConfig.ps1

nanodns -Computername $imgparam.ComputerName -JsonDNS .\configurations\summitdns.json -OutputPath C:\DSC\NanoDNS
psedit C:\dsc\NanoDNS\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xDnsServer"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s| select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\NanoDNS -Verbose
Start-DscConfiguration -Path C:\dsc\NanoDNS -Verbose -Wait -force

#zones need configuration on master servers
$z = get-DnsServerZone -Name globomantics.local -ComputerName chi-dc04
#get existing secondaries
[string[]]$current = $z.SecondaryServers.IPAddressToString
$current+= $imgparam.IPv4Address

$set = @{
Name = 'globomantics.local '
ComputerName = 'chi-dc04' 
SecondaryServers = $current 
SecureSecondaries = 'TransferToSecureServers' 
Notify  = 'NotifyServers' 
NotifyServers = $current
}
Set-DnsServerPrimaryZone @set

#verify in DNS Manager

Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv3 | Restore-VMSnapshot -confirm:$false

#endregion

#region DHCP

$imgparam = @{
ComputerName = "N-SRV4"
Plaintext = "P@ssw0rd"
IPv4Address = "172.16.40.5"
DiskPath = "E:\VMdisks"
ConfigData = ".\nanodefaults.psd1"
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
psedit .\configurations\DHCPConfig.ps1

$configdata = @{
    AllNodes = @(
        @{
            NodeName = 'n-srv4'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true 
        })
}
nanodhcp -Computername $imgparam.ComputerName -OutputPath C:\DSC\NanoDHCP -configurationdata $configdata -credential globomantics\administrator

#nanodhcp -Computername chi-test03 -OutputPath C:\DSC\NanoDHCP -configurationdata $configdata -credential globomantics\administrator

psedit C:\dsc\NanoDHCP\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xDHCPServer"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s| select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\NanoDHCP -Verbose
Start-DscConfiguration -Path C:\dsc\NanoDHCP -Verbose -Wait -ComputerName $imgparam.ComputerName -force

# Start-DscConfiguration -Path C:\dsc\NanoDHCP -Verbose -Wait -ComputerName chi-test03 -force 

invoke-command { get-module -list } -session $s

Get-WindowsFeature -ComputerName n-srv4

Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv4 | Restore-VMSnapshot -confirm:$false

#endregion

#region Hyper-V host

psedit .\Nanohyperv.psd1

$imgparam = @{
ComputerName = "N-SRV5"
Plaintext = "P@ssw0rd"
IPv4Address = "172.16.40.6"
DiskPath = "E:\VMdisks"
ConfigData = ".\nanohyperv.psd1"
DomainName = "globomantics"
ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
Path = "E:\VMs" 
SwitchName = "DomainNet" 
MemoryStartupBytes = 16GB
Memory = "Static"
ProcessorCount = 4
start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam -Verbose

Checkpoint-VM -Name $imgparam.ComputerName -SnapshotName "Baseline"

get-windowsfeature -ComputerName $imgparam.ComputerName
get-vmhost -computer n-srv5
invoke-command { get-command -module hyper-v} -comp n-srv5

$r = Get-DscResource xVMHyperV | Get-DSCResourceDetail
$r.commands
#verify commands exist
$cmds = $r.commands.where({$_.modulename -ne 'unknown'}).name 
invoke-command {get-command $using:cmds} -computer n-srv5

#DSC Configuration
psedit .\configurations\HyperVConfig.ps1

nanohyperv -Computername $imgparam.ComputerName -OutputPath C:\DSC\NanoHyperV -VMName Summit01 -StartupMemory 1gb -MinimumMemory 1gb -MaximumMemory 2gb -SwitchName Lab -MaximumSizeBytes 10gb -ProcessorCount 2
psedit C:\dsc\NanoHyperV\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xHyper-V"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s| select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\NanoHyperV -Verbose
Start-DscConfiguration -Path C:\dsc\NanoHyperV -Verbose -Wait -force

#verify
get-vm -ComputerName n-srv5
enter-pssession $s
get-vm | Get-VMHardDiskDrive | get-item
Get-VMSwitch
exit

Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv5 | Restore-VMSnapshot -confirm:$false

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