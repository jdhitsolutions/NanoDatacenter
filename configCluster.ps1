#configure cluster

Return "This is not a script. Walk through the process."

$computers = "n-srv7","n-srv8"

#create shared disk
$shared = "D:\shared.vhdx"
New-VHD -Path $shared -SizeBytes 2gb -Dynamic

#create Quorum disk
$quorum = "D:\quorum.vhdx"
New-VHD -Path $quorum -SizeBytes 1gb -Dynamic

#configure Hyper-Vhost to support sharing
#FailoverClustering feature must be installed on the host
FLTMC.EXE attach svhdxflt D:

#add a second scsi controller
stop-computer $computers
Add-VMScsiController -VMName $computers -Passthru
Get-VM -Name $computers | Get-VMScsiController

$params = @{
    VMName = $computers 
    ControllerNumber = 1 
    ControllerType = 'SCSI'
    ControllerLocation = 0 
    Path = $quorum 
    SupportPersistentReservations = $True 
    Passthru  = $True
}

Add-VMHardDiskDrive @params

$params.ControllerLocation = 1
$params.Path = $shared

Add-VMHardDiskDrive @params

#verify
Get-VMHardDiskDrive -VMName $computers -ControllerType SCSI

start-vm $computers
$cim = New-CimSession -ComputerName $computers

get-disk -CimSession $cim[0]

#Clear Quorum disk
#get-disk -CimSession $computers[0] -Number 1 | Clear-Disk -RemoveData 

#clear Data disk
#get-disk -CimSession $computers[0] -Number 2 | Clear-Disk -RemoveData 

#Initialize raw disk, partition, format, and label Quorum disk on one node
#Initialize, format, partition and label
Get-Disk -Number 1 -CimSession $cim[1] | 
Initialize-Disk -PassThru -Confirm:$false | 
New-Partition -UseMaximumSize | 
Format-Volume -FileSystem NTFS -NewFileSystemLabel Quorum -Confirm:$false

#Initialize raw disk, partition, format, and label Data disk on one node
#Initialize, format, partition and label
Get-Disk -Number 2 -CimSession $cim[1] | 
Initialize-Disk -PassThru -Confirm:$false | 
New-Partition -UseMaximumSize -DriveLetter E | 
Format-Volume -FileSystem NTFS -NewFileSystemLabel ClusterData -Confirm:$false

Update-HostStorageCache -CimSession $cim
get-disk -CimSession $cim

test-cluster -node $computers | invoke-item

#create cluster
New-Cluster -Name N-Cluster -Node $computers -NoStorage -StaticAddress 172.16.200.1 -AdministrativeAccessPoint ActiveDirectoryAndDns

$mycluster = get-cluster -Name n-cluster -Domain globomantics.local


#Add Cluster Quorum disk
Get-ClusterAvailableDisk -Cluster $mycluster.name | 
Where-Object Number -EQ 1 | 
Add-ClusterDisk -Cluster $mycluster.name

#Add ClusterData disk
Get-ClusterAvailableDisk -Cluster $Mycluster.name | 
Where-Object Number -EQ 2 | 
Add-ClusterDisk -Cluster $myCluster.name

get-cluster $mycluster.name | select *

#add file services feature
Add-WindowsFeature File-Services -IncludeAllSubFeature -ComputerName $computers[0]
Add-WindowsFeature File-Services -IncludeAllSubFeature -ComputerName $computers[1]

#add role
Add-ClusterFileServerRole -Cluster $mycluster.name -Storage "Cluster Disk 2" -StaticAddress 172.16.200.2/16
