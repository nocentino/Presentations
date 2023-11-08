#Demo 3 - Seeding and AG
# Restore a database from storage snapshot and leave it in recovery for AG Seeding
Import-Module dbatools
Import-Module PureStoragePowerShellSDK2


##Pre-requisites
#1 - Snapshot replication between arrays.
#2 - You've disabled or are in some other way accounting for log backups during the seeding process.
#3 - You already have the AG up and running, with both instances configured as replicas,
#4 - The database you want to seed is online on the primary, but not on the secondary at all.


#Set up some variables and sessions to talk to the replicas in the AG
$Primary = 'aen-sql-22-c'
$Secondary = 'aen-sql-22-d'
$SecondaryPsSession = New-PSSession -ComputerName $Secondary
$SqlInstancePrimary = Connect-DbaInstance -SqlInstance $Primary -TrustServerCertificate -NonPooledConnection 
$SqlInstanceSecondary = Connect-DbaInstance -SqlInstance $Secondary -TrustServerCertificate -NonPooledConnection 
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"



# Connect to the FlashArray with for the AG Primary
$FlashArrayPrimary = Connect-Pfa2Array –EndPoint sn1-m70-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError



#Freeze the database 
$Query = 'ALTER DATABASE FT_Demo SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Query $Query -Verbose



#Take a snapshot of the Protection Group, and replicate it to our other array
$PrimarySnapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArrayPrimary `
    -SourceName 'aen-sql-22-c-pg' `
    -ForReplication $true `
    -ReplicateNow $true



#Take a metadata backup of the database, this will automatically unfreeze if successful
#We'll use MEDIADESCRIPTION to hold some information about our snapshot
$BackupFile = "\\w2016-anthony\SHARE\BACKUP\FT_Demo_$(Get-Date -Format FileDateTime).bkm"
$Query = "BACKUP DATABASE FT_Demo 
          TO DISK='$BackupFile' 
          WITH METADATA_ONLY, 
               MEDIADESCRIPTION='$($PrimarySnapshot.Name)|$($FlashArrayPrimary.ArrayName)'"
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Query $Query -Verbose




# Connect to the FlashArray's REST API where the secondary's data is located
Write-Host "Establishing a session against the target Pure Storage FlashArray..." -ForegroundColor Red
$FlashArraySecondary = Connect-Pfa2Array –EndPoint sn1-x70-f06-27.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError

Write-Warning "Obtaining the most recent snapshot for the protection group..."
$TargetSnapshot = $null
do {
    Write-Warning "Waiting for snapshot to replicate to target array..."
    $TargetSnapshot = Get-Pfa2ProtectionGroupSnapshotTransfer -Array $FlashArraySecondary -Name 'sn1-m70-f06-33:aen-sql-22-c-pg' | 
            Where-Object { $_.Name -eq "sn1-m70-f06-33:$($PrimarySnapshot.name)" } 

    if ( $TargetSnapshot -and $TargetSnapshot.progress -ne 1.0 ){
        Write-Warning "Snapshot $($TargetSnapshot.Name) found on Target Array...replication progress is $($TargetSnapshot.progress)"
    }    
   Start-Sleep 3

} while ( [string]::IsNullOrEmpty($TargetSnapshot.Completed) -or ($TargetSnapshot.progress -ne 1.0) )
Write-Warning "Snapshot $($TargetSnapshot.Name) replicated on Target Array. Completed at $($TargetSnapshot.Completed)"



#Check the snapshot names
$PrimarySnapshot.Name
$TargetSnapshot.Name


# Offline the volumes on the Secondary
Invoke-Command -Session $SecondaryPsSession `
    -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq '6000c29668589f61a386218139e21bb0' } | Set-Disk -IsOffline $True }



#Overwrite the volumes on the Secondary from the protection group snapshot
Write-Host "Restore the snapshot over the current volume" -ForegroundColor Red
New-Pfa2Volume -Array $FlashArraySecondary `
    -Name 'vvol-aen-sql-22-d-7050d50f-vg/Data-fd4e545a' `
    -SourceName ($TargetSnapshot.Name + ".vvol-aen-sql-22-c-a55a37f5-vg/Data-c8f8057c") `
    -Overwrite $true



# Online the volumes on the Secondary
Invoke-Command -Session $SecondaryPsSession `
    -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq '6000c29668589f61a386218139e21bb0' } | Set-Disk -IsOffline $False }



# Restore the database with no recovery 
$Query = "RESTORE DATABASE FT_Demo FROM DISK = '$BackupFile' WITH METADATA_ONLY, REPLACE, NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Database master -Query $Query -Verbose



#Take a log backup on the Primary
$Query = "BACKUP LOG FT_DEMO TO DISK = '\\w2016-anthony\SHARE\BACKUP\FT_Demo-seed.trn' WITH FORMAT, INIT" 
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query -Verbose



#Restore it on the Secondary
$Query = "RESTORE LOG FT_DEMO FROM DISK = '\\w2016-anthony\SHARE\BACKUP\FT_Demo-seed.trn' WITH NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Database master -Query $Query -Verbose



#Set the seeding mode on the Seconary to manual
$Query = 'ALTER AVAILABILITY GROUP [ag1] MODIFY REPLICA ON N''aen-sql-22-c'' WITH (SEEDING_MODE = MANUAL)'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query -Verbose



#Add the database to the AG
$Query = 'ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [FT_Demo];'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query -Verbose


#Start data movement
$Query='ALTER DATABASE [FT_Demo] SET HADR AVAILABILITY GROUP = [ag1];'
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Database master -Query $Query -Verbose


###Now, let's backup our AG

#Backup on the primary, freeze the database 
$Query = 'ALTER DATABASE FT_Demo SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Query $Query -Verbose



#Take a snapshot of the Protection Group, and replicate it to our other array
$PrimarySnapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArrayPrimary `
    -SourceName 'aen-sql-22-c-pg' `
    -ForReplication $true `
    -ReplicateNow $true



#Take a metadata backup of the database, this will automatically unfreeze if successful
$BackupFile = "\\w2016-anthony\SHARE\BACKUP\FT_Demo_$(Get-Date -Format FileDateTime).bkm"
$Query = "BACKUP DATABASE FT_Demo 
          TO DISK='$BackupFile' 
          WITH METADATA_ONLY, 
               MEDIADESCRIPTION='$($PrimarySnapshot.Name)|$($FlashArrayPrimary.ArrayName)'"
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Query $Query -Verbose


#Let's check out the error log to see what SQL Server thinks happened
Get-DbaErrorLog -SqlInstance $SqlInstancePrimary -LogNumber 0 | Format-Table



#The backup is recorded in MSDB as a Full backup with snapshot
$BackupHistory = Get-DbaDbBackupHistory -SqlInstance $SqlInstancePrimary -Database 'FT_Demo' -Last
$BackupHistory


#You cannot backup on the secondary...
#you'll get this error: The operation cannot be performed on database "FT_Demo" because it is
#involved in a database mirroring session or an availability group. Some operations are not allowed on a database that is participating in a database
#mirroring session or in an availability group.
$Query = 'ALTER DATABASE FT_Demo SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON'
Invoke-DbaQuery -SqlInstance $SqlInstanceSecondary -Query $Query -Verbose


###What would a restore into an AG look like?
# 0. You have to have a snapshot that you want to restore from, just like any other full backup...you need to have them to restore with
# 1. Remove the database from the AG
# 2. Restore from snapshot on the primary using "RESTORE DATABASE FT_Demo FROM DISK = '$BackupFile' WITH METADATA_ONLY" and any needed diffs and logs
# 3. Now, start the seeding process above, freeze the database
# 4. Take the snapshot of the primary's volume
# 5. Take the metadata_only backup on the primary
# 6. Replicate the snapshot
# 7. Offline the volume(s) on the secondary
# 8. Restore the snapshot on the secondary, with NORECOVERY
# 9. Finish seeding the AG take transaction log backup on the primary
# 10. Restore the transaction log backup on the secondary
# 11. Join the DB to the AG
# 12. Start data movement





#RESET DEMO by removing database from the AG
Get-DbaConnectedInstance | Disconnect-DbaInstance
Remove-PSSession $SecondaryPsSession
$Query = 'ALTER AVAILABILITY GROUP [ag1]
REMOVE DATABASE [FT_Demo];'
Invoke-DbaQuery -SqlInstance $SqlInstancePrimary -Database master -Query $Query
Remove-DbaDatabase -SqlInstance $SqlInstanceSecondary -Database FT_DEMO -Confirm:$false 
