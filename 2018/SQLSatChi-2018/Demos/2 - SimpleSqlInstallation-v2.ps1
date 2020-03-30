<#
    1. Install WMF 5.1 on the authoring station and the target.
    2. Install the DSC Resources on authoring station and copy them to the targets. 
        a. To install the modules on the authoring station use
           Install-Module SqlServerDsc Install-Module xPendingReboot
    3. Ensure your .NET Path (NETPath) and SQL Binaries (SourcePath) paths are shared and 
        security is set to allow the computer account of the target access to the share.
#>
#Common configuration across all targets
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName                    = "*" 
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
            NETPath                     = "\\dc1\SHARE\INSTALLS\Windows2016\sources\sxs"
            SQLSysAdminAccounts         = "LAB\Domain Admins", "LAB\Database Engineers"
            SourcePath                  = "\\dc1\SHARE\Installs\en_sql_server_2017_enterprise_core_x64_dvd_11293037"
        }
    )
}

#Use an array of hash table entries to store per server configuration.
$SQLServers = @(
    @{ServerName = "DSCSQL3"; InstanceName = "SQLA"; }
    @{ServerName = "DSCSQL4"; InstanceName = "SQLB"; }
)

#Per server configuration per target.
#Need to access the hash table by key name.
ForEach ($SQLServer in $SQLServers) {
    $ConfigurationData.AllNodes += @{
        NodeName     = $SQLServer["ServerName"]
        InstanceName = $SQLServer["InstanceName"]
    }
}

$ConfigurationData
$ConfigurationData.AllNodes

Configuration SimpleSqlInstallationV2
{
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module xPendingReboot
    Import-DscResource -Module SqlServerDsc

    Node $AllNodes.NodeName
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $True
        }

        xPendingReboot PendingReboot {
            Name = $Node.NodeName
        }

        WindowsFeature NET-Framework-Core {
            Name                 = "NET-Framework-Core"
            Ensure               = "Present"
            IncludeAllSubFeature = $true
            Source               = $Node.NETPath
        }

        SqlSetup InstallSQL {
            DependsOn           = '[WindowsFeature]NET-Framework-Core'
            SourcePath          = $Node.SourcePath
            SQLSysAdminAccounts = $Node.SQLSysAdminAccounts
            InstanceName        = $Node.InstanceName
            Features            = "SQLENGINE"
        }
    }
}

#Modules must exist on the targets, so let's copy our modules to the targets
ForEach ($SQLServer in $SQLServers) {
    Write-Output "Copying modules to $($SQLServer.ServerName)"
    $Destination = "\\" + $($SQLServer.ServerName) + "\c$\Program Files\WindowsPowerShell\Modules"
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\SqlServerDsc' -Destination $Destination -Recurse -Force
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\xPendingReboot' -Destination $Destination -Recurse -Force
    Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\dbatools' -Destination $Destination -Recurse -Force
}

### STEP 1 - Generate the MOFs for your servers ###
SimpleSqlInstallationV2 -OutputPath "C:\DeploySQL\" -ConfigurationData $ConfigurationData
Invoke-Item "C:\DeploySQL\"

### STEP 2 - Push LCM Configuration ###
Set-DscLocalConfigurationManager -Path "C:\DeploySQL\" -ComputerName $SQLServers.ServerName ["ServerName"]

### STEP 2 - Push  Configuration since we're not using -Wait, this will post a PowerShell Job###
Start-DscConfiguration -Path "C:\DeploySQL\" -ComputerName $SQLServers.ServerName -Force 

### Check on the status of the job ###
Get-Job 

### STEP 3 - Look for ScenarioEngine, Setup, sqlservr, sqlagent or msiexec to confirm installation activity ###
Invoke-Command -ComputerName $SQLServers.ServerName { Get-Process }   

### STEP 4 - You're so woefully impatient and you need to check the LCM status right now! Look at LCMState. 
### Is it idle, PendingConfiguration or Busy. Idle means you're likely finished. ###
Invoke-Command -ComputerName $SQLServers.ServerName { Get-DscLocalConfigurationManager } | Select-Object PSComputerName, LCMState

### STEP 5 - If it's finished, verify DSC status on the nodes to confirm the node is in compliance with the configuration. Any errors in the DSC configuration will pop out here. ###
Invoke-Command -ComputerName $SQLServers.ServerName { Test-DscConfiguration -Detailed } | Select-Object * 

Invoke-Command -ComputerName $SQLServers.ServerName { Get-Service -Name *SQL* }