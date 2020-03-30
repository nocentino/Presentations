<#
	Author: 		Anthony E. Nocentino
	Email:			aen@centinosystems.com
	Description:		One liner using PS Remoting to get the top to processes from a remote computer.
#>
Invoke-Command -HostName server2.domain.local -UserName demo -ScriptBlock { Get-Process | Sort-Object -Descending CPU | Select-Object -First 10 }  

