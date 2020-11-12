#From: https://techibee.com/powershell/powershell-verify-or-test-ad-account-credentials/2956
function Test-AdCredential(   
    [Parameter(Mandatory=$True)]   [PSCredential] $Credential
){    
    $NetworkCredential = New-Object System.Net.NetworkCredential $Credential.UserName, $Credential.Password
    $Domain = $NetworkCredential.UserName.Split('\')[0]
    $Account = $NetworkCredential.UserName.Split('\')[1]
    $Password = $NetworkCredential.Password

    if ( [string]::IsNullOrWhiteSpace($Domain) ){
        Write-Error "Domain is null or empty" -ErrorAction Stop
        return $false
    }
    if ( [string]::IsNullOrWhiteSpace($Account) ){
        Write-Error "Username is null or empty" -ErrorAction Stop
        return $false
    }
    if ( [string]::IsNullOrWhiteSpace($Password) ){
        Write-Error "Password is null or empty"
        return $false
    }

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $ct, $Domain 

    try{
        $loginresult = $pc.ValidateCredentials( $Account, $Password )
    }
    catch{
        Write-Error $_ -ErrorAction Stop
        return $false
    }

    if ($loginresult -eq $true) {
        Write-Verbose "Login succeeded for $Account"
        return $true
    }
    else {
        Write-Verbose "Login failed for $Account!"
        return $false
    }
}
