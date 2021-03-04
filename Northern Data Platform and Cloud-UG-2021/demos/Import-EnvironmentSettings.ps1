Param(
    [Parameter(Mandatory=$True)]
    [ValidateSet('DC1','LAB')]
    [String]   $DataCenter)
try{
    if ( $DataCenter -eq 'DC1' ){
        Write-Output "Loading $DataCenter Environment Settings"
        . .\Import-Dc1EnvironmentSettings.ps1 
    }        
    if ( $DataCenter -eq 'LAB' ){
        Write-Output "Loading $DataCenter Environment Settings"
        . .\Import-LabEnvironmentSettings.ps1
    }
}
catch{
    Write-Error $_
}
