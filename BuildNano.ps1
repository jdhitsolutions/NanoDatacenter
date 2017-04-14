#requires -version 5.1

Return "This is a demo file to walk through. Try again."

<#
This demo relies on a few projects I've been working on that are in my 
GitHub repo. Eventually they will be published to the PowerShell Gallery. 

For now you can go to the module, download a zip file and extract it locally.

These modules are still being updated so it is possible these demos may fail
at some point in the future.

Jeff - April 14, 2017
#>

#Run this ON a Hyper-V server either on Windows 10 or Windows Server 2016

#https://github.com/jdhitsolutions/myNanoTools
#this module contains my tools for building and managing Nano virtual server
#images and machines.
Import-Module s:\MyNanoTools\MyNanoTools.psd1 -force

#https://github.com/jdhitsolutions/DSCResourceTools
#this module contains some tools for analyzing DSC Resources.
Import-Module S:\DscResourceTools -force

#region Basics

#Demo provisioning a Nano server in a Hyper-V virtual machine.
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

psedit .\NanoFile.psd1

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

#add some features
Add-WindowsFeature File-Services -IncludeAllSubFeature -ComputerName $imgparam.ComputerName

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
Start-DscConfiguration -Path C:\dsc\NanoFile -ComputerName n-srv1 -Verbose -Wait

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

#NOTE: PowerShell Web Access not supported on Nano. 
# requires a fuller version of the .NET Framework

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

$imgparam = @{
    ComputerName = "N-SRV6"
    Plaintext = "P@ssw0rd"
    IPv4Address = "172.16.40.7"
    DiskPath = "E:\VMdisks"
    ConfigData = ".\nanodefaults.psd1"
    DomainName = "globomantics"
    ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
    Path = "E:\VMs" 
    SwitchName = "DomainNet" 
    MemoryStartupBytes = 8GB
    Memory = "Static"
    ProcessorCount = 4
    start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam -Verbose

Checkpoint-VM -Name $imgparam.ComputerName -SnapshotName "Baseline"

$iso = "D:\iso\en_sql_server_2016_enterprise_x64_dvd_8701793.iso"
Add-VMDvdDrive -VMName $imgparam.computername -Path $iso
get-vm $imgparam.ComputerName | Get-VMDvdDrive

#DSC Configuration
psedit .\configurations\SQLConfig.ps1

$configdata = @{
    AllNodes = @(
        @{
            NodeName = $imgparam.ComputerName
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true 
        })
}

nanosql -Computername $imgparam.ComputerName -OutputPath C:\DSC\Nanosql -ConfigurationData $configdata -Credential globomantics\administrator
psedit C:\dsc\Nanosql\$($imgparam.ComputerName).mof

#copy DSC Resources
$s = New-PSSession $imgparam.ComputerName

$modules = "xSqlPs"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

invoke-command { Get-DscResource } -session $s| select name,module,version

#push configuration
Set-DscLocalConfigurationManager -Path C:\dsc\Nanosql -Verbose
Start-DscConfiguration -Path C:\dsc\Nanosql -Verbose -Wait -force
#clear 
Remove-DscConfigurationDocument -Stage Pending -CimSession $imgparam.ComputerName

#try Standard?
$std = "D:\iso\en_sql_server_2016_standard_x64_dvd_8701871.iso"
Set-VMDvdDrive -VMName $imgparam.computername -Path $std
Start-DscConfiguration -Path C:\dsc\Nanosql -Verbose -Wait -force

#try different resource
#look at Nanosql2

$modules = "xSqlServer"
foreach ($module in $modules) {
    Split-Path (Get-Module $module -ListAvailable).ModuleBase |
    Copy-Item -recurse -Destination 'C:\Program Files\WindowsPowerShell\Modules' -force -Tosession $S
}

nanosql2 -Computername $imgparam.ComputerName -OutputPath C:\DSC\Nanosql2 -ConfigurationData $configdata -Credential globomantics\administrator
Start-DscConfiguration -Path C:\dsc\Nanosql2 -Verbose -Wait -force
Remove-DscConfigurationDocument -Stage Pending -CimSession $imgparam.ComputerName

#try SQL Server vNext Preview
# https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-vnext-ctp
$ctp = 'D:\iso\SQLServerVnextCTP1.4-x64-ENU.iso'
Set-VMDvdDrive -VMName $imgparam.computername -Path $ctp

Start-DscConfiguration -Path C:\dsc\Nanosql2 -Verbose -Wait -force
Remove-DscConfigurationDocument -Stage Pending -CimSession $imgparam.ComputerName

Start-DscConfiguration -Path C:\dsc\Nanosql -Verbose -Wait -force

#this might be possible in a container but I have not tested

#cleanup
Remove-VMDvdDrive -VMName $imgparam.ComputerName
Remove-PSSession $s

#reset demo
# Get-VMSnapshot -VMName n-srv6 | Restore-VMSnapshot -confirm:$false

#endregion

#region Clustering?

psedit .\NanoCluster.psd1

$imgparam = @{
    ComputerName = "N-SRV7"
    Plaintext = "P@ssw0rd"
    IPv4Address = "172.16.40.8"
    DiskPath = "E:\VMdisks"
    ConfigData = ".\nanocluster.psd1"
    DomainName = "globomantics"
    ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
    Path = "E:\VMs" 
    SwitchName = "DomainNet" 
    MemoryStartupBytes = 1GB
    Memory = "Dynamic"
    ProcessorCount = 2
    start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam -Verbose

$imgparam = @{
    ComputerName = "N-SRV8"
    Plaintext = "P@ssw0rd"
    IPv4Address = "172.16.40.9"
    DiskPath = "E:\VMdisks"
    ConfigData = ".\nanocluster.psd1"
    DomainName = "globomantics"
    ReuseDomainNode = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam -Verbose

#checkpoint
Get-VM n-srv7,n-srv8 | Checkpoint-VM -SnapshotName "Baseline"

#view installed features
get-windowsfeature -comp n-srv7

#DSC Config ?
get-dscresource xcluster | Get-DSCResourceDetail -ov d
$d.commands.where({$_.modulename -ne 'unknown'}) | select modulename -Unique

icm { get-module failoverclusters -list } -computer n-srv7,n-srv8
# --> no

#Manual setup, which could be scripted

psedit .\configCluster.ps1

#verify
#cluster roles may be limited
get-windowsfeature -ComputerName n-srv7
get-windowsfeature -ComputerName n-srv8
cluadmin.msc

#cleanup
#destroy cluster
# get-vm n-srv7,n-srv8 | Get-VMSnapshot | restore-vmsnapshot

#endregion

#region Containers

psedit .\NanoContainers.psd1

$imgparam = @{
    ComputerName = "N-SRV9"
    Plaintext = "P@ssw0rd"
    IPv4Address = "172.16.40.10"
    DiskPath = "E:\VMdisks"
    ConfigData = ".\nanocontainers.psd1"
    DomainName = "globomantics"
    ReuseDomainNode = $True
}

#parameters for New-MyNanoVM
$vmparam = @{
    Path = "E:\VMs" 
    SwitchName = "DomainNet" 
    MemoryStartupBytes = 4GB
    MemoryMaximumBytes = 4GB
    Memory = "Dynamic"
    ProcessorCount = 2
    start = $True
}

New-MyNanoImage @imgparam | New-MyNanoVM @vmparam -Verbose

Invoke-Command { get-module containers -list } -computer $imgparam.computername
Get-WindowsFeature -computer $imgparam.ComputerName

#configure
# https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/deploy-containers-on-nano
$s = New-PSSession -ComputerName $imgparam.ComputerName
enter-pssession $s
$sess = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
Invoke-CimMethod -InputObject $sess -MethodName ApplyApplicableUpdates
gcim win32_quickfixengineering
exit
restart-computer $imgparam.computername -Wait -For WinRM

#install Docker
$s = New-PSSession -ComputerName $imgparam.ComputerName
enter-pssession $s

Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider
exit
restart-computer $imgparam.computername -wait -for Winrm

#pull images
$s = New-PSSession -ComputerName $imgparam.ComputerName
enter-pssession $s
docker pull microsoft/nanoserver

netsh advfirewall firewall add rule name="Docker daemon " dir=in action=allow protocol=TCP localport=2375

new-item -Type File c:\ProgramData\docker\config\daemon.json
Add-Content 'c:\programdata\docker\config\daemon.json' '{ "hosts": ["tcp://0.0.0.0:2375", "npipe://"] }'
Restart-Service docker
exit

#checkpoint VM
Checkpoint-VM -Name $imgparam.ComputerName -SnapshotName "Baseline"

#client config
Invoke-WebRequest "https://download.docker.com/components/engine/windows-server/cs-1.12/docker.zip" -OutFile "$env:TEMP\docker.zip" -UseBasicParsing
Expand-Archive -Path "$env:TEMP\docker.zip" -DestinationPath $env:ProgramFiles
# For quick use, does not require shell to be restarted.
$env:path += ";c:\program files\docker"

# For persistent use, will apply even after a reboot. 
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Docker", [EnvironmentVariableTarget]::Machine)

#validate in the console, not the ISE
docker -H tcp://172.16.40.10:2375 run -it microsoft/nanoserver cmd

remove-pssession $s

#reset to Updates snapshot
# get-vm n-srv9 | get-vmsnapshot -name Updates | restore-vmsnapshot

#endregion

#region SMTP 

#no supported feature

#endregion

#region IPAM

#no supported feature

#endregion

#region WDS

#no supported feature

#endregion

#region Remote Access

#no supported feature

#endregion

#region ADLS

#no supported feature

#endregion

#region AD-Certificate server

#no supported feature

#endregion

#region Network Policy Server

#no supported feature

#endregion

#region WSUS server

#no supported feature

#endregion