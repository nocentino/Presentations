#troubleshooting SSH
Stop-Service -Name sshd
notepad C:\\ProgramData\\ssh\sshd_config #Set LogLevel DEBUG3
Start-Serivce -Name sshd
ssh aen@windows-s1
notepad C:\\ProgramData\\ssh\\logs
