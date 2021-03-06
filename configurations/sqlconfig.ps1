#Requires -version 5.1

Configuration NanoSQL {

Param(
[Parameter(mandatory)]
[string]$Computername,
[Parameter(mandatory)]
[pscredential]$Credential
)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -module xSqlPs


Node $Computername {

xSQLServerInstall Default {
InstanceName = "Default"
SourcePath = "D:\"
Features= "SQLEngine"
SqlAdministratorCredential = $credential
}

  
LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyOnly'
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite =  $True
}

}

}

Configuration NanoSQL2 {

Param(
[Parameter(mandatory)]
[string]$Computername,
[Parameter(mandatory)]
[pscredential]$Credential
)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -module xSQLServer


Node $Computername {

xSqlServerSetup Default {
InstanceName = "Default"
SetupCredential = $Credential
SourcePath = "D:\"
SuppressReboot = $True
Action = 'Install'
Features = "SQLEngine"

}

  
LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyOnly'
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite =  $True
}

}

}


