Param(
    [Parameter(
        Mandatory = $true, 
        Position = 0, 
        HelpMessage = 'Specify a servername', 
        ValueFromPipeline = $true
        )]
    [pscredential] $SqlCredential,
    [ValidateNotNullOrEmpty()]
    [string[]] $SqlInstance
)
foreach ($pSqlInstance in $SqlInstance) {
    Describe "Test for Instance Level Settings" {
        Context "$pSqlInstance`: Memory Configuration" {
            $Memory = (Test-DbaMaxMemory -SqlInstance $pSqlInstance -SqlCredential $SqlCredential)
            $RecommendedValue = ($Memory.RecommendedValue)
            $MaxValue = ($Memory.MaxValue)
            It "Checking the Max Memory setting for the instance should be $RecommendedValue" {
                $MaxValue | Should -Be $RecommendedValue
            }  
        }

        Context "$pSqlInstance`: MaxDOP Configuration" {
            $dop = (Test-DbaMaxDop -SqlInstance $pSqlInstance -SqlCredential $SqlCredential)
            $DopInstance = ($dop | Where-Object { $_.Database -eq 'n/a' })
            $DopDatabase = ($dop | Where-Object { $_.Database -ne 'n/a' })
            
            It "$pSqlInstance`: Checking if Instance MAXDOP exceeds the number of cores in a NUMA node" {
                $DopInstance.CurrentInstanceMaxDop | Should -BeLessOrEqual $($DopInstance.RecommendedMaxDop) -Because "we do not want to span a NUMA Node. Resource: Instance. Suggested value: $($DopInstance.RecommendedMaxDop)"
            }
            @($DopDatabase.Database).foreach{
                It "$pSqlInstance`: Checking if database: $($DopDatabase.Database) MAXDOP exceeds the number of cores in a NUMA node" {
                    $DopDatabase.DatabaseMaxDop | Should -BeLessOrEqual $($DopDatabase.RecommendedMaxDop) -Because "We do not want to span a NUMA Node. Resource: $($DopDatabase.Database). Suggested value: $($DopDatabase.RecommendedMaxDop)"
                }
            }    
        }
    }
}