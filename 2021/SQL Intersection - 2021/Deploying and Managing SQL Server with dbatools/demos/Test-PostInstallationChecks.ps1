[CmdletBinding()]
Param(
    [Parameter(
        Mandatory = $true, 
        Position = 0, 
        HelpMessage = 'Specify a servername', 
        ValueFromPipeline = $true
    )]
    [ValidateNotNullOrEmpty()]
    [string[]] $SqlInstance
)

#$pSqlInstance will be the whole SERVERNAME\INSTANCENAME, $ServerName will be just the SERVERNAME and $InstanceName is just the INSTANCENAME
foreach ($pSqlInstance in $SqlInstance) {
    $ServerName = $null
    $InstanceName = $null
    
    #If there's a named instance in the form SERVERNAME\INSTANCENAME split it on the \. if there is no INSTANCENAME then set it to MSSQLSERVER
    $ServerName, $InstanceName = $pSqlInstance.Split('\')

    if ( [string]::IsNullOrEmpty($InstanceName) ) {
        $InstanceName = 'MSSQLSERVER'
    }

    Describe "SQL Agent Configuration" {
        Context "$pSqlInstance`: Testing to see if the SQL Server Agent Service is running" {
            It "Testing to see if the SQL Server Agent Service is running" {
                $result = (Get-DbaService -ComputerName "$pSqlInstance" -Type Agent).State
                $result | Should -Be 'Running' -Because "We want to ensure SQL Server Service is online."
            }
        } 
        Context "$pSqlInstance`: SqlAgent Operator" {
            @(Get-DbaAgentOperator -SqlInstance "$pSqlInstance" -Operator Alerts).ForEach{
                It 'Testing for an Operator named Alerts' {
                    $PSItem.Name | Should -Be "Alerts" -Because "There should be an operator named Alerts"
                }
                It 'Testing if Alert Operator has a valid email address' {
                    $PSItem.EmailAddress | Should -Match '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$' -Because "There should be valid email address on the operator"
                }
            }  
        }
        Context "$pSqlInstance`: Agent History Retention" {
            @(Get-DbaAgentServer -SqlInstance "$pSqlInstance").ForEach{
                It "$pSqlInstance`: Should have a job history length set to 1000 per job" {
                    $psitem.MaximumJobHistoryRows | Should -BeGreaterOrEqual 1000 -Because "We want to keep a large body of job history around per job."
                }
                It "$pSqlInstance`: Should have a job history length set to 10000 total" {
                    $psitem.MaximumHistoryRows | Should -BeGreaterOrEqual 10000 -Because "We want to keep a large body of job history around total."
                }
            }  
        }
    }

    Describe "Database Mail Configuration"{
        Context "$pSqlInstance`: Test to see if Database Mail is properly configured" {
            $result = Get-DbaDbMailAccount -SqlInstance "$SqlInstance\$InstanceName"
            It "Testing for Database Mail Alerts Account" {
                $result.Name  | Should -Be "Alerts" -Because "There should be Mail Account named Alerts"
            }
            $result = Get-DbaDbMailProfile -SqlInstance "$SqlInstance\$InstanceName"
            It "Testing for Database Mail Alerts Profile" {
                $result.Name  | Should -Be "Alerts" -Because "There should be Mail Profile named Alerts"
            }
        }
    }

    Describe "Ola Hallengren SP and Job Configuration" {
        Context "$pSqlInstance`: Test to see if Ola Hallengrens Maintenance Solution and if sp_whoisactive is installed" {
            #Do not use this, brutally slow.
            #$storedprocedures = (Get-DbaDbStoredProcedure -SqlInstance "$pSqlInstance" -Database 'master' -ExcludeSystemSp).Name
            $storedprocedures = (Get-DbaModule -SqlInstance "$pSqlInstance" -Database 'master' -ExcludeSystemObjects | Where-Object { $_.Type -eq 'SQL_STORED_PROCEDURE' } ).Name

            It 'Testing for DatabaseBackup' {
                $storedprocedures | Should -Contain "DatabaseBackup" -Because "We want this script on all systems"
            }
            It 'Testing for DatabaseIntegrityCheck' {
                $storedprocedures | Should -Contain "DatabaseIntegrityCheck" -Because "We want this script on all systems"
            }
            It 'Testing for IndexOptimize' {
                $storedprocedures | Should -Contain "IndexOptimize" -Because "We want this script on all systems"
            }
            It 'Testing for CommandExecute' {
                $storedprocedures | Should -Contain "CommandExecute" -Because "We want this script on all systems"
            }
            It 'Testing for sp_WhoIsActive' {
                $storedprocedures | Should -Contain "sp_WhoIsActive" -Because "We want this script on all systems"
            }
        }

        Context "$pSqlInstance`: Test to see if maintenance jobs are on the local instance" {
            $jobs = Get-DbaAgentJob -SqlInstance "$pSqlInstance" | Where-Object { $_.Enabled -eq $true }
            It 'Should have a CommandLog Cleanup job' {
                ($jobs.Name | Where-Object { $_ -like "*CommandLog Cleanup" }) | Should -BeLike "*CommandLog Cleanup" 
            }
            It 'Should have a Integrity Check job for the SYSTEM_DATABASES' {
                ($jobs.Name | Where-Object { $_ -like "*DatabaseIntegrityCheck - SYSTEM_DATABASES" }) | Should -BeLike "*DatabaseIntegrityCheck - SYSTEM_DATABASES"
            }
            It 'Should have a Integrity Check job for the USER_DATABASES' {
                ($jobs.Name | Where-Object { $_ -like "*DatabaseIntegrityCheck - USER_DATABASES" }) | Should -BeLike "*DatabaseIntegrityCheck - USER_DATABASES"
            }
            It 'Should have a Index Maintenance job for the USER_DATABASES' {
                ($jobs.Name | Where-Object { $_ -like "*IndexOptimize - USER_DATABASES" }) | Should -BeLike "*IndexOptimize - USER_DATABASES"
            }
        }

        Context "$pSqlInstance`: Test to see if maintenance jobs have run recently" {
            $InstallDate = Get-DbaInstanceInstallDate "$pSqlInstance" | Select-Object SqlInstallDate -ExpandProperty SqlInstallDate

            if ( $InstallDate.Date -lt (Get-date).AddDays(-7)  ) {
                $jobs = Get-DbaAgentJob -SqlInstance "$pSqlInstance" | Where-Object { $_.Enabled -eq $true }

                It 'Should have successfully run a CommandLog Cleanup job in the last week' {
                    ($jobs | Where-Object { $_.Name -like "*CommandLog Cleanup" -and $_.LastRunOutcome -eq 'Succeeded' }).LastRunDate | Should -BeGreaterOrEqual (Get-Date).AddDays(-7)
                }
                It 'Should have successfully run an Integrity Check job for the SYSTEM_DATABASES in the last week' {
                    ($jobs | Where-Object { $_.Name -like "*DatabaseIntegrityCheck - SYSTEM_DATABASES" -and $_.LastRunOutcome -eq 'Succeeded' }).LastRunDate | Should -BeGreaterOrEqual (Get-Date).AddDays(-7)
                }
                It 'Should have successfully run an Integrity Check job for the USER_DATABASES in the last week' {
                    ($jobs | Where-Object { $_.Name -like "*DatabaseIntegrityCheck - USER_DATABASES" -and $_.LastRunOutcome -eq 'Succeeded' }).LastRunDate | Should -BeGreaterOrEqual (Get-Date).AddDays(-7)
                }
                It 'Should have successfully run an Index Maintenance job for the USER_DATABASES successfully in the last week' {
                    ($jobs | Where-Object { $_.Name -like "*IndexOptimize - USER_DATABASES" -and $_.LastRunOutcome -eq 'Succeeded' }).LastRunDate | Should -BeGreaterOrEqual (Get-Date).AddDays(-7)
                }
            }
        }
  
    }

    Describe "Security Configuration" {
        Context "$ServerName`: Test and verify the SPN configuration." {
            @(Test-DbaSpn -ComputerName $ServerName).ForEach{
                $ThisSet = ($PSItem).IsSet
                It "Testing the SPN settings of the instance $($PSItem.RequiredSPN)" {
                    $ThisSet | Should -Be $true -Because "We really would like the SPN configuration to be valid"
                }
            }
        }        
        Context "$pSqlInstance`: Sysadmin fixed server role members" {
            $GroupMembers = Get-DbaServerRoleMember -SqlInstance "$pSqlInstance" -ServerRole sysadmin 

            It "$pSqlInstance`: Testing to see if $DbEngineers in a member of the sysadmin server role" {
                $GroupMembers.Name | Where-Object { $_ -eq $DbEngineers } | Should -Contain $DbEngineers
            }
        }
        Context "$pSqlInstance`: sa SQL login should be disabled" {
            $logins = Get-DbaLogin -SqlInstance "$pSqlInstance" | Where-Object { $_.Name -eq 'sa' }
            It "$pSqlInstance`: Test to see if sa is disabled" {
                $logins.IsDisabled | Should -Be $true
            }
        }
    }

    Describe "Instance Startup Trace Flags" {
        Context "$pSqlInstance`: Test to see if trace flags are set in the startup configuration if < 2017 1117/1118/3226 else if 2017+ just 3226" {
            $ThisSqlInstance = Connect-DbaInstance -SqlInstance "$pSqlInstance" 
            $serverversion = $ThisSqlInstance.Version
            $traceflags = (Get-DbaStartupParameter -SqlInstance "$pSqlInstance").TraceFlags.Split(',')

            if ( $serverversion.major -lt 13 ) {
                It 'Instance is less than SQL 2016, TF 1117' {
                    $traceflags | Should -Contain '1117' 
                }
                It 'Instance is less than SQL 2016, TF 1118' {
                    $traceflags | Should -Contain '1118' 
                }
            } #end if lt 13      
            It 'All Versions should TF 3226 enabled' {
                $traceflags | Should -Contain '3226' 
            }
            It 'Find any non-standard trace flags' {
                #pulling the TFs again in the event the previous tests added one
                $traceflags = (Get-DbaStartupParameter -SqlInstance "$pSqlInstance").TraceFlags.Split(',')
                $traceflags | Should -BeIn @('1117', '1118', '3226') -Because "There are non-standard trace flags enabled"
            }
        }
    }

    Describe "Test for Instance Level Settings" {
        Context "$pSqlInstance`: Memory Configuration" {
            $Memory = (Test-DbaMaxMemory -SqlInstance "$pSqlInstance")
            $RecommendedValue = ($Memory.RecommendedValue)
            $MaxValue = ($Memory.MaxValue)
            It "Checking the Max Memory setting for the instance should be $RecommendedValue" {
                $MaxValue | Should -Be $RecommendedValue
            }  
        }
        Context "$pSqlInstance`: MaxDOP Configuration" {
            $dop = Test-DbaMaxDop -SqlInstance "$pSqlInstance"
            $DopInstance = ($dop | Where-Object { $_.Database -eq 'n/a' })
            $DopDatabase = ($dop | Where-Object { $_.Database -ne 'n/a' })

            It "$pSqlInstance`: Checking if Instance MAXDOP exceeds the number of cores in a NUMA node" {
                $DopInstance.CurrentInstanceMaxDop | Should -BeLessOrEqual $NumberOfPhysicalCoresPerCPU -Because "we do not want to span a NUMA Node. Resource: Instance. Suggested value: $($PSItem.RecommendedMaxDop)"
            }
            @($DopDatabase).foreach{
                It "$pSqlInstance`: Checking if database: $($PSItem.Database) MAXDOP exceeds the number of cores in a NUMA node" {
                    $PSItem.DatabaseMaxDop | Should -BeLessOrEqual $NumberOfPhysicalCoresPerCPU -Because "We do not want to span a NUMA Node. Resource: $($PSItem.Database). Suggested value: $($PSItem.RecommendedMaxDop)"
                }
            }    
        }

        $configuration = Get-DbaSpConfigure -SqlInstance "$pSqlInstance"
        Context "$pSqlInstance`: sp configure options" {
            It "Remote Admin Connections - DAC - Configured Value" {
                $configuration | Where-Object { $_.Name -eq 'RemoteDacConnectionsEnabled' } | Select-Object ConfiguredValue -ExpandProperty ConfiguredValue | Should -Be 1
            }  
            It "Remote Admin Connections - DAC - Running Value" {
                $configuration | Where-Object { $_.Name -eq 'RemoteDacConnectionsEnabled' } | Select-Object RunningValue -ExpandProperty RunningValue | Should -Be 1
            }  
            It "Optimize for Adhoc workloads - Configured Value" {
                $configuration | Where-Object { $_.Name -eq 'OptimizeAdhocWorkloads' } | Select-Object ConfiguredValue -ExpandProperty ConfiguredValue | Should -Be 1
            }  
            It "Optimize for Adhoc workloads - Running Value" {
                $configuration | Where-Object { $_.Name -eq 'OptimizeAdhocWorkloads' } | Select-Object RunningValue -ExpandProperty RunningValue | Should -Be 1
            }  
            It "AgentXPs Enabled - Configured Value" {
                $configuration | Where-Object { $_.Name -eq 'AgentXPsEnabled' } | Select-Object ConfiguredValue -ExpandProperty ConfiguredValue | Should -Be 1
            }  
            It "AgentXPs Enabled - Running Value" {
                $configuration | Where-Object { $_.Name -eq 'AgentXPsEnabled' } | Select-Object RunningValue -ExpandProperty RunningValue | Should -Be 1
            }  
            It "Database Mail XPs Enabled - Configured Value" {
                $configuration | Where-Object { $_.Name -eq 'DatabaseMailEnabled' } | Select-Object ConfiguredValue -ExpandProperty ConfiguredValue | Should -Be 1
            }  
            It "Database Mail XPs Enabled - Running Value" {
                $configuration | Where-Object { $_.Name -eq 'DatabaseMailEnabled' } | Select-Object RunningValue -ExpandProperty RunningValue | Should -Be 1
            }
        }
    }

    Describe "TempDB Configuration" {
        $TempDBTest = Test-DbaTempdbConfig -SqlInstance "$pSqlInstance"
        Context "$pSqlInstance`: TempDB should have best practice or 8 TempDB Files" {
            It "should have 8 TempDB Files on $($TempDBTest[1].SqlInstance)" {
                $Reccomended = @()
                $Reccomended += $TempDBTest[1].Recommended
                $Reccomended += 8
                $TempDBTest[1].CurrentSetting | Should -BeIn $Reccomended -Because 'This is the recommended number of tempdb files for your server'
            }
        }
        Context "$pSqlInstance`: TempDB growth should be a fixed value" {
            It "TempDB growth should be a fixed value on all files" {
                $TempDBTest[2].CurrentSetting | Should -Be $TempDBTest[2].Recommended -Because 'Auto growth type should not be percent'
            }
        }
        Context "$pSqlInstance`: TempDB files should not be on the system drive" {
            It "TempDB files should not be on the system drive" {
                $TempDBTest[3].CurrentSetting | Should -Be $TempDBTest[3].Recommended -Because 'You do not want the tempdb files on the same drive as the operating system'
            }
        }
        Context "$pSqlInstance`: TempDB should have have no max growth" {
            It "on $($TempDBTest[4].SqlInstance)" {
                $TempDBTest[4].CurrentSetting | Should -Be $TempDBTest[4].Recommended -Because 'Tempdb files should be able to grow'
            }
        }
        Context "$pSqlInstance`: TempDB files should all be the same size" {
            It "TempDB data files should all be the same size" {
                @((Get-DbaDbFile -SqlInstance "$pSqlInstance" -Database tempdb).Where{ $_.Type -eq 0 }.Size.Megabyte | Select-Object -Unique).Count | Should -Be 1 -Because "We want all the tempdb data files to be the same size"
            }
        }
    }  

    Describe "Database Settings" {
        Context "$pSqlInstance`: Model Database Should Be Set to Simple" {
            @(Get-DbaDatabase -SqlInstance "$pSqlInstance" -Database 'model').ForEach{
                It 'Should have a recovery model set to SIMPLE' {
                    $PSItem.RecoveryModel | Should -Be 'SIMPLE' -Because "We want to use the SIMPLE recovery model for newly databases created."
                }
            } 
        }

        $files = Get-DbaDbFile -SqlInstance "$pSqlInstance" -Database 'model'
        Context "$pSqlInstance`: Model Database Should have data file growth set to 512MB or greater" {      
            $mdffile = $files | Where-Object { $_.ID -eq "1" }
            It 'Should have a data file growth size set to greater than 512MB' {
                $mdffile.growth | Should -BeGreaterOrEqual 524288 -Because 'we want the mdf to have a 512MB expansion by default'
            }  
        }
        Context "$pSqlInstance`: Model Database Should have log file growth set to 512MB or greater" {
            $logfile = $files | Where-Object { $_.TypeDescription -eq "LOG" }
            It 'Should have a log file growth size set to greater than 512MB' {
                $logfile.growth | Should -BeGreaterOrEqual 524288 -Because 'we want the log to have a 512MB expansion by default'
            }
        }
    }

    Describe "Windows Settings" {
        Context "$pSqlInstance`: High Performance PowerPlan" {        
            $dbapp = Test-DbaPowerPlan -ComputerName $pSqlInstance
            try {
                It "Checking if the Windows PowerPlan is set to High Performance" {
                    $dbapp.isBestPractice | Should -Be $true 
                }
            }
            catch {
                Write-Warning -Message "Setting PowerPlan to High Performance"
                if ( $remediate ) {
                    Set-DbaPowerPlan -ComputerName $pSqlInstance -PowerPlan "High Performance"
                }
            }      
        }
        #Perform Volume Maintenance
        #NOTIMPLEMENTED

        #Lock Pages in Memory
        #NOTIMPLEMENTED
    }
}
#END PROCESS