function ConfigurePageFile {
    Param(
        [Parameter(Mandatory = $True)] [String]   $SqlInstance
    )

    $PageFileLocation = 'F:\'
    $PageFileSize = 8192
    $PageFileSettings = Get-DbaPageFileSetting -ComputerName $SqlInstance
    if ( $PageFileSettings.FileName -notlike "$PageFileLocation*" -or $PageFileSettings.InitialSize -ne $PageFileSize  -or $PageFileSettings.MaximumSize -ne $PageFileSize  ){
        Write-Verbose "Setting page file size"
        Set-PageFile -ComputerName $SqlInstance -Location $PageFileLocation -InitialSize $PageFileSize -MaximumSize $PageFileSize        
    }
    else{
        Write-Output "Page file in desired state"
        $PageFileSettings
    }
}

function AddSqlManagementToLocalAdmin {
    Param(
        [Parameter(Mandatory = $True)] [String]   $SqlInstance
    )

    #Add "SQL Management Group to local administrators, this is for CommVault access to the server"
    $group = $null
    try {
        $group = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Get-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement }  -ErrorAction Ignore
    }
    catch {
    }

    try {
        if ($null -eq $group -or ($group.Name -notcontains $SQLManagement)) {
            Write-Verbose "Adding $($group.Name) to Local Adminstrators group on $servername"
            Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Add-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement }
        }
        else {
            Write-Verbose "$($group.Name) found on $SqlInstance in Local Adminstrators group"
        }
    }
    catch {
        Write-Error "Error adding SQL Management to local administrators: $_" 
    }

    try{
        New-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" -Login $SQLManagement -WarningAction SilentlyContinue
        Set-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" -Login $SQLManagement -AddRole sysadmin
    }
    catch{
        Write-Error "Error creating the login for $SQLManagement and adding it to the sysadmin server role: $_"
    }
}

function DisableSaLogin {
    Param(
        [Parameter(Mandatory = $True)]  [String] $SqlInstance,
        [String] $InstanceName = "MSSQLSERVER"
    )

    #Disable the sa login.
    Get-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" | Where-Object { $_.Name -eq 'sa' } | Set-DbaLogin -Disable
}

function ConfigureTraceFlags {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    $TraceFlags = @(3226)
    if ($SqlVersion -lt 2016 ) {
        $TraceFlags += 1117
        $TraceFlags += 1118
    }
    Write-Verbose "Enabling trace flags $TraceFlags"
    
    try {
        Enable-DbaTraceFlag -SqlInstance "$SqlInstance\$InstanceName" -TraceFlag $TraceFlags -WarningAction SilentlyContinue
        Set-DbaStartupParameter -SqlInstance "$SqlInstance\$InstanceName" -TraceFlag $TraceFlags -Confirm:$false
    }
    catch {
        Write-Error "Error enabling or setting the instance trace flags: $_"
    }
}

function SetSpConfigureOptions {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )
  
    if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name 'remote admin connections').ConfiguredValue -ne 1) {
        Set-DbaSpConfigure  -SqlInstance "$SqlInstance\$InstanceName"  -Name 'remote admin connections' -Value 1 
    }

    if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name 'optimize for ad hoc workloads').ConfiguredValue -ne 1) {
        Set-DbaSpConfigure   -SqlInstance "$SqlInstance\$InstanceName" -Name 'optimize for ad hoc workloads' -Value 1 
    }

    if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name 'Database Mail XPs').ConfiguredValue -ne 1) {
        Set-DbaSpConfigure   -SqlInstance "$SqlInstance\$InstanceName" -Name 'Database Mail XPs' -Value 1 
    }

    #Set CTFP to initial value of 50
    Set-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName"  -Name 'cost threshold for parallelism' -Value 50 -WarningAction SilentlyContinue
}

function ConfigureModelDatabase  {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    try {
        $modelrecoverymodel = Get-DbaDbRecoveryModel -SqlInstance "$SqlInstance\$InstanceName" -Database "MODEL"
        if ( $modelrecoverymodel.RecoveryModel -ne 'SIMPLE' ){
            Set-DbaDbRecoveryModel -SqlInstance "$SqlInstance\$InstanceName" -Database "MODEL" -RecoveryModel Simple -Confirm:$false -EnableException
        }
        $Query = "ALTER DATABASE [model] MODIFY FILE ( NAME = N`'modeldev`', FILEGROWTH = 512MB )"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $Query -EnableException
        $Query = "ALTER DATABASE [model] MODIFY FILE ( NAME = N`'modellog`', FILEGROWTH = 512MB )"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $Query -EnableException

        #Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Database "MASTER" -File "$folder\2-querystore.sql" -EnableException
        

        #Set-DbaDbQueryStoreOption -SqlInstance "$SqlInstance\$InstanceName" -Database 'MODEL' -State ReadWrite -CollectionInterval 30 -MaxSize 2048 -CaptureMode Auto -CleanupMode Auto 
    }
    catch {
        Write-Error "Error configuring the model database: $_"
    }
}

function ConfigureSqlMail{
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    try{
        $mailaccount = Get-DbaDbMailAccount -SqlInstance "$SqlInstance\$InstanceName"
        if ( $mailaccount.name -ne 'Alerts'){
            New-DbaDbMailAccount -SqlInstance "$SqlInstance\$InstanceName" -Name 'Alerts' -EmailAddress sqlalerts@centinosystems.com -MailServer smtp.lab.centinosystems.com -force
            New-DbaDbMailProfile -SqlInstance "$SqlInstance\$InstanceName" -Name 'Alerts' -MailAccountName 'Alerts' -MailAccountPriority 1
        }
    }
    catch{
        Write-Error "Error configuring SQL Database Mail Account: $_"
    }
}

function ConfigureSqlAgent {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    try {
        Set-DbaAgentServer -SqlInstance "$SqlInstance\$InstanceName" -MaximumHistoryRows 10000 -MaximumJobHistoryRows 1000 -AgentMailType DatabaseMail -DatabaseMailProfile 'Alerts' -SaveInSentFolder Enabled
    }
    catch {
        Write-Error "Error configuring the SQL Agent: $_"
    }
}

function Invoke-SqlConfigure {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Set-DbaPowerPlan -ComputerName $SqlInstance -PowerPlan 'High Performance'
    
    Set-DbaMaxDop -SqlInstance "$SqlInstance\$InstanceName"

    Set-DbaMaxMemory -SqlInstance "$SqlInstance\$InstanceName"

    Set-DbaTempdbConfig -SqlInstance "$SqlInstance\$InstanceName" -DataFileSize 1024 -DataFileGrowth 1024 -LogFileSize 1024 -LogFileGrowth 1024 -DataPath 'T:\TEMPDB' -LogPath 'L:\LOGS' 

    Install-DbaMaintenanceSolution -SqlInstance "$SqlInstance\$InstanceName" -LogToTable -InstallJobs

    Install-DbaWhoIsActive -SqlInstance "$SqlInstance\$InstanceName" -Database 'master'

    DisableSaLogin -SqlInstance $SqlInstance -InstanceName $InstanceName
    
    ConfigureTraceFlags -SqlInstance $SqlInstance -InstanceName $InstanceName
    
    SetSpConfigureOptions -SqlInstance $SqlInstance -InstanceName $InstanceName
  
    ConfigureModelDatabase -SqlInstance $SqlInstance -InstanceName $InstanceName

    ConfigureSqlMail -SqlInstance $SqlInstance -InstanceName $InstanceName

    ConfigureSqlAgent -SqlInstance $SqlInstance -InstanceName $InstanceName
}
