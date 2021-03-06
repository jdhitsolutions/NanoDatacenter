#Requires -version 5.1

Configuration NanoHyperV {

Param(
    [Parameter(Mandatory)]
    [string]$Computername,

    [Parameter(Mandatory)]
    [string]$VMName,
        
    [Parameter(Mandatory)]
    [Uint64]$StartupMemory,

    [Parameter(Mandatory)]
    [Uint64]$MinimumMemory,

    [Parameter(Mandatory)]
    [Uint64]$MaximumMemory,

    [Parameter(Mandatory)]
    [String]$SwitchName,

    [Parameter(Mandatory)]
    [Uint64]$MaximumSizeBytes,

    [Uint32]$ProcessorCount = 1

)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xHyper-V

Node $Computername {

File VMDisks {
    Ensure = 'Present'
    Type = 'Directory'
    DestinationPath = 'C:\VMdisks'
}

 xVMSwitch InternalSwitch
        {
            Ensure         = 'Present'
            Name           = $SwitchName
            Type           = 'Internal'
            AllowManagementOS = $True
        }

 xVhd NewVhd
        {
            Ensure           = 'Present'
            Name             = $VMName
            Path             = 'C:\VMDisks'
            Generation       = 'Vhdx'
            MaximumSizeBytes = $MaximumSizeBytes
            DependsOn = '[File]VMDisks'
        }

xVMHyperV NewVM 
    {
        Ensure          = 'Present'
        Name            = $VMName
        VhdPath         = $(Join-path -Path C:\VMDisks -ChildPath "$VMName.vhdx")
        SwitchName      = $SwitchName
        Generation      = 2
        StartupMemory   = $StartupMemory
        MinimumMemory   = $MinimumMemory
        MaximumMemory   = $MaximumMemory
        ProcessorCount  = $ProcessorCount
        RestartIfNeeded = $true
        EnableGuestService = $True
  }
  
  LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    ConfigurationMode = 'ApplyAndMonitor'
    ActionAfterReboot = 'ContinueConfiguration'
    AllowModuleOverwrite =  $True
} 

} #node

}

