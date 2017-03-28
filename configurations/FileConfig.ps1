#requires -version 5.0

Configuration NanoFile {

Param([string]$Computername,[string]$Domain = $env:USERDOMAIN)

Import-DscResource -ModuleName PSDesiredStateConfiguration,xSMBShare
Node $Computername {
    File Public {
        ensure  = 'Present'
        DestinationPath = 'C:\Public'
        Type = 'Directory'        
    }

    File Sales {
         ensure  = 'Present'
        DestinationPath = 'C:\Sales'
        Type = 'Directory'     
    }

    File IT {
        Ensure = 'Present'
        DestinationPath = 'C:\IT'
        Type = 'Directory'
    }

    File SalesReadme {
        Ensure = 'Present'
        DependsOn = '[file]Sales'
        DestinationPath = 'c:\sales\readme.txt'
        Type = 'File'
        Contents = 'Files for the Sales department'
    }

    File PublicReadme {
        Ensure = 'Present'
        DependsOn = '[file]Public'
        DestinationPath = 'c:\Public\readme.txt'
        Type = 'File'
        Contents = 'public files for the company'
    }

    #create a folder structure for IT
    $folders = "Scripts","Reports","Tools","Logs"
    foreach ($folder in $folders) {
        File $folder {
            DependsOn = '[file]IT'
            DestinationPath = "c:\IT\$folder"
            Type = 'Directory'
            Ensure = 'Present'
            Force = $true
        }
    }

    xSMBShare PublicShare {
        DependsOn = '[file]Public'
        Name = 'Public'
        Path = 'C:\public'
        Description = 'Domain public files'
        ChangeAccess = "$domain\domain users"
        FullAccess = "$domain\domain admins"
    }

     xSMBShare SalesShare {
        DependsOn = '[file]Sales'
        Name = 'SalesData'
        Path = 'C:\Sales'
        Description = 'Sales Staff files'
        ChangeAccess = "$domain\Chicago Sales Users"
        FullAccess = @("$domain\domain admins","$domain\Chicago Sales Managers")
        FolderEnumerationMode = 'AccessBased'
    }

     xSMBShare ITShare {
        DependsOn = '[file]IT'
        Name = 'IT$'
        Path = 'C:\IT'
        Description = 'hidden IT file share'
        ChangeAccess = "$domain\Help Desk"
        FullAccess = "$domain\domain admins"
        FolderEnumerationMode = 'AccessBased'
    }

    LocalConfigurationManager {
        ConfigurationMode = 'ApplyAndAutoCorrect'
        RebootNodeIfNeeded = $true
        ActionAfterReboot = 'ContinueConfiguration'
    }
} 
}