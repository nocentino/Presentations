#Getting started with OpenSSH
#Setup 
#   ssh aen@centos-s1 'rm -rf ~/.ssh/'
#   ssh aen@windows-s1 'rmdir /S /Q %userprofile%\.ssh\'
#   rm -rf ~/.ssh/
#   test domain join on centos-s1 - id aen@centinosystems.com. User member of lab\sshusers.
#
#On CENTOS-S1
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