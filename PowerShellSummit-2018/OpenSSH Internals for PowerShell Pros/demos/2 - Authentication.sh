#Setup, centos-s1 is in the domain and .ssh contains no user keys on centos-w1 and no keys on windows-s1 and no keys on centos-s1
#Windows host has ssh installed
#On CENTOS-S1
#Generating and distributing a key
/usr/bin/ssh-keygen

#copy the key to the remote server.
/usr/bin/ssh-copy-id aen@centos-s1

#Examine the hierarchy of authentication methods and find where the key is presented and accepted
ssh -v aen@centos-s1
cat .ssh/authorized_keys
exit


cd ./ssh
/usr/bin/ssh-keygen -f windows

#Copy the key to the Windows server windows-s1, because of 'StrictModes yes' we need to manage permissions
cd ~
ssh aen@windows-s1 'mkdir .ssh'
scp ~/.ssh/windows.pub aen@windows-s1:".ssh\my_authorized_keys"

ssh aen@windows-s1 'type .ssh\my_authorized_keys >> .ssh\authorized_keys && del .ssh\my_authorized_keys'
ssh aen@windows-s1 'icacls C:\users\aen\.ssh\authorized_keys /inheritance:r'
ssh aen@windows-s1 'icacls C:\users\aen\.ssh\authorized_keys /grant "SYSTEM":(R)'
ssh aen@windows-s1 'icacls C:\users\aen\.ssh\authorized_keys /grant "aen":(R)'

#Test key based authentication to windows-s1. Works, but checks id_rsa.pub first, then presents windows.pub
#look for the receive packet: type 51 which is an authentication failure. 52 is a success.
ssh aen@windows-s1 -vvv
ssh aen@windows-s1 -vvvv -i .ssh/windows.pub
