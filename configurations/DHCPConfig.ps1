#Requires -version 5.1

Configuration NanoDHCP {

Param([string]$Computername,[pscredential]$Credential)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xDHCPServer

Node $Computername {

WindowsFeature DHCP {
    Name = 'DHCP'
    Ensure = 'Present'
}

<#
WindowsFeature RSAT {
    Name = 'RSAT-DHCP'
    Ensure = 'Present'
}
#>

xDhcpServerScope Chicago {
    Name = 'Chicago'
    IPStartRange = '172.16.100.1'
    IPEndRange = '172.16.100.100'
    SubnetMask =  '255.255.0.0'
    LeaseDuration = '00:08:00'
    State = 'Active'
    AddressFamily = 'IPv4'
    Ensure = 'Present'
    DependsOn = '[WindowsFeature]DHCP'
}

xDhcpServerOption 'DhcpOption' {
    ScopeID = '172.16.0.0'
    DnsServerIPAddress = @('172.16.30.203','172.16.30.200')
    Router = '172.16.10.254'
    AddressFamily = 'IPv4'
    DnsDomain = 'globomantics.local'
    DependsOn = '[xDhcpServerScope]Chicago'
}  
 
xDhcpServerAuthorization 'DhcpServerAuthorization' {
    Ensure = 'Present'
    DnsName = "$computername.globomantics.local"
    PsDscRunAsCredential = $credential
    DependsOn = '[xDhcpServerScope]Chicago'
} 

LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyAndAutoCorrect'
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite =  $True
}

}

}

