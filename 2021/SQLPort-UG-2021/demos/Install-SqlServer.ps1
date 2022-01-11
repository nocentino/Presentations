#region Dot sourcing of functions
$Environment = 'LAB'
. .\Import-EnvironmentSettings.ps1 -DataCenter $Environment
. .\Test-AdCredential.ps1
. .\Invoke-SqlConfigure.ps1
#endregion

#region Installation Variables
$Version = 2019
$SqlInstance = 'DBASQL1'
$Features = @('ENGINE')


$ServiceAccount = "SA-$SqlInstance"
$svcPassword = ConvertTo-SecureString -String 'S0methingS@Str0ng!' -AsPlainText -Force
$EngineCredential = $AgentCredential = New-Object System.Management.Automation.PSCredential("$ActiveDirectoryDomain\$ServiceAccount", $svcPassword)
$InstallationCredential = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message 'Enter your credential information...'
#endregion

#region Pre-flight checks
$PreflightChecksResult = Invoke-Pester -Script @{ 
    Path = '.\Test-PreInstallationChecks.ps1' ; 
    Parameters = @{
        SqlInstance = $SqlInstance;  
        EngineCredential = $EngineCredential; 
        AgentCredential = $AgentCredential; 
        InstallationCredential = $InstallationCredential; 
        InstallationSource =  $InstallationSources[$Version];
        UpdateSource =  $UpdateSources[$Version];
    }
}  -PassThru 

if ( $PreflightChecksResult.FailedCount -gt 0 ){
    Write-Output "FAILED: Preflight checks failed please ensure pester test passes" -ErrorAction Stop
}
#endregion

#region Installation Execution
$Configuration = @{ UpdateSource = $UpdateSources[$Version]; BROWSERSVCSTARTUPTYPE = "Automatic"}

$InstallationParameters = @{
    SqlInstance = $SqlInstance 
    Path = $InstallationSources[$Version]
    Version = $Version
    Feature = $Features
    InstancePath = $InstancePath
    DataPath = $DataPath
    LogPath = $LogPath
    TempPath = $TempPath
    BackupPath = $BackupPath
    EngineCredential = $EngineCredential
    AgentCredential = $AgentCredential
    Credential = $InstallationCredential
    Configuration = $Configuration
    PerformVolumeMaintenanceTasks = $true
    Restart = $true
    Confirm = $false 
    Verbose = $true
}

$InstallationResult = Install-DbaInstance @InstallationParameters
$InstallationResult

if ( -Not ($InstallationResult.Successful )){
    Write-Output "FAILED: Installation on $SqlInstance failed. Examine the installation log at $($InstallationResult.LogFile) on the target server." -ErrorAction Stop
}
#endregion

# Configure SQL instance
Invoke-SqlConfigure -SqlInstance $SqlInstance 

# Test SQL install
Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ SqlInstance = $SqlInstance; } }


