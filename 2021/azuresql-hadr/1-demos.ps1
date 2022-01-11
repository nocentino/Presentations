#Based on - https://docs.microsoft.com/en-us/azure/azure-sql/database/scripts/setup-geodr-and-failover-elastic-pool-powershell and https://docs.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-configure?tabs=azure-powershell#code-try-2

Connect-AzAccount
$SubscriptionId = 'YOURSUB'
Set-AzContext -Subscription $SubscriptionId

#Resource group names
$PrimaryResourceGroupName = "azure-sql-hadr-primary"
$SecondaryResourceGroupName = "azure-sql-hadr-secondary"

#The regions for our two logical servers that will become members of the failover group
#https://docs.microsoft.com/en-us/azure/best-practices-availability-paired-regions
$PrimaryLocation = "eastus2"
$SecondaryLocation = "centralus"

#The logical server names. database.windows.net will be added automatically by Azure
$PrimaryServerName = "aen-sql-primary"
$SecondaryServerName = "aen-sql-secondary"
$FailoverGroupName = 'aen-sql-fog'

#Create the SQL Admin credentials for SQLDB
$SqlAdmin = "aen"
$Password = "ChangeYourAdminPassword1"
$SqlCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SqlAdmin, $(ConvertTo-SecureString -String $Password -AsPlainText -Force)

#Our test database name
$DatabaseName = "TestDB1"

#This is the IP address of my admin workstation, add any IP addresses or ranges for your application servers
$PrimaryStartIp = "YOURIP"
$PrimaryEndIp = "YOURIP"
$SecondaryStartIp = "YOURIP"
$SecondaryEndIp = "YOURIP"


#Create two new resource groups in the paired regions
$PrimaryResourceGroup   = New-AzResourceGroup -Name $PrimaryResourceGroupName   -Location $primaryLocation
$SecondaryResourceGroup = New-AzResourceGroup -Name $SecondaryResourceGroupName -Location $secondaryLocation


#Create the primary and secondary logical servers. These will be the members of the failover group
$primaryServer = New-AzSqlServer `
    -ResourceGroupName $PrimaryResourceGroupName `
    -ServerName $PrimaryServerName `
    -Location $PrimaryLocation `
    -SqlAdministratorCredentials $SqlCred

$secondaryServer = New-AzSqlServer `
    -ResourceGroupName $SecondaryResourceGroupName `
    -ServerName $SecondaryServerName `
    -Location $SecondaryLocation `
    -SqlAdministratorCredentials $SqlCred

    
#Create a database on the primary server
$database = New-AzSqlDatabase `
    -ResourceGroupName $PrimaryResourceGroupName `
    -ServerName $PrimaryServerName `
    -DatabaseName $DatabaseName `
    -Edition "GeneralPurpose" `
    -Vcore 2 `
    -ComputeGeneration "Gen5"


#Create the failover group (FOG)
$failovergroup = New-AzSqlDatabaseFailoverGroup `
    -ResourceGroupName $PrimaryResourceGroupName `
    -ServerName $PrimaryServerName `
    -PartnerResourceGroupName $SecondaryResourceGroupName `
    -PartnerServerName $SecondaryServerName  `
    -FailoverGroupName $FailoverGroupName `
    -FailoverPolicy Automatic `
    -GracePeriodWithDataLossHours 2 

$failovergroup


#Add our database to the FOG...this will block while the database is seeding.
Add-AzSqlDatabaseToFailoverGroup `
   -ResourceGroupName $PrimaryResourceGroupName `
   -ServerName $PrimaryServerName `
   -FailoverGroupName $FailoverGroupName `
   -Database $database  


#Create a firewall rule on both logical servers for our admin IP address. This will allow us to use the Invoke-Sqlcmd below to enable database level firewall rules
$primaryServerFirewallRule = New-AzSqlServerFirewallRule -ResourceGroupName $PrimaryResourceGroupName `
    -ServerName $primaryServerName `
    -FirewallRuleName "AllowedIPs" -StartIpAddress $primaryStartIp -EndIpAddress $primaryEndIp

$secondaryServerFirewallRule = New-AzSqlServerFirewallRule -ResourceGroupName $SecondaryResourceGroupName `
    -ServerName $secondaryServerName `
    -FirewallRuleName "AllowedIPs" -StartIpAddress $secondaryStartIp -EndIpAddress $secondaryEndIp

#Add a database level rule so we this configuration is replicated with the database in the FOG 
$Query = "EXECUTE sp_set_database_firewall_rule N'Example DB Setting 1', '$primaryStartIp', '$primaryEndIp';"
Invoke-Sqlcmd -ServerInstance "$primaryServerName.database.windows.net" -Credential $SqlCred -Query $Query


open https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/azure-sql-hadr-primary/overview
open https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/azure-sql-hadr-secondary/overview

#Check Role of current primary, should be...primary
#https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-geo-replication-link-status-azure-sql-database?view=azuresqldb-current
Get-AzSqlDatabaseFailoverGroup `
    -ResourceGroupName $PrimaryResourceGroupName `
    -FailoverGroupName $FailoverGroupName `
    -ServerName $PrimaryServerName


#Where does ATM send the connection?
dig aen-sql-fog.database.windows.net
dig aen-sql-fog.secondary.database.windows.net


#Failover to secondary
Switch-AzSqlDatabaseFailoverGroup `
   -ResourceGroupName $SecondaryResourceGroupName `
   -ServerName $SecondaryServerName `
   -FailoverGroupName $FailoverGroupName #-AllowDataLoss


#Where does ATM send the connection?
dig aen-sql-fog.database.windows.net
dig aen-sql-fog.secondary.database.windows.net

#Failback to primary
Switch-AzSqlDatabaseFailoverGroup `
   -ResourceGroupName $PrimaryResourceGroupName `
   -ServerName $PrimaryServerName `
   -FailoverGroupName $FailoverGroupName


#Clean up
Remove-AzResourceGroup -ResourceGroupName $PrimaryResourceGroupName   -Force
Remove-AzResourceGroup -ResourceGroupName $SecondaryResourceGroupName -Force
