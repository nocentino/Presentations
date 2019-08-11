#On windows-s1
<#
    notepad C:\ProgramData\ssh\sshd_config
    Add the following line, pointing to you pwsh.exe...forward slash alert!!!
    On Windows
    Subsystem    powershell c:/program files/powershell/6.1.0-preview.1/pwsh.exe -sshs -NoLogo -NoProfile
    On Linux
    vi /etc/ssh/sshd_config
    Subsystem    powershell /bin/pwsh -sshs -NoLogo -NoProfile
#>
Restart-Service sshd

#On centos-w1
pwsh
#authenticate to our Windows box with our key
Enter-PSSession windows-s1 
Enter-PSSession windows-s1 -SSHTransport
Enter-PSSession -HostName windows-s1 
whoami

#Let's use PowerShell remoting via AD auth. Notice the difference the profile path? 
Enter-PSSession -HostName windows-s1 -UserName aen@lab.centinosystems.com
whoami
exit

#Try to connect to centos-s. Won't work because we don't have the subsystem configured yet
Enter-PSSession -HostName centos-s1 -UserName aen@lab.centinosystems.com
