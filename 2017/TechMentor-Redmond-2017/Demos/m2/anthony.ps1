<#
    Setup
        1. Zoom in VS Code Window
        2. Increase font size on mac Terminal.app
#>

#Linux
ps -aux 

#macOS/BSD
ps -elf

#Linux
ps -aux | sort -nrk 4 | head

#macOS/BSD
ps -elf | sort -nrk 3 | head

#PowerShell - Windows, #macOS/BSD, Linux...one command...oh yeah (sounds like Macho Man) :)
Get-Process | Sort-Object -Descending CPU | Select-Object -First 10

#Can blend PowerShell cmdlets and native OS commands. Respects Unix style pipelines.
Get-Process | Sort-Object -Descending CPU | head

Get-Process -Name powershell

Get-Process | grep powershell 

#Yeilds a System.Diagnostics.Process Object
Get-Process -Name powershell | Get-Member

#Yeilds a System.String Object...Sad object based pipeline. :( But UNIXy FTW :)
Get-Process | grep powershell | Get-Member

#do command line remoting demos

#$var = New-PSSession -HostName win10 -UserName demo

#Enter-PsSession -Session

#Invoke-Command -Session $s -ScriptBlock {Get-Process}

#mac -> (Windows, Linux, Linux)
#Get-Content ./2_remoteCmdsManyHosts.ps1

#Get top 10 processes from each computer. mac -> (Windows, Linux, Linux) How’s that for heterogeneous?
#./2_remoteCmdsManyHosts.ps1

#Get top 10 processes from all computers
#./2_remoteCmdsManyHosts.ps1 | Sort-Object -Descending CPU