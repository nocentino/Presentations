################################################################################################################################################
# Demo Set up
#      1. Azure VM, running SQL Server 2022 with two disks attached, one name DATA and the other LOG
#      2. Using PowerShell 7
#      3. Availability Group is already created
################################################################################################################################################
#Demo 1 - Basic Snapshot backup of a database
################################################################################################################################################
Import-Module dbatools

Connect-AzAccount -TenantId 'f17cbd44-7697-453e-941c-efe0a4c2d55a'


#Let's initalize some variables we'll use for connections to our SQL Server and it's base OS
$Location = "CentralUS"
$ResourceGroupName = "SqlSnapshots"
$PrimaryReplica = 'Sql1'
$SecondaryReplica = 'Sql2'
$SecondaryPsSession = New-PSSession -ComputerName $SecondaryReplica
$SqlInstancePrimary = Connect-DbaInstance -SqlInstance $PrimaryReplica -TrustServerCertificate -NonPooledConnection 
$SqlInstanceSecondary = Connect-DbaInstance -SqlInstance $SecondaryReplica -TrustServerCertificate -NonPooledConnection 
################################################################################################################################################
#Get a reference to our SQL VM in Azure for the primary replica
$Sql1vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $PrimaryReplica
$Sql2vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $SecondaryReplica
$Sql1vm | Select-Object ResourceGroupName, Name
$Sql2vm | Select-Object ResourceGroupName, Name



#Get our data and logs disk's names
$SourceDataDiskName = ($Sql1vm.StorageProfile.DataDisks | Where-Object { $_.Name -eq 'sql1_data' }).Name
$SourceLogDiskName = ($Sql1vm.StorageProfile.DataDisks | Where-Object { $_.Name -eq 'sql1_log' }).Name
$SourceDataDiskName
$SourceLogDiskName
 


#Use the names to get a reference to the Azure Virtual Disk resource...this will become the base of our clone operation
$SourceDataDisk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $SourceDataDiskName
$SourceLogDisk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $SourceLogDiskName
$SourceDataDisk.Id
$SourceLogDisk.Id

################################################################################################################################################
# Let's create a snapshot config, this defines the configuration parameters for the snapshot, such as its source and location.
# You can use optionally useSKUName to specify a disk type with replication.
$DataSnapshot =  New-AzSnapshotConfig `
    -SourceUri $SourceDataDisk.Id `
    -Location $location `
    -CreateOption Copy
$DataSnapshot

$LogSnapshot =  New-AzSnapshotConfig `
    -SourceUri $SourceLogDisk.Id `
    -Location $location `
    -CreateOption Copy
$LogSnapshot


################################################################################################################################################
#Freeze the database, since this is in the data tier, we can get consistent snapshots across two disks
$Query = 'ALTER DATABASE TestDB1 SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Query $Query -Verbose


#And now, lets take a snapshot of each disk...notice that this is fast and not based on the size of data
$DataSnapshotName = "Sql1_DATA_$(Get-Date -Format FileDateTime)"
$DataSnapshot = New-AzSnapshot `
    -Snapshot $DataSnapshot `
    -SnapshotName $DataSnapshotName `
    -ResourceGroupName $ResourceGroupName

$LogSnapshotName = "Sql1_LOG_$(Get-Date -Format FileDateTime)"
$LogSnapshot = New-AzSnapshot `
    -Snapshot $LogSnapshot `
    -SnapshotName $LogSnapshotName `
    -ResourceGroupName $ResourceGroupName


#Take a metadata backup of the database, this will automatically unfreeze if successful
#We'll use MEDIADESCRIPTION to hold some information about our snapshot
$BackupFile = "\\sql1\SHARE\BACKUPS\$($DataSnapshotName).bkm"
$Query = "BACKUP DATABASE TestDB1 
          TO DISK='$BackupFile' 
          WITH METADATA_ONLY, INIT,
               MEDIADESCRIPTION='$($DataSnapshotName.Name)|$($DataSnapshot.Id)'"
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Query $Query -Verbose


################################################################################################################################################
#Seeding the secondary replica from snapshot
# Offline the volumes supporting that database, since these are disk level operations
Write-Host "Offlining the volume on the secondary replica..." -ForegroundColor Red
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 2 | Set-Disk -IsOffline $True }
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 3 | Set-Disk -IsOffline $True }


#If there's existing disks on your Secondary replicat, create new or remove them, here we're removing them
#I'm keeping the disk around just in case.
Remove-AzVMDataDisk -VM $Sql2vm -Name 'sql2_data'
Remove-AzVMDataDisk -VM $Sql2vm -Name 'sql2_log'
Update-AzVM -ResourceGroupName $ResourceGroupName -VM $Sql2vm



# Create two new Azure Virtual Disks from snapshot
# https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azdiskconfig?view=azps-10.4.1
# This starts by defining a disk configuration, key things to note, the Zone and the SourceRescourceID (this is the snapshot's ID)
# Keep in mind the previous disks configuration for performans profile and zones
# Then we pass the config into the New-AzDisk cmdlet.
$StorageType = 'Premium_LRS'
$DataDiskName = 'sql1_data_CLONE'
$DataDiskConfig = New-AzDiskConfig -SkuName $StorageType -Location $location -CreateOption Copy -SourceResourceId $DataSnapshot.Id -Zone 1 
$DataDisk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName -Disk $DataDiskConfig 


$LogDiskName = 'sql1_log_CLONE'
$LogDiskConfig = New-AzDiskConfig -SkuName $StorageType -Location $location -CreateOption Copy -SourceResourceId $LogSnapshot.Id -Zone 1 
$LogDisk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $LogDiskName -Disk $LogDiskConfig 


#Now that the disks are created with the data on the snapshot, let's attach them to the VM
Add-AzVMDataDisk -Name $DataDiskName -CreateOption Attach -VM $Sql2vm -ManagedDiskId $DataDisk.Id -Lun 1
Add-AzVMDataDisk -Name $LogDiskName  -CreateOption Attach -VM $Sql2vm -ManagedDiskId $LogDisk.Id  -Lun 2
Set-AzVMDataDisk -VM $Sql2vm -Name 'sql1_data_CLONE' -Caching ReadWrite
Update-AzVM -VM $Sql2vm -ResourceGroupName $ResourceGroupName


# Online the new volumes
Write-Host "Onlining the volume..." -ForegroundColor Red
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 2 | Set-Disk -IsOffline $False }
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 3 | Set-Disk -IsOffline $False }



# Restore the database with no recovery, which means we can restore LOG or DIFFERENTIAL native SQL Server backups 
$Query = "RESTORE DATABASE TestDB1 FROM DISK = '$BackupFile' WITH METADATA_ONLY, REPLACE, NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Database master -Query $Query -Verbose



#Take a log backup on the Primary
$Query = "BACKUP LOG TestDB1 TO DISK = '\\sql1\SHARE\BACKUPS\TestDB1-seed.trn' WITH FORMAT, INIT" 
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query -Verbose



#Restore it on the Secondary
$Query = "RESTORE LOG TestDB1 FROM DISK = '\\sql1\SHARE\BACKUPS\TestDB1-seed.trn' WITH NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Database master -Query $Query -Verbose



#Set the seeding mode on the Seconary to manual
$Query = 'ALTER AVAILABILITY GROUP [ag1] MODIFY REPLICA ON N''sql2'' WITH (SEEDING_MODE = MANUAL)'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query -Verbose



#Add the database to the AG
$Query = 'ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [TestDB1];'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query -Verbose



#Start data movement
$Query='ALTER DATABASE [TestDB1] SET HADR AVAILABILITY GROUP = [ag1];'
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Database master -Query $Query -Verbose

####CHECK OUT THE STATUS IN SSMS

################################################################################################################################################
# Clean up
#Remove the database from the secondary
Remove-DbaAgDatabase -SqlInstance $SqlInstancePrimary -AvailabilityGroup ag1 -Database TestDB1 -Confirm:$false
Remove-DbaDatabase -SqlInstance $SqlInstanceSecondary -Database 'TestDB1' -Confirm:$false

#Remove the snapshots from Azure
Get-AzSnapshot -ResourceGroupName $ResourceGroupName | Remove-AzSnapshot -Force
Get-AzSnapshot -ResourceGroupName $ResourceGroupName 


#Offline our disks on the secondary replica
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 2 | Set-Disk -IsOffline $True }
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 3 | Set-Disk -IsOffline $True }


#Remove the Azure Virtual Disks (based off the clones) from the VM
$Sql2vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $SecondaryReplica
Remove-AzVMDataDisk -VM $Sql2vm -Name 'sql1_data_CLONE'
Remove-AzVMDataDisk -VM $Sql2vm -Name 'sql1_log_CLONE'
Update-AzVM -ResourceGroupName $ResourceGroupName -VM $Sql2vm


#Get references to our original disks
$DataDiskInitial = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'sql2_data'
$LogDiskInitial = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'sql2_log'


#Add our original disks to our VM
Add-AzVMDataDisk -Name 'sql2_data' -CreateOption Attach -VM $Sql2vm -ManagedDiskId $DataDiskInitial.Id -Lun 1
Add-AzVMDataDisk -Name 'sql2_log' -CreateOption Attach -VM $Sql2vm -ManagedDiskId $LogDiskInitial.Id -Lun 2
Set-AzVMDataDisk -VM $Sql2vm -Name 'sql2_data' -Caching ReadWrite
Update-AzVM -ResourceGroupName $ResourceGroupName -VM $Sql2vm


#Online our disks
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 2 | Set-Disk -IsOffline $False }
Invoke-Command -Session $SecondaryPsSession { Get-Disk -Number 3 | Set-Disk -IsOffline $False }


#Remove the Azure Virtual Disks based off the clones...this will DELETE these disks
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'sql1_data_CLONE' -Force;
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'sql1_log_CLONE' -Force;


#Disconnect from SQL Server
Get-DbaConnectedInstance | Disconnect-DbaInstance
