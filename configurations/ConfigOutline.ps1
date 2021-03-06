#Requires -version 5.1

Configuration NanoXXX {

Param([string]$Computername)

Import-DscResource -ModuleName PSDesiredStateConfiguration


Node $Computername {



  
LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyAndAutoCorrect'
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite =  $True
}

}



}

