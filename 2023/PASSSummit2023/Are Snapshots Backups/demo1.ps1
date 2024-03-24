##Demo Setup
# - One SQL Server running 2022
# - One 3.5TB database
# - Using PowerShell 7


#Demo 1 - Basic Snapshot backup of a database
Import-Module dbatools
Import-Module PureStoragePowerShellSDK2



#Let's initalize some variables we'll use for connections to our SQL Server and it's base OS
$Target = 'aen-sql-22-a'
$TargetSession = New-PSSession -ComputerName $Target
$SqlInstance = Connect-DbaInstance -SqlInstance $Target -TrustServerCertificate -NonPooledConnection
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"



#Let's get some information about our database
Get-DbaDatabase -SqlInstance $SqlInstance -Database 'FT_Demo' | 
  Select-Object Name, SizeMB


# Connect to the FlashArray's REST API
Write-Host "Establishing a session against the Pure Storage FlashArray..." -ForegroundColor Red
$FlashArray = Connect-Pfa2Array –EndPoint sn1-m70-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError


#Freeze the database
$Query = 'ALTER DATABASE FT_Demo SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON'
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose



#Take a snapshot of the Protection Group while the database is frozen
$Snapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceName 'aen-sql-22-a-pg' 
$Snapshot



#Take a metadata backup of the database, this will automatically unfreeze if successful
#We'll use MEDIADESCRIPTION to hold some information about our snapshot
$BackupFile = "\\w2016-anthony\SHARE\BACKUP\FT_Demo_$(Get-Date -Format FileDateTime).bkm"
$Query = "BACKUP DATABASE FT_Demo 
          TO DISK='$BackupFile' 
          WITH METADATA_ONLY, 
               MEDIADESCRIPTION='$($Snapshot.Name)|$($FlashArray.ArrayName)'"
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose



#Let's check out the error log to see what SQL Server thinks happened
Get-DbaErrorLog -SqlInstance $SqlInstance -LogNumber 0 | Format-Table



#The backup is recorded in MSDB as a Full backup with snapshot
$BackupHistory = Get-DbaDbBackupHistory -SqlInstance $SqlInstance -Database 'FT_Demo' -Last
$BackupHistory



#Let's explore the stuff in the backup header...
#Remember, VDI is just a contract saying what's in the backup matches what SQL Server thinks is in the backup.
Read-DbaBackupHeader -SqlInstance $SqlInstance -Path $BackupFile



#Let's take a log backup
$LogBackup = Backup-DbaDatabase -SqlInstance $SqlInstance `
  -Database 'FT_Demo' `
  -Type Log `
  -Path '\\w2016-anthony\SHARE\BACKUP' `
  -CompressBackup



#Delete a table...I should update my resume, right? :P 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database FT_Demo -Query "DROP TABLE customer"



#Let's check out the state of the database, size, last full and last log
Get-DbaDatabase -SqlInstance $SqlInstance -Database 'FT_Demo' | 
  Select-Object Name, Size, LastFullBackup, LastLogBackup



# Offline the database, which we'd have to do anyway if we were restoring a full backup
Write-Host "Offlining the database..." -ForegcroundColor Red
$Query = "ALTER DATABASE FT_DEMO SET OFFLINE WITH ROLLBACK IMMEDIATE" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query



# Offline the volume
Write-Host "Offlining the volume..." -ForegroundColor Red
Invoke-Command -Session $TargetSession `
  -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq '6000c29240f79ca82ef017e1fdc000a7' } | Set-Disk -IsOffline $True }



#We can get the snapshot name from the $Snapshot variable above, but what if we didn't know this ahead of time?
#We can also get the snapshot name from the MEDIADESCRIPTION in the backup file. 
$Query = "RESTORE LABELONLY FROM DISK = '$BackupFile'"
$Labels = Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose
$SnapshotName = (($Labels | Select-Object MediaDescription -ExpandProperty MediaDescription).Split('|'))[0]
$ArrayName = (($Labels | Select-Object MediaDescription -ExpandProperty MediaDescription).Split('|'))[1]
$SnapshotName
$ArrayName



#Restore the snapshot over the volume
Write-Host "Restore the snapshot over the current volume" -ForegroundColor Red
New-Pfa2Volume -Array $FlashArray `
  -Name "vvol-aen-sql-22-a-1-3d9acfdd-vg/Data-cabce242" `
  -SourceName ($SnapshotName + ".vvol-aen-sql-22-a-1-3d9acfdd-vg/Data-cabce242") `
  -Overwrite $true



# Online the volume
Write-Host "Onlining the volume..." -ForegroundColor Red
Invoke-Command -Session $TargetSession `
  -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq '6000c29240f79ca82ef017e1fdc000a7' } | Set-Disk -IsOffline $False }



# Restore the database with no recovery, which means we can restore LOG or DIFFERENTIAL native SQL Server backups 
$Query = "RESTORE DATABASE FT_Demo FROM DISK = '$BackupFile' WITH METADATA_ONLY, REPLACE, NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query -Verbose



#Let's check the current state of the database...its RESTORING
Get-DbaDbState -SqlInstance $SqlInstance -Database 'FT_Demo' 



#Restore the log backup.
Restore-DbaDatabase -SqlInstance $SqlInstance `
  -Database 'FT_Demo' `
  -Path $LogBackup.BackupPath `
  -NoRecovery `
  -Continue



# Online the database
$Query = "RESTORE DATABASE FT_Demo WITH RECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query


#Let's see if our table is back in our database...
#whew...we don't have to tell anybody since our restore was so fast :P 
Get-DbaDbTable -SqlInstance $SqlInstance -Database 'FT_Demo' -Table 'Customer' | Format-Table



#How long does this process take? 

$Start = (Get-Date)
#Freeze the database (add a measure command)
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query 'ALTER DATABASE FT_Demo SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON' 


#Take a snapshot of the Protection Group
$Snapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceName 'aen-sql-22-a-pg' 


#Take a metadata backup of the database, this will automatically unfreeze if successful
#We'll use MEDIADESCRIPTION to hold some information about our snapshot
$BackupFile = "\\w2016-anthony\SHARE\BACKUP\FT_Demo_$(Get-Date -Format FileDateTime).bkm"
$Query = "BACKUP DATABASE FT_Demo TO DISK='$BackupFile' WITH METADATA_ONLY, MEDIADESCRIPTION='$($Snapshot.Name)|$($FlashArray.ArrayName)'"
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query

$Stop = (Get-Date)

Write-Output "The snapshot time takes...$(($Stop - $Start).Milliseconds)ms!"



# Clean up
Remove-PSSession $TargetSession
Write-Host "All done." -ForegroundColor Red
Get-DbaConnectedInstance | Disconnect-DbaInstance