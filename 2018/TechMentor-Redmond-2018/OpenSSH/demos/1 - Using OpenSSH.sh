#On CENTOS-W1
#Getting started with OpenSSH
#Setup 
#   test internet connectivity
#   on aen@centos-w1 'rm -rf ~/.ssh/'
#   on aen@windows-s1 'rmdir /S /Q %userprofile%\.ssh\'
#   on aen@centos-s1 rm -rf ~/.ssh/
#   Remove computer account for centos-s1
#   Restore snapshot of centos-s1
#   User aen member of lab\sshusers.

#Host keys
ssh aen@centos-s1
exit
more ~/.ssh/known_hosts
ssh -v aen@centos-s1

#Privilege separation
#look for the priveledged, the monitor and the unpriveledged process
sudo netstat -plant | grep ssh
ps --forest -x -p $(pidof sshd)
systemctl restart sshd

#The only pid changed is the priveledged process listening on 22
ps --forest -x -p $(pidof sshd)
exit

#Remote execution
ssh aen@centos-s1 hostname
ssh aen@centos-s1 'ps -aux' | grep root
