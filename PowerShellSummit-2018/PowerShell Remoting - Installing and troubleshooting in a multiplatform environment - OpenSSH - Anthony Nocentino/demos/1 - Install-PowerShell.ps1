#Install PowerShell Core.
#Run VS Code (with PowerShell Extension) or PowerShell Core as administrator

#Download OpenSSH from GitHub
#$url = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.6.0.0p1-Beta/OpenSSH-Win32.zip"
$ZipFile = "\\vmware-host\Shared Folders\aen\Dropbox\Talks\PowerShell Summit\OpenSSH-Win32.zip"
#Invoke-WebRequest -Uri $url -OutFile $ZipFile

#Unzip the file
$InstallationDestination = "C:\Program Files\OpenSSH"
Expand-Archive -LiteralPath $ZipFile -DestinationPath $InstallationDestination

#Run Install-sshd.ps1
& "$InstallationDestination\OpenSSH-Win32\install-sshd.ps1"

#Adjust your firewall rules, using PowerShell 5.1...shhh, don't tell anyone.
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

#Verify if service is running
Get-Service -Name "*ssh*"

#Start SSHD
Set-Service sshd -StartupType Automatic
Set-Service ssh-agent -StartupType Automatic
Start-Service -Name sshd
netstat -bano | Select-String -Pattern ":22"

