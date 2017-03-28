#requires -version 5.0
#requires -RunAsAdministrator

#this version is designed with defaults for CHI-P50
#creating a domain joined image will require a CredSSP session

Function New-MyNanoImage {

[cmdletbinding(SupportsShouldProcess)]
Param(
[Parameter(Mandatory)]
[alias("name")]
[string]$ComputerName,
[Parameter(Mandatory)]
[ValidateNotNullorEmpty()]
[string]$Plaintext = "P@ssw0rd",
[Parameter(Mandatory)]
[ValidateNotNullorEmpty()]
[string]$IPv4Address,
[Parameter(Mandatory)]
[ValidateScript({Test-Path $_})]
[string]$ConfigData,
[Parameter(Mandatory)]
[ValidateScript({Test-Path $_})]
[string]$DiskPath,
[string]$SetupCompleteCommand,
[string[]]$CopyPath,
[string]$DomainName,
[switch]$ReuseDomainNode,
[string]$DomainBlobPath
)

$start = Get-Date

Write-Verbose "Importing values from $ConfigData"
$config = Import-PowerShellDataFile -Path $ConfigData

#add each entry to PSBoundParameters which will eventually be 
#splatted to New-NanoServerImage
foreach ($key in $config.keys) {
    $PSBoundParameters.Add($key,$config.item($key))
}

#remove some parameters that don't belong to New-NanoServerImage
$PSBoundParameters.Remove("DiskPath") | Out-Null
$PSBoundParameters.Remove("ConfigData") | Out-Null
$PSBoundParameters.Remove("Plaintext") | Out-Null

Write-Verbose "Creating a new Nano image for $($Computername.toupper())"
$Target = Join-Path $diskPath -ChildPath "$computername.vhdx"
$secure = ConvertTo-SecureString -String $plainText -AsPlainText -Force

#add to PSBoundParameters
$PSBoundParameters.Add("TargetPath",$target) | Out-Null
$PSBoundParameters.Add("AdministratorPassword",$secure) | Out-Null

Write-Verbose "Using these values"
$PSBoundParameters | Out-String | write-verbose 

if ($PSCmdlet.ShouldProcess($target)) {
    Try {
        $result = New-NanoServerImage @PSBoundparameters -ErrorAction Stop
        #write image path to the pipeline
        [pscustomobject]@{
            Result = $result
            Name = $ComputerName
            VHDPath = $Target
        }
    }
    Catch {
        Write-Warning "Error. $($_.exception.message)"
    }
} #should process

$end = Get-Date
Write-Verbose "Image created in $($end-$Start)"

}

Function New-MyNanoVM {
[cmdletbinding(SupportsShouldProcess)]
Param(
[Parameter(Position = 0, Mandatory,ValueFromPipelineByPropertyName)]
[string]$Name,
[Parameter(Position = 1, Mandatory,ValueFromPipelineByPropertyName)]
[string]$VhdPath,
[Parameter(Mandatory)]
[string]$Path,
[ValidateSet("Dynamic","Static")]
[string]$Memory = "Dynamic",
[ValidateNotNullorEmpty()]
[int32]$MemoryStartupBytes = 512MB,
[ValidateNotNullorEmpty()]
#this will be ignored if using Static memory
[int64]$MemoryMaximumBytes = 1GB,
[ValidateScript({$_ -ge 1})]
[int]$ProcessorCount = 1,
[Parameter(Mandatory)]
[ValidateNotNullOrEmpty()]
[string]$SwitchName,
[switch]$Start
)

#create a generation 2 VM
$PSBoundParameters.Add("Generation",2)

#remove parameters that don't belong to New-VM
$PSBoundParameters.Remove("MemoryMaximumBytes") | Out-Null
$PSBoundParameters.Remove("ProcessorCount") | Out-Null
$PSBoundParameters.Remove("Memory") | Out-Null
$PSBoundParameters.Remove("Start") | Out-Null

#create a hashtable of parameters for Set-VM
$set = @{
 MemoryMinimumBytes = $MemoryStartupBytes
 ProcessorCount = $ProcessorCount
}

if ($Memory -eq 'Dynamic') {
    $set.Add("DynamicMemory",$True)
    $set.Add("MemoryMaximumBytes", $MemoryMaximumBytes)
}
else {
    $set.Add("StaticMemory",$True)
}

$vm = New-VM @PSBoundParameters

$vm | Set-VM @set

if ($start) {
    Start-VM $vm
}
}

<#
New-MyNanoImage -ComputerName "NFoo" -Plaintext P@ssw0rd -IPv4Address "172.16.80.2" -DiskPath E:\disks -ConfigData .\NanoDefaults.psd1 | 
New-MyNanoVM -Path E:\VMs -SwitchName DomainNet -MemoryStartupBytes 1GB
#>