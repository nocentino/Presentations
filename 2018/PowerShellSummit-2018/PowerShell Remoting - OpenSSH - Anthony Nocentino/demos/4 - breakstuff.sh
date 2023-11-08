#Host key mismatch
ssh aen@windows-s1 
del C:\ProgramData\ssh\ssh_host_*
dir C:\ProgramData\ssh\ssh_host_*

#Key permissions mismatch
icacls C:\users\aen\.ssh\authorized_keys /inheritance:e

move C:\ProgramData\ssh\sshd_config C:\ProgramData\ssh\sshd_config.remoting
C:\ProgramData\ssh\sshd_config.orig C:\ProgramData\ssh\sshd_config
powershell -Command { Restart-Service -Name sshd -Verbose }


#Remove the remoting subsystem

No Subsystem Configured