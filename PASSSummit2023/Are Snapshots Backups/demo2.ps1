##Demo Setup
# - One SQL Server running 2022
# - One 3.5TB database, and three other databases 
# - The databases are on different volume and are in the same protection group
# - Using PowerShell 7

#Demo 2 - Restore one database from a set of backups
Import-Module dbatools
Import-Module PureStoragePowerShellSDK2


#Let's initalize some variables we'll use for connections to our SQL Server and it's base OS
$Target = 'aen-sql-22-a'
$TargetSession = New-PSSession -ComputerName $Target
$SqlInstance = Connect-DbaInstance -SqlInstance $Target -TrustServerCertificate -NonPooledConnection
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"



# Connect to the FlashArray's REST API
Write-Host "Establishing a session against the Pure Storage FlashArray..." -ForegroundColor Red
$FlashArray = Connect-Pfa2Array –EndPoint sn1-m70-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError



$Query = 'ALTER SERVER CONFIGURATION SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON 
          (GROUP = (FT_Demo, TPCC100, TPCH100));'
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose



#Take a snapshot of the Protection Group while the database is frozen
#This protection group contains all of the volumes for this SQL instance
$Snapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceName 'aen-sql-22-a-pg' 
$Snapshot



#Take a metadata backup of the database, this will automatically unfreeze if successful
#We'll use MEDIADESCRIPTION to hold some information about our snapshot
$BackupFile = "\\w2016-anthony\SHARE\BACKUP\SnapshotGroup_$(Get-Date -Format FileDateTime).bkm"
$Query = "BACKUP DATABASE FT_Demo BACKUP GROUP FT_Demo, TPCC100, TPCH100 
          TO DISK='$BackupFile' 
          WITH METADATA_ONLY, 
               MEDIADESCRIPTION='$($Snapshot.Name)|$($FlashArray.ArrayName)'"
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query -Verbose



#Let's check out the state of the database, size, last full and last log
#In our full don't have the new 10,000 customers...just the original set, we need both the full and the log.
Get-DbaDatabase -SqlInstance $SqlInstance -Database @('FT_Demo','TPCC100','TPCH100') | 
  Select-Object Name, Size, LastFullBackup, LastLogBackup



# Offline the database, which we'd have to do anyway if we were restoring a full backup
# Here's we're offlining just one database, rather than all
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



#With three databases in the backup meta data file, you can restore the one database by name...
# if there's more than one, just restore each one by name with three seperate restore statements
$Query = "RESTORE DATABASE FT_Demo FROM DISK = '$BackupFile' 
          WITH METADATA_ONLY, REPLACE, NORECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query -Verbose



#Let's check the current state of the database, our other two databases stayed online
Get-DbaDatabase -SqlInstance $SqlInstance -Database @('FT_Demo','TPCC100','TPCH100') | 
  Select-Object Name, Size, LastFullBackup, LastLogBackup



# Online the database
$Query = "RESTORE DATABASE FT_Demo WITH RECOVERY" 
Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $Query


# Clean up
Remove-PSSession $TargetSession
Write-Host "All done." -ForegroundColor Red
Get-DbaConnectedInstance | Disconnect-DbaInstance

