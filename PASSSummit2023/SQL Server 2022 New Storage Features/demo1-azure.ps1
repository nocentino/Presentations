################################################################################################################################################
# Demo Set up
#      1. Azure VM, running SQL Server 2022 with two disks attached, one name DATA and the other LOG
#      2. Using PowerShell 7
################################################################################################################################################
#Demo 1 - Basic Snapshot backup of a database
################################################################################################################################################
Import-Module dbatools

Connect-AzAccount -TenantId 'f17cbd44-7697-453e-941c-efe0a4c2d55a'


#Let's initalize some variables we'll use for connections to our SQL Server and it's base OS
$Location = "CentralUS"
$ResourceGroupName = "SqlSnapshots"
$Target = 'Sql1'
$TargetSession = New-PSSession -ComputerName $Target
$SqlInstance = Connect-DbaInstance -SqlInstance $Target -TrustServerCertificate -NonPooledConnection


#Let's get some information about our database
# It took me 1h:12m to do a full restore of this database on this server
Get-DbaDbFile -SqlInstance $SqlInstance -Database 'TestDB1' | 
   Select-Object PhysicalName, Size


################################################################################################################################################
#Get a reference to our SQL VM in Azure
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Target
$vm | Select-Object ResourceGroupName, Name



#Get our data and logs disk's names
$SourceDataDiskName = ($vm.StorageProfile.DataDisks | Where-Object { $_.Name -eq 'Sql1_DATA' }).Name
$SourceLogDiskName = ($vm.StorageProfile.DataDisks | Where-Object { $_.Name -eq 'Sql1_LOG' }).Name
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
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose


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
          WITH METADATA_ONLY, 
               MEDIADESCRIPTION='$($DataSnapshotName.Name)|$($DataSnapshot.Id)'"
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose
################################################################################################################################################

################################################################################################################################################
# Now, let's examine some of the metadata available to use
# Get a listing of the snapshots available to us
Get-AzSnapshot -ResourceGroupName $ResourceGroupName | Format-Table



#Let's check out the error log to see what SQL Server thinks happened, 
#...someone didn't enable TF3226 :P
Get-DbaErrorLog -SqlInstance $SqlInstance -LogNumber 0 | Format-Table



#The backup is recorded in MSDB as a Full backup with snapshot
$BackupHistory = Get-DbaDbBackupHistory -SqlInstance $SqlInstance -Database 'TestDB1' -Last
$BackupHistory



#Let's explore the stuff in the backup header...SQL Server sees this as a real backup
Read-DbaBackupHeader -SqlInstance $SqlInstance -Path $BackupFile


################################################################################################################################################
# We can now perform normal backups with the snapshot as the base
# First, let's take a regular log backup
$LogBackup = Backup-DbaDatabase -SqlInstance $SqlInstance `
  -Database 'TestDB1' `
  -Type Log `
  -Path '\\sql1\SHARE\BACKUPS\' `
  -CompressBackup



#Let's check out the state of the database, size, last full and last log
Get-DbaDatabase -SqlInstance $SqlInstance -Database 'TestDB1' | 
  Select-Object Name, Size, LastFullBackup, LastLogBackup



################################################################################################################################################
# With our snapshot and log backup, now let's begin a point in time restore
# Offline the database, which we'd have to do anyway if we were restoring a full backup
Write-Host "Offlining the database..." -ForegcroundColor Red
$Query = "ALTER DATABASE TestDB1 SET OFFLINE WITH ROLLBACK IMMEDIATE" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query



# Offline the volumes supporting that database, since these are disk level operations
Write-Host "Offlining the volume..." -ForegroundColor Red
Get-Disk -Number 2 | Set-Disk -IsOffline $True 
Get-Disk -Number 3 | Set-Disk -IsOffline $True 




#Remove the existing disks from your VM...
#I'm keeping the disk around just in case.
Remove-AzVMDataDisk -VM $vm -Name 'Sql1_DATA'
Remove-AzVMDataDisk -VM $vm -Name 'Sql1_LOG'
Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm



# Create two new Azure Virtual Disks from snapshot
# https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azdiskconfig?view=azps-10.4.1
# This starts by defining a disk configuration, key things to note, the Zone and the SourceRescourceID (this is the snapshot's ID)
# Keep in mind the previous disks configuration for performans profile and zones
# Then we pass the config into the New-AzDisk cmdlet.
$StorageType = 'Premium_LRS'
$DataDiskName = 'DATA_CLONE'
$DataDiskConfig = New-AzDiskConfig -SkuName $StorageType -Location $location -CreateOption Copy -SourceResourceId $DataSnapshot.Id -Zone 1 
$DataDisk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName -Disk $DataDiskConfig 


$LogDiskName = 'LOG_CLONE'
$LogDiskConfig = New-AzDiskConfig -SkuName $StorageType -Location $location -CreateOption Copy -SourceResourceId $LogSnapshot.Id -Zone 1 
$LogDisk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $LogDiskName -Disk $LogDiskConfig 


#Now that the disks are created with the data on the snapshot, let's attach them to the VM
Add-AzVMDataDisk -Name $DataDiskName -CreateOption Attach -VM $vm -ManagedDiskId $DataDisk.Id -Lun 1
Add-AzVMDataDisk -Name $LogDiskName -CreateOption Attach -VM $vm -ManagedDiskId $LogDisk.Id -Lun 2
Set-AzVMDataDisk -VM $vm -Name 'DATA_CLONE' -Caching ReadWrite
Update-AzVM -VM $vm -ResourceGroupName $ResourceGroupName



# Online the new volumes
Write-Host "Onlining the volume..." -ForegroundColor Red
Get-Disk -Number 2 | Set-Disk -IsOffline $False 
Get-Disk -Number 3 | Set-Disk -IsOffline $False 



# Restore the database with no recovery, which means we can restore LOG or DIFFERENTIAL native SQL Server backups 
$Query = "RESTORE DATABASE TestDB1 FROM DISK = '$BackupFile' WITH METADATA_ONLY, REPLACE, NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query -Verbose



#Let's check the current state of the database...its RESTORING
Get-DbaDbState -SqlInstance $SqlInstance -Database 'TestDB1' 



#Restore the log backup, we're using the Continue option since we didn't use a FULL as the base
Restore-DbaDatabase -SqlInstance $SqlInstance `
  -Database 'TestDB1' `
  -Path $LogBackup.BackupPath `
  -NoRecovery `
  -Continue



# Online the database, we've just completed a point in time restore
$Query = "RESTORE DATABASE TestDB1 WITH RECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query -Verbose

################################################################################################################################################
#Demo 1a - Cloning a database back to the same instance
a################################################################################################################################################
# We can also clone to new disks, leaving the database online. 
# This is great accessing data for reporting or even data recovery when you don't need to restore the whole database
#
# Create Disk from snapshot
# https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azdiskconfig?view=azps-10.4.1
# Create a new disk config, create a disk, then attach it to the VM, then set it online
$storageType = 'Premium_LRS'
$DataDiskName = 'DATA_CLONE_2'
$DataDiskConfig = New-AzDiskConfig -SkuName $storageType -Location $location -CreateOption Copy -SourceResourceId $DataSnapshot.Id -Zone 1 
$DataDisk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName -Disk $DataDiskConfig 


$LogDiskName = 'LOG_CLONE_2'
$LogDiskConfig = New-AzDiskConfig -SkuName $storageType -Location $location -CreateOption Copy -SourceResourceId $LogSnapshot.Id -Zone 1 
$LogDisk = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $LogDiskName -Disk $LogDiskConfig 


$MaxLunID = ($vm.StorageProfile.DataDisks | Select-Object Lun  -ExpandProperty Lun | Measure-Object -Maximum ).Maximum
$vm = Add-AzVMDataDisk -Name $DataDiskName -CreateOption Attach -VM $vm -ManagedDiskId $DataDisk.Id -Lun (++$MaxLunID)
$vm = Add-AzVMDataDisk -Name $LogDiskName -CreateOption Attach -VM $vm -ManagedDiskId $LogDisk.Id -Lun (++$MaxLunID)
Update-AzVM -VM $vm -ResourceGroupName $ResourceGroupName


Write-Host "Onlining the new volumes..." -ForegroundColor Red
Get-Disk -Number 4 | Set-Disk -IsOffline $False 
Get-Disk -Number 5 | Set-Disk -IsOffline $False 



#TODO: Dynamically find drive letters
Get-Volume

$fileStructure = New-Object System.Collections.Specialized.StringCollection
$fileStructure.Add("H:\DATA\Data01.mdf")
$fileStructure.Add("H:\DATA\Data02.ndf")
$fileStructure.Add("H:\DATA\Data03.ndf")
$fileStructure.Add("H:\DATA\Data04.ndf")
$fileStructure.Add("H:\DATA\Data05.ndf")
$fileStructure.Add("H:\DATA\Data06.ndf")
$fileStructure.Add("H:\DATA\Data07.ndf")
$fileStructure.Add("H:\DATA\Data08.ndf")
$filestructure.Add("I:\LOG\log.ldf")
Mount-DbaDatabase -SqlInstance $SqlInstance -Database TestDB1_RESTORE -FileStructure $fileStructure

################################################################################################################################################
# Clean up
Remove-PSSession $TargetSession
Write-Host "All done." -ForegroundColor Red

#Remove the databases
Set-DbaDbState -SqlInstance $SqlInstance -Database @('TestDB1','TestDB1_RESTORE') -Offline -Force
Remove-DbaDatabase -SqlInstance $SqlInstance -Database 'TestDB1_RESTORE' 

#Remove the snapshots from Azure
Get-DbaConnectedInstance | Disconnect-DbaInstance
Get-AzSnapshot -ResourceGroupName $ResourceGroupName | Remove-AzSnapshot -Force
Get-AzSnapshot -ResourceGroupName $ResourceGroupName 

#Offline the new disks we attached that were based off the clones
Get-Disk -Number 2 | Set-Disk -IsOffline $True 
Get-Disk -Number 3 | Set-Disk -IsOffline $True 
Get-Disk -Number 4 | Set-Disk -IsOffline $True 
Get-Disk -Number 5 | Set-Disk -IsOffline $True 


#Remove the Azure Virtual Disks (based off the clones) from the VM
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Target
Remove-AzVMDataDisk -VM $vm -Name 'DATA_CLONE'
Remove-AzVMDataDisk -VM $vm -Name 'LOG_CLONE'
Remove-AzVMDataDisk -VM $vm -Name 'DATA_CLONE_2'
Remove-AzVMDataDisk -VM $vm -Name 'LOG_CLONE_2'
Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm


#Get references to our original disks
$DataDiskInitial = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'sql1_data'
$LogDiskInitial = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'sql1_log'


#Add our original disks to our VM
Add-AzVMDataDisk -Name 'sql1_data' -CreateOption Attach -VM $vm -ManagedDiskId $DataDiskInitial.Id -Lun 1
Add-AzVMDataDisk -Name 'sql1_log' -CreateOption Attach -VM $vm -ManagedDiskId $LogDiskInitial.Id -Lun 2
Set-AzVMDataDisk -VM $vm -Name 'sql1_data' -Caching ReadWrite
Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm


#Online our disks
Get-Disk -Number 2 | Set-Disk -IsOffline $False 
Get-Disk -Number 3 | Set-Disk -IsOffline $False 


#Remove the Azure Virtual Disks based off the clones...this will DELETE these disks
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'DATA_CLONE' -Force;
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'LOG_CLONE' -Force;
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'DATA_CLONE_2' -Force;
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName 'LOG_CLONE_2' -Force;


#Online our original database
Set-DbaDbState -SqlInstance $SqlInstance -Database @('TestDB1') -Online
