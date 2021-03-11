[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [String] $SqlInstance,
    [Parameter(Mandatory = $true)] [PSCredential] $EngineCredential,
    [Parameter(Mandatory = $true)] [PSCredential] $AgentCredential,
    [Parameter(Mandatory = $true)] [PSCredential] $InstallationCredential,
    [Parameter(Mandatory = $true)] [String] $InstallationSource,
    [Parameter(Mandatory = $true)] [String] $UpdateSource
)

Describe "Pre-Installation Checks" {
    Context "Server accessible via WinRM" {
        $result = Test-NetConnection -ComputerName $SqlInstance -InformationLevel Quiet -CommonTCPPort WINRM
        It "The target server should be accessible via WinRM" {
            $result | Should -BeTrue -Because "We need to do stuff with WinRM during the installation."        
        }
    }

    Context "Service Account Validation" {
        $CredentialTestResult = Test-AdCredential -Credential $EngineCredential
        It "Testing to see if the Engine Service account credential is valid $($EngineCredential.Username): " {
            $CredentialTestResult | Should -BeTrue -Because "SQL Server Engine requires a valid service account."
        }

        $CredentialTestResult = Test-AdCredential -Credential $AgentCredential
        It "Testing to see if the Agent Service account credential is valid $($AgentCredential.Username): " {
            $CredentialTestResult | Should -BeTrue -Because "SQL Server Agent requires a valid service account."
        }
    }

    Context "Installation Account Validation" {
        $CredentialTestResult = Test-AdCredential -Credential $InstallationCredential
        It "Testing to see if the installation account credential is valid $($InstallationCredential.Username): " {
            $CredentialTestResult | Should -BeTrue -Because "Need a valid installation account to run the installer."
        }
    }

    Context "Testing for the existence of required drives on target" {
        $drives = @('C', 'D', 'F', 'L', 'S', 'T') 
        $ServerDrives = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Get-PSDrive } 
        foreach ($drive in $drives) {
            $result = $ServerDrives.Name.Contains($drive)
            It "Should have a drive $($drive)" {
                $result | Should -BeTrue -Because "SQL Server requires a drive $($Drive)"
            }
        }
    }

    Context "Testing for existance of the installation share" {
        $result = Test-Path -Path $InstallationSource
        It "Testing to see if the installation share exists $InstallationSource" {
            $result | Should -BeTrue -Because "The installation share must exist"
        }
    }

    Context "Testing for existance of the Update Sources share" {
        $result = Test-Path -Path $UpdateSource
        It "Testing to see if the Update Sources share exists $UpdateSource" {
            $result | Should -BeTrue -Because "The Update Sources share must exist"
        }
    }
}
