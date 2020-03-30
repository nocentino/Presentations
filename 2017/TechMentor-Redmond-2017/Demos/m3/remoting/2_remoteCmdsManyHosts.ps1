<#
	Author: 		Anthony E. Nocentino
	Email:			aen@centinosystems.com
	Description:		A very small script that can be used to get processes from several computers. In the demo I show getting processes from 
				three computers, two linux and one windows.
				$names holds a list computers coming from the file myhosts.
				Currently PS remoting on linux does not support the -ComputerName parameter...which has substantial benefits such as parallel connections
				and error handing.
#>

$names = Get-Content "myhosts"

foreach ($name in $names)
{
	Write-Debug "Getting top 10 processes from $($name)" 
	Invoke-Command -HostName $name -UserName demo -ScriptBlock { Get-Process | Sort-Object -Descending CPU | Select-Object -First 10 }  
}

