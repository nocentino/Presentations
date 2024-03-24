#######################################################################################################################################
# Anthony E. Nocentino
# Centino Systems
# aen@centinosystems.com
# Platform: PowerShell on Windows, Mac or Linux
#######################################################################################################################################
#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
$PASSWORD='S0methingS@Str0ng!'

#######################################################################################################################################
#Environment setup
#######################################################################################################################################
#Let's start up a few containers
#Start up a container with a Data Volume
docker run `
    --name "sql1" `
    --hostname "sql1" `
    -e "ACCEPT_EULA=Y" `
    -e "MSSQL_SA_PASSWORD=$PASSWORD" `
    -p 1433:1433 `
    -v sqldata1_0:/var/opt/mssql `
    -v sqlbackups:/backups `
    -d mcr.microsoft.com/mssql/server:2022-RTM-CU2-ubuntu-20.04

docker run `
    --name "sql2" `
    --hostname "sql2" `
    -e "ACCEPT_EULA=Y" `
    -e "MSSQL_SA_PASSWORD=$PASSWORD" `
    -p 1434:1433 `
    -v sqldata2_0:/var/opt/mssql `
    -v sqlbackups:/backups `
    -d mcr.microsoft.com/mssql/server:2022-RTM-CU2-ubuntu-20.04

#######################################################################################################################################
# Use Case 1 - Building Connections - Working with Connect-DbaInstance 
#   - Persistent connection to your instance which can be used over and over again.
#   - Can give you a ton of information about your instance.
#   - Its a SMO object so you can do things that may not yet be implemented in dbatools
#######################################################################################################################################
#Yea, I'm using sa...don't judge :P 
$sqluser = 'sa' 
$sqlpasswd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
$SqlCredential = New-Object System.Management.Automation.PSCredential ($sqluser, $sqlpasswd)


#My first favorite cmdlet lets you persist a connection between executions
$SqlInstance = Connect-DbaInstance -SqlInstance "localhost,1433" -SqlCredential $SqlCredential
$SqlInstance


#You can see the connection here and it's its SPIDs.
Get-DbaProcess -SqlInstance $SqlInstance -ExcludeSystemSpids | 
    Where-Object { $_.Program -eq 'dbatools PowerShell module - dbatools.io' }


#The connection is a SMO object. 
$SqlInstance | Get-Member | more


#Its got a ton of info and also can be used for things not yet implemented in dbatools
$SqlInstance.Databases | Format-Table


#######################################################################################################################################




#######################################################################################################################################
# Use Case 2 - Getting information - Using the Get-* cmdlets - Get-DbaDatabase
#   - Let's get a listing of what's on this instance...just the system databases. 
#   - This is using our $SqlInstance variable - so it's using the existing SMO object and doesn't require authentication again. 
#   - Get for inventory and auditing...like when was the last backup and much more.
#   - Core to migration techniques since you can pipe output into other cmdlets to create objects on other instances
#######################################################################################################################################
Get-Command -Module dbatools -Verb Get

Get-DbaDatabase -SqlInstance $SqlInstance | Format-Table


#######################################################################################################################################




#######################################################################################################################################
# Use Case 3 - Back to the future with Restore-DbaDatabase
# The most versitile cmdlet in the bunch. Supports many use cases...
#   - Restore all databases.
#   - Foundation to migration scenarios
#   - Restoring a subset of backups, and in this example we're restoring from Azure Blob.
#   - Restoring from object (blob) and building a restore sequence without msdb 
#   - Selecting a subset of databases from a stack of backups - default cmdlet does not support this.
#    
#    Why would I want to do any of this? Disaster recovery scenarios!!!
#    Also, supports complex restore patterns - file group, page, point in time ... with a much simpler syntax
#######################################################################################################################################
#Restoring all backups from a set of backups
docker exec -t sql1 sh -c "ls -lahR /backups/sqlbackups"
Restore-DbaDatabase -SqlInstance $SqlInstance -Path "/backups/sqlbackups" -WithReplace
Get-DbaDatabase -SqlInstance $SqlInstance | Format-Table


#This is basically how I've migrated every SQL Server instance since the year 2016...take full backups of the source instance...
$databases = @('TPCC','TPCH')
$FullBackups = Backup-DbaDatabase -SqlInstance $SqlInstance -Database $databases -Type Full -CompressBackup -Path '/backups/sqlbackups/migrate/' 
$FullBackups
$FullBackups | Select-Object *

#Restore them the target instance sql2...leave the databases in recovery 
$FullBackups | Restore-DbaDatabase -SqlInstance 'localhost,1434' -SqlCredential $SqlCredential -NoRecovery -WithReplace


#Check the databases' status
Get-DbaDatabase -SqlInstance 'localhost,1434' -SqlCredential $SqlCredential  | Format-Table


#Now at cutover time...stop your applications and take a differential backup on the source instance
$DiffBackups = Backup-DbaDatabase -SqlInstance $SqlInstance -Database $databases -Type Differential -CompressBackup -Path '/backups/sqlbackups/migrate/'
$DiffBackups
$DiffBackups | Select-Object * 


#Set the source databases offline
Set-DbaDbState -SqlInstance $SqlInstance -Database $databases -Offline -Confirm:$false | Format-Table


#Restore it on the target instance and bring the databases online
$DiffBackups | Restore-DbaDatabase -SqlInstance 'localhost,1434' -SqlCredential $SqlCredential -Continue


#Check the databases' status
Get-DbaDatabase -SqlInstance 'localhost,1434' -SqlCredential $SqlCredential  | Format-Table


#Clean up from this demo before moving to the next set of demos
Set-DbaDbState -SqlInstance $SqlInstance -Database $databases -Online
docker rm -f sql2
docker volume rm sqldata2_0




#Let's look at restoring a subset of backups and in this example its from object, could be from any data store...smb, s3, nfs.
#Set up the credential in the SQL Server instance...using a SAS Token here
$ResourceGroupName = 'AzureBackupRG_eastus2_1'
$StorageAccountName = 'testdbaen'
$BlobContainerName = 'testdb'
$AccountKeys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName 
$StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $AccountKeys[0].Value
$sas = New-AzStorageContainerSASToken -name $BlobContainerName -Policy AutomatedRestore -Context $StorageContext
$container = Get-AzStorageContainer -Context $StorageContext -Name $BlobContainerName  
$cbc = $container.CloudBlobContainer 
Write-Host 'Shared Access Signature= '$($sas.Substring(1))''  


#Build our instance's CREDENTIAL for access to blob
$Query = "CREATE CREDENTIAL [{0}] WITH IDENTITY='Shared Access Signature', SECRET='{1}'" -f $cbc.Uri,$sas.Substring(1)   
Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Query $Query
Get-DbaCredential -SqlInstance $SqlInstance -SqlCredential $SqlCredential  -Name $cbc.Uri | 
    Where-Object { $_.Identity -eq 'Shared Access Signature' }


#Run some backups to blob...I'm using -WhatIf to spare you the wait time
Backup-DbaDatabase -SqlInstance $SqlInstance -CompressBackup -AzureBaseUrl 'https://testdbaen.blob.core.windows.net/testdb' -Type Full -WhatIf


#Let's check out the backups in our blob container, getting a listing of the files in the blob container
Get-AzStorageBlob -Container $BlobContainerName -Context $StorageContext -Blob "*.bak"


#Let's get a smaller listing of backups from our blob container...
#Why would I want to limit the number of backup files when building the restore sequence? 
$DaysBack = 14
$DateBack = (Get-Date).ToUniversalTime().AddDays(-$DaysBack)
$BlobsToRestoreFrom = Get-AzStorageBlob -Container $BlobContainerName -Context $storageContext -Blob "*.bak" |  
    Where-Object { $_.LastModified -gt $DateBack }


#A much smaller set of backups to build the backup set from...saves time, right? 
$BlobsToRestoreFrom


#Build a list of backup files available in URI/Name format
$FilesToRestore = @()
foreach ( $Blob in $BlobsToRestoreFrom ){
    $FilesToRestore += "$($cbc.Uri.AbsoluteUri)/$($Blob.Name)"
}
$FilesToRestore


#Build the backup set from our files in our blob container using Get-DbaBackupInformation 
$BackupHistory = Get-DbaBackupInformation `
    -SqlInstance $SqlInstance `
    -DatabaseName @('TPCC','TPCH') `
    -Path $FilesToRestore


#Now that we've reconstructed to backup history...
$BackupHistory
$BackupHistory | Select-Object * 


#We can build a restore sequence and execute the restore or script it to file...i'm only scripting this out to save you the pain of watching the restores :) 
$BackupHistory | Restore-DbaDatabase -SqlInstance $SqlInstance -WithReplace -OutputScriptOnly


#######################################################################################################################################
# Use case 4 - Bringing balance to the force with - Invoke-DbaBalanceDataFiles
#    - Its common to walk into a customer site and all the database objects are in one data file in the primary file group.
#    - Breaking databases into multiple files enables advanced data management techniques 
#    - Specifically, this can help with IO and backup/restore performance.
#    - https://www.nocentino.com/posts/2015-04-21-moving-sql-server-data-between-file-groups/
#    - https://www.nocentino.com/posts/2015-04-28-moving-sql-server-data-between-filegroups-part-2-the-implementation/
#######################################################################################################################################

#Let's check out the database file layout...to get parallelism we need to get lots of database files
Get-DbaDbFile -SqlInstance $SqlInstance -Database TPCH | 
    Select-Object Database,FileGroupName,TypeDescription,LogicalName,PhysicalName,Size,UsedSpace | Format-Table


#Let's tear down our container and add four volumes...we're gonna leave the current volume sqldata1_0 for sql1 intact 
docker stop sql1
docker rm sql1
docker volume ls 

docker run `
    --name "sql1" `
    --hostname "sql1" `
    -e "ACCEPT_EULA=Y" `
    -e "MSSQL_SA_PASSWORD=$PASSWORD" `
    -p 1433:1433 `
    -v sqldata1_0:/var/opt/mssql `
    -v sqldata1_1:/var/opt/mssql/data1 `
    -v sqldata1_2:/var/opt/mssql/data2 `
    -v sqldata1_3:/var/opt/mssql/data3 `
    -v sqldata1_4:/var/opt/mssql/data4 `
    -v sqlbackups:/backups `
    -d mcr.microsoft.com/mssql/server:2022-RTM-CU2-ubuntu-20.04


#Make a new connection to the "new" instance.
$SqlInstance = Connect-DbaInstance -SqlInstance "localhost,1433" -SqlCredential $SqlCredential
$SqlInstance


#Let's get a listing of what's on this instance
Get-DbaDatabase -SqlInstance $SqlInstance | Format-Table


#Let's look at the file layout one more time
Get-DbaDbFile -SqlInstance $SqlInstance -Database TPCH | 
    Select-Object Database,FileGroupName,TypeDescription,LogicalName,PhysicalName,Size,UsedSpace | Format-Table


#Add one file per volume in the new file group...we'll need to set the permissions on the directories so the mssql user can create files
docker exec sql1 bash -c "ls -lah /var/opt/mssql"
docker exec -t -u 0 sql1 bash -c "chown mssql /var/opt/mssql/data{1..4}"
Invoke-DbaQuery -SqlInstance $SqlInstance -Database TPCH -Query "ALTER DATABASE TPCH ADD FILE (NAME = file_1, FILENAME = '/var/opt/mssql/data1/tpch_file1.ndf', SIZE = 1024MB) TO FILEGROUP [PRIMARY];"
Invoke-DbaQuery -SqlInstance $SqlInstance -Database TPCH -Query "ALTER DATABASE TPCH ADD FILE (NAME = file_2, FILENAME = '/var/opt/mssql/data2/tpch_file2.ndf', SIZE = 1024MB) TO FILEGROUP [PRIMARY];"
Invoke-DbaQuery -SqlInstance $SqlInstance -Database TPCH -Query "ALTER DATABASE TPCH ADD FILE (NAME = file_3, FILENAME = '/var/opt/mssql/data3/tpch_file3.ndf', SIZE = 1024MB) TO FILEGROUP [PRIMARY];"
Invoke-DbaQuery -SqlInstance $SqlInstance -Database TPCH -Query "ALTER DATABASE TPCH ADD FILE (NAME = file_4, FILENAME = '/var/opt/mssql/data4/tpch_file4.ndf', SIZE = 1024MB) TO FILEGROUP [PRIMARY];"
docker exec sql1 bash -c "ls -lah /var/opt/mssql/data{1..4}"


#Let's check out the database file layout...to get parallelism we need to get lots of database files...but the four new files are emtpy.
Get-DbaDbFile -SqlInstance $SqlInstance -Database TPCH | 
    Select-Object Database,FileGroupName,TypeDescription,LogicalName,PhysicalName,Size,UsedSpace | 
    Format-Table


#Balance the data into the new files. -Force is needed to override a space check that is Windows specific. Takes about a minute. Currently this only supports rebuilding into the same file group. 
Invoke-DbaBalanceDataFiles -SqlInstance $SqlInstance -Database TPCH -Verbose -Force


#Are the files balanced? Close enough, some objects such as heaps are ignored. 
Get-DbaDbFile -SqlInstance $SqlInstance -Database TPCH | 
    Select-Object Database,FileGroupName,TypeDescription,LogicalName,PhysicalName,Size,UsedSpace | 
    Format-Table


#######################################################################################################################################
# Use Case 5 - IT'S ALIVE!!! - Building an availability group in code
#   - Generally a complex dba task that's done in a user interface or a whole boat load of tsql using sqlcmd to hit the multiple replicas
#   - This involves networking knowledge, authentication (AD/Certificates), and seeding databases.
#   - I'm doing this in containers b/c I'm so tired of VMs :P But on this all works just the same on Windows. 
#   - You can use the FailoverClusters module's cmdlets to create a windows cluster if needed
#######################################################################################################################################
docker stop sql1 
docker rm sql1


#Create a docker network 
docker network create agnetwork


#This time, let's start our container but on this docker network...this helps with addressing hosts by name.
#We're also setting MSSQL_ENABLE_HADR to 1 so we can use AGs.
docker run `
    --name "sql1" `
    --hostname "sql1" `
    --net agnetwork `
    -e "ACCEPT_EULA=Y" `
    -e "MSSQL_ENABLE_HADR=1" `
    -e "MSSQL_SA_PASSWORD=$PASSWORD" `
    -p 1433:1433 `
    -v sqldata1_0:/var/opt/mssql `
    -v sqldata1_1:/var/opt/mssql/data1 `
    -v sqldata1_2:/var/opt/mssql/data2 `
    -v sqldata1_3:/var/opt/mssql/data3 `
    -v sqldata1_4:/var/opt/mssql/data4 `
    -v sqlbackups:/backups `
    -d mcr.microsoft.com/mssql/server:2022-RTM-CU2-ubuntu-20.04


docker run `
    --name "sql2" `
    --hostname "sql2" `
    --net agnetwork `
    -e "ACCEPT_EULA=Y" `
    -e "MSSQL_ENABLE_HADR=1" `
    -e "MSSQL_SA_PASSWORD=$PASSWORD" `
    -p 1434:1433 `
    -v sqldata2_0:/var/opt/mssql `
    -v sqldata2_1:/var/opt/mssql/data1 `
    -v sqldata2_2:/var/opt/mssql/data2 `
    -v sqldata2_3:/var/opt/mssql/data3 `
    -v sqldata2_4:/var/opt/mssql/data4 `
    -v sqlbackups:/backups `
    -d mcr.microsoft.com/mssql/server:2022-RTM-CU2-ubuntu-20.04


$SqlInstance1 = Connect-DbaInstance -SqlInstance "localhost,1433" -SqlCredential $SqlCredential
$SqlInstance2 = Connect-DbaInstance -SqlInstance "localhost,1434" -SqlCredential $SqlCredential


#clean up the permissions on sql2 since it will need to have 4 files too. 
docker exec -t -u 0 sql2 bash -c "chown mssql /var/opt/mssql/data{1..4}"


#Let's start off with sorting authentication, since we're using linux containers...I'm gonna opt for certificates. Also good to consider when using AD too. Why? 
#Create DMK and Certificates on each replica...
#This is based off the beard's blog - https://github.com/dataplat/dbatools-lab/blob/development/notebooks/NotDotNet/03AvailabilityGroups.ipynb
New-DbaDbMasterKey -SqlInstance $SqlInstance1 -Credential $SqlCredential -Confirm:$false
New-DbaDbMasterKey -SqlInstance $SqlInstance2 -Credential $SqlCredential -Confirm:$false


#Now create a new certificate on sql1, backup the certificate on sql1 and restore it to sql2
New-DbaDbCertificate -SqlInstance $SqlInstance1 -Name ag_cert -Subject ag_cert -StartDate (Get-Date) -ExpirationDate (Get-Date).AddYears(10) -Confirm:$false
Backup-DbaDbCertificate -SqlInstance $SqlInstance1 -Certificate ag_cert -Path '/backups/certs' -EncryptionPassword $SqlCredential.Password -Confirm:$false


$Certificate = (Get-DbaFile -SqlInstance $SqlInstance1 -Path '/backups/certs' -FileType cer).FileName
Restore-DbaDbCertificate -SqlInstance $SqlInstance2 -SqlCredential $SqlCredential -Path $Certificate -DecryptionPassword $SqlCredential.Password -Confirm:$false


#Create a test database in the AG...I always create a "stub" database first to test out the plumbing before bringing in the real data sets.
New-DbaDatabase -SqlInstance $SqlInstance1 -Name TestDB1 -RecoveryModel Full


#To put a database in an AG it's gotta be in real full recovery mode, so you need to take a full and a log backup.
Backup-DbaDatabase -SqlInstance $SqlInstance1 -Database TestDB1 -Type Full -BackupFileName NUL 
Backup-DbaDatabase -SqlInstance $SqlInstance1 -SqlCredential $SqlCredential -Database TestDB1 -Type Log  -BackupFileName NUL 


#Now, let's create the AG, lots 'o parameters. This creates a clusterless, manual failover AG using the certificate we just created to authenticate the database mirroring endpoints
New-DbaAvailabilityGroup `
    -Primary $SqlInstance1 `
    -Secondary $SqlInstance2 `
    -Name ag1 `
    -Database TestDB1 `
    -ClusterType None  `
    -FailoverMode Manual `
    -SeedingMode Automatic `
    -Certificate ag_cert `
    -Verbose -Confirm:$false


#Let's check the status of our AG
Get-DbaAvailabilityGroup -SqlInstance $SqlInstance1 -AvailabilityGroup ag1


#To put a database in an AG it's gotta be in real full recovery mode, so you need to take a full and a log backup.
Set-DbaDbRecoveryModel -SqlInstance $SqlInstance1 -Database TPCH -RecoveryModel Full -Confirm:$false
Backup-DbaDatabase -SqlInstance $SqlInstance1 -Database TPCH -Type FULL -BackupFileName NUL 
Backup-DbaDatabase -SqlInstance $SqlInstance1 -Database TPCH -Type Log  -BackupFileName NUL 


#Now let's add the main database we've been working with...TPCH, this will use automatic seeding so we don't have to land a backup anywhere
Add-DbaAgDatabase `
    -SqlInstance $SqlInstance1 `
    -Secondary $SqlInstance2 `
    -AvailabilityGroup ag1 `
    -Database TPCH `
    -SeedingMode Automatic `
    -Verbose  


Get-DbaAgDatabase -SqlInstance $SqlInstance1 | Format-Table
Get-DbaAgDatabase -SqlInstance $SqlInstance2 | Format-Table


#######################################################################################################################################
# Use Case 6 - Just the two of us - The Copy-* cmdlets
# Even though dbatools has a fantastic migration cmdlet... 
#  - I often select the exact objects I want to migrate and migrate just those
#  - Also often used to keep objects in sync for Availability Groups
#  - There's also Sync-DbaAvailabilityGroup
#######################################################################################################################################
Get-Command -Verb copy -Module dbatools

#Copy-DbaUser/Login
New-DbaLogin -SqlInstance $SqlInstance1 -Login login1 -SecurePassword $sqlpasswd
New-DbaLogin -SqlInstance $SqlInstance1 -Login login2 -SecurePassword $sqlpasswd
New-DbaLogin -SqlInstance $SqlInstance1 -Login login3 -SecurePassword $sqlpasswd
New-DbaLogin -SqlInstance $SqlInstance1 -Login login4 -SecurePassword $sqlpasswd


New-DbaDbUser -SqlInstance $SqlInstance1 -Database TPCH -Login login1
New-DbaDbUser -SqlInstance $SqlInstance1 -Database TPCH -Login login2
New-DbaDbUser -SqlInstance $SqlInstance1 -Database TPCH -Login login3
New-DbaDbUser -SqlInstance $SqlInstance1 -Database TPCH -Login login4


#Even though it's in an AG, its on you to copy instance objects like logins, linked servers, jobs and more.
Get-DbaLogin -SqlInstance 'localhost,1433' -SqlCredential $SqlCredential | Format-Table
Get-DbaLogin -SqlInstance 'localhost,1434' -SqlCredential $SqlCredential | Format-Table

#THIS HAS CAUSED SO MANY OUTAGES!!!!!!!!!

#This will also copy the password and permissions.
Copy-DbaLogin -Source $SqlInstance1 -Destination $SqlInstance2

Get-DbaLogin -SqlInstance 'localhost,1433' -SqlCredential $SqlCredential | Format-Table
Get-DbaLogin -SqlInstance 'localhost,1434' -SqlCredential $SqlCredential | Format-Table



#######################################################################################################################################
# Use Case 7 - What's the scenario? - Configuration cmdlets
#   - The only way to keep things sane is to deploy in code...
#   - so I always use dbatools to test/set/get any of the core sql instance configuration settings.
#   - Further, I wrap them in pester to esure the settings are set and then I can come back later and re-test for compliance.
#######################################################################################################################################
#Configure an Instance
$SqlInstances = @('localhost,1433','localhost,1434')
Set-DbaMaxMemory -SqlInstance $SqlInstances -SqlCredential $SqlCredential #This throws a warning since it's trying to find multiple instances but cannot on SQL Server on Linux
Install-DbaWhoIsActive -SqlInstance $SqlInstances -SqlCredential $SqlCredential -Database master


#Run a pester test
$container = New-PesterContainer -Path './tests/PostInstallationChecks.Tests.ps1' -Data @{ SqlInstance = $SqlInstances; SqlCredential = $SqlCredential; }
Invoke-Pester -Container $container -Output Detailed





#Clean up
docker exec sql1 bash -c "rm /backups/certs/*"
docker exec sql1 bash -c "rm /backups/sqlbackups/migrate/*"
docker rm sql1 -f
docker rm sql2 -f

docker volume rm sqldata1_0
docker volume rm sqldata1_1
docker volume rm sqldata1_2
docker volume rm sqldata1_3
docker volume rm sqldata1_4

docker volume rm sqldata2_0
docker volume rm sqldata2_1
docker volume rm sqldata2_2
docker volume rm sqldata2_3
docker volume rm sqldata2_4

docker network rm agnetwork

