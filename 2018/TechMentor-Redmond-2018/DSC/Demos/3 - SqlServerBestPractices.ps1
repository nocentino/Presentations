#Common configuration across all targets
$ActiveDirectoryDomain = "LAB"
$InstallerServiceCredential = Import-Clixml .\cred_aen.xml
$SqlAdministrators = "$ActiveDirectoryDomain\Database Engineers"
$NETPath = "\\dc1\SHARE\INSTALLS\Windows2016\sources\sxs"
$SourcePath = "\\dc1\SHARE\Installs\en_sql_server_2017_enterprise_core_x64_dvd_11293037"

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName                    = "*" 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
            NETPath                     = $NETPath
            SQLSysAdminAccounts         = "$ActiveDirectoryDomain\Domain Admins", $SqlAdministrators
            SourcePath                  = $SourcePath
            InstallerServiceCredential  = $InstallerServiceCredential
            SQLAdministrators           = $SqlAdministrators
        }
    )
}

#Use an array of hash table entries to store PER server configuration.
$SQLServers = @(
    @{ServerName = "DSCSQL1"; InstanceName = "SQLA"; SVCUserName = "LAB\SA-DSCSQL1";  SVCPassword = "ncuu41hr1c;n1ccdwA" }
    @{ServerName = "DSCSQL2"; InstanceName = "SQLB"; SVCUserName = "LAB\SA-DSCSQL2";  SVCPassword = "123LPOPwjndfwqf^&*" }
)

#Test connection to each server
ForEach ($SQLServer in $SQLServers) {
    if (!(Test-Connection -ComputerName $SQLServer.ServerName -Count 1 -Quiet)){
        exit
    }
    else {
        Write-Output "Found host: $($SQLServer.ServerName)"
    }
}

#Per server configuration per target.
#Need to access the hash table by key name.
ForEach ($SQLServer in $SQLServers) {
    $username = $SQLServer["SVCUserName"]
    $password = $SQLServer["SVCPassword"] | ConvertTo-SecureString -AsPlainText -Force
    $SVCCredential = New-Object System.Management.Automation.PSCredential( $username, $password )

    $ConfigurationData.AllNodes += @{
        NodeName      = $SQLServer["ServerName"]
        InstanceName  = $SQLServer["InstanceName"]
        SVCCredential = $SVCCredential
    }
}

Configuration SqlServerBestPractices
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPendingReboot
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName SecurityPolicyDsc
    Import-DscResource -ModuleName xComputerManagement

    Node $AllNodes.NodeName
    {
        #region LCM Settings
        LocalConfigurationManager {
            RebootNodeIfNeeded = $True
        }
        #endregion

        #region Windows Settings
        xPendingReboot PendingReboot {
            Name = $Node.NodeName
        }

        WindowsFeature NET-Framework-Core {
            Name                 = "NET-Framework-Core"
            Ensure               = "Present"
            IncludeAllSubFeature = $true
            Source               = $Node.NETPath
        }

        #Identity will overwrite what's in the setting so we need the existing default setting PLUS ours
        UserRightsAssignment PerformVolumeMaintenanceTasks {
            Policy                  = "Perform_volume_maintenance_tasks"
            Identity                = "BUILTIN\Administrators", $Node.SVCCredential.Username
        }

        UserRightsAssignment LockPagesInMemory {
            Policy                  = "Lock_pages_in_memory"
            Identity                = "BUILTIN\Administrators", $Node.SVCCredential.Username
        }

        xPowerPlan PowerPlan {
            IsSingleInstance        = "Yes"
            Name                    = "High Performance"
        }

        #This directory is isolated out to so the dynamically created directory resources all wait on this, then the install what's on this
        #figure out a what to do this more dynamically, specifically, the depends on generation.
        File CreateDataDirectory {
            Ensure                  = "Present"
            Type                    = "Directory"
            DestinationPath         = "D:\DATA"
            DependsOn               = "[File]CSQLAgentLogs", "[File]LLOGS", "[File]SBACKUPS", "[File]SSYSTEM", "[File]TTEMPDB"
        }

        #You can use straight PowerShell in here to make repeative tasks easier.
        $directories = @("C:\SQLAgentLogs", "L:\LOGS", "S:\BACKUPS", "S:\SYSTEM", "T:\TEMPDB")
        ForEach ($directory in $directories ) {
            File $directory.Replace(":\", "") {
                Ensure              = "Present"
                Type                = "Directory"
                DestinationPath     = $directory
            }
        } #end for each

        #Add a AD group to a local group, must be an authenticated domain account to query AD, so we have a Credential
        Group SQLManagementLocalAdmin {
            GroupName               = "Administrators"
            Ensure                  = "Present"
            MembersToInclude        = $Node.SqlAdministrators
            Credential              = $Node.InstallerServiceCredential
        }
        #endregion

        #region Install SQL Server
        #Keeping this the same as our SqlSetup call from the previous demo. We're not changing the install here. But it's still part of our desired
        SqlSetup InstallSQL {
            DependsOn           = '[WindowsFeature]NET-Framework-Core'
            SourcePath          = $Node.SourcePath
            SQLSysAdminAccounts = $Node.SQLSysAdminAccounts
            InstanceName        = $Node.InstanceName
            Features            = "SQLENGINE"
        }
        #endregion

        #region SQL Server Instance Settings
        $SqlConfigurations = @('remote admin connections','optimize for ad hoc workloads','Agent XPs')
        foreach ($SqlConfiguration in $SqlConfigurations) {
            SqlServerConfiguration $SqlConfiguration{
                ServerName = $Node.NodeName
                InstanceName = $Node.InstanceName
                OptionName = $SqlConfiguration
                OptionValue = 1
                RestartService = $true
            }
        }

        SqlDatabaseDefaultLocation DataFiles {
            DependsOn = "[File]CreateDataDirectory"
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            Type = "Data"
            Path = "D:\DATA\"
        }

        SqlDatabaseDefaultLocation LogFiles {
            DependsOn = "[File]CreateDataDirectory"
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            Type = "Log"
            Path = "L:\LOGS\"
        }

        SqlServerConfiguration CostThresholdForParallelism{
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            OptionName = 'cost threshold for parallelism'
            OptionValue = 50
        }

        SqlServerMemory SqlMemory{
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            DynamicAlloc = $True
        }

        SqlServerMaxDop MaxDOP{
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            DynamicAlloc = $True
        }

        SqlServiceAccount DatabaseEngine{
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            ServiceType = 'DatabaseEngine'
            ServiceAccount = $Node.SVCCredential
            RestartService = $false
        }

        SqlServiceAccount SqlServerAgent{
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            ServiceType = 'SQLServerAgent'
            ServiceAccount = $Node.SVCCredential
            RestartService = $false
            DependsOn = '[SqlServiceAccount]DatabaseEngine'
        }

        #Conditional branches can't happen inside a resource :(
        if ($Node.InstanceName -eq "MSSQLSERVER"){
            Service SqlSererStarted{
                Name      = "MSSQLSERVER"
                DependsOn = '[SqlServiceAccount]DatabaseEngine'
                State     = "Running"        
            }
            Service SqlAgentStarted{
                Name      = "SQLServerAgent"
                DependsOn = '[SqlServiceAccount]SqlServerAgent'
                State     = "Running"        
            }
        }
        else{
            Service SqlSererStarted{
                Name      = "MSSQL`$$($Node.InstanceName)"
                DependsOn = '[SqlServiceAccount]DatabaseEngine'
                State     = "Running"        
            }
            Service SqlAgentStarted{
                Name      = "SQLAGENT`$$($Node.InstanceName)"
                DependsOn = '[SqlServiceAccount]SqlServerAgent'
                State     = "Running"        
            }            
        }

        #endregion

        #region SQL Server Security
        SqlServerLogin DisableSaAccount{
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            Name = 'sa'
            LoginType = 'SqlLogin'
            Disabled = $true
        }

        SqlServerLogin AddDatabaseEngineers {
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            Ensure = 'Present'
            Name = $Node.SQLAdministrators
            LoginType = 'WindowsGroup'
        }

        SqlServerLogin AddServiceAccount {
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            Ensure = 'Present'
            Name = $Node.SVCCredential.Username
            LoginType = 'WindowsUser'
        }

        SqlServerRole SysAdmins_DatabaseEngineers{
            DependsOn = '[SqlServerLogin]AddDatabaseEngineers'
            ServerName = $Node.NodeName
            InstanceName = $Node.InstanceName
            ServerRoleName = 'sysadmin'
            MembersToInclude = $Node.SQLAdministrators
            Ensure = 'Present'
        }
        #endregion
    } #end node
}#end configuration

#Modules must exist on the targets, so let's copy our modules to the targets
ForEach ($SQLServer in $SQLServers) {
    Write-Output "Copying modules to $($SQLServer.ServerName)"
    $Destination = "\\" + $($SQLServer.ServerName) + "\c$\Program Files\WindowsPowerShell\Modules"
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\SqlServerDsc' -Destination $Destination -Recurse -Force
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\xPendingReboot' -Destination $Destination -Recurse -Force
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\SecurityPolicyDsc' -Destination $Destination -Recurse -Force
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\xComputerManagement' -Destination $Destination -Recurse -Force    
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\dbatools' -Destination $Destination -Recurse -Force
}

### STEP 1 - Generate the MOFs for your servers ###
SqlServerBestPractices -OutputPath "C:\DeploySQL\" -ConfigurationData $ConfigurationData

### STEP 2 - Push Configuration ###
Set-DscLocalConfigurationManager -Path "C:\DeploySQL\" -ComputerName $SQLServers.ServerName 

Start-DscConfiguration -Path "C:\DeploySQL\" -ComputerName $SQLServers.ServerName -Force -Verbose -Wait

### STEP 3 - You're so woefully impatient and you need to check the LCM status right now! Look at LCMState. 
### Is it idle, PendingConfiguration or Busy. Idle means you're likely finished. ###
Invoke-Command -ComputerName $SQLServers.ServerName { Get-DscLocalConfigurationManager } | Select-Object PSComputerName, LCMState

### STEP 4 - If it's finished, verify DSC status on the nodes to confirm the node is in compliance with the configuration. Any errors in the DSC configuration will pop out here. ###
Invoke-Command -ComputerName $SQLServers.ServerName { Test-DscConfiguration -Detailed } | Select-Object *

Invoke-Command -ComputerName $SQLServers.ServerName { Get-Service -Name *SQL* } | Sort-Object -Property PSComputerName, Name
