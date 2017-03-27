#requires -version 5.0
#requires -RunAsAdministrator

#this version is designed with defaults for CHI-P50
#creating a domain joined image will require a CredSSP session

Function New-MyNanoImage {

[cmdletbinding()]
Param(
[Parameter(Mandatory)]
[alias("name")]
[string]$ComputerName,
[Parameter(Mandatory)]
[ValidateNotNullorEmpty()]
[string]$IPv4Address,
[string[]]$Package = @('Microsoft-NanoServer-Guest-Package','Microsoft-NanoServer-DSC-Package'),
[string]$SetupCompleteCommand,
[string[]]$CopyPath,
[switch]$Compute,
[switch]$Storage,
[switch]$Clustering,
[switch]$Containers,
[string]$DomainName,
[switch]$ReuseDomainNode,
[string]$DomainBlobPath,
[ValidateNotNullorEmpty()]
[string]$DiskPath = "E:\VMDisks",
[ValidateNotNullorEmpty()]
[string]$Plaintext = "P@ssw0rd"
)

$start = Get-Date

Write-Verbose "Creating a new Nano image for $($Computername.toupper())"
$Target = Join-Path $diskPath -ChildPath "$computername.vhdx"
$secure = ConvertTo-SecureString -String $plainText -AsPlainText -Force

#remove some parameters that don't belong to New-NanoServerImage
$PSBoundParameters.Remove("DiskPath") | Out-Null
$PSBoundParameters.Remove("plaintext") | Out-Null

#set my default values
$PSBoundParameters.Add("DeploymentType","Guest")
$PSBoundParameters.Add("Edition","Standard")
$PSBoundParameters.Add("TargetPath",$Target)
$PSBoundParameters.Add("administratorPassword",$secure)
$PSBoundParameters.Add("Basepath","c:\NanoServer")
$PSBoundParameters.Add("Defender",$True)
$PSBoundParameters.Add("EnableRemoteManagementPort",$True)
$PSBoundParameters.add("EnableEMS",$True)
$PSBoundParameters.Add("EMSPort",1)
$PSBoundParameters.Add("EMSBaudRate",115200)
$PSBoundParameters.Add("Ipv4DNS",@('172.16.30.203','172.16.30.50'))
$PSBoundParameters.Add("InterfaceNameorIndex","Ethernet")
$PSBoundParameters.Add("Ipv4Subnet",'255.255.0.0')
$PSBoundParameters.Add("IPv4Gateway",'172.16.10.254')
$PSBoundParameters.Add("Package",$Package)
$PSBoundParameters | Out-String | write-verbose 

$result = New-NanoServerImage @PSBoundparameters

$end = Get-Date
Write-Verbose "Image created in $($end-$Start)"

#write image path to the pipeline
[pscustomobject]@{
    Result = $result
    Name = $ComputerName
    VHDPath = $Target
}

}

Function New-MyNanoVM {
[cmdletbinding()]
Param(
[Parameter(Position = 0, Mandatory,ValueFromPipelineByPropertyName)]
[string]$Name,
[Parameter(Position = 1, Mandatory,ValueFromPipelineByPropertyName)]
[string]$VhdPath,
[Parameter()]
[string]$Path,
[ValidateNotNullorEmpty()]
[int32]$MemoryStartupBytes = 512MB,
[string]$SwitchName = "DomainNet"
)

$PSBoundParameters.Add("Generation",2)

$vm = New-VM @PSBoundParameters

$vm | Set-VM -DynamicMemory -MemoryMaximumBytes 1gb -MemoryMinimumBytes $MemoryStartupBytes

}

