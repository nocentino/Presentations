#On CENTOS-W1
rm -rf ~/.ssh/
ssh-agent -k

#Authenticating users with keys
#On management workstation, generate an ssh key pair
/usr/bin/ssh-keygen

#Copy the key to the Linux server centos-s1
/usr/bin/ssh-copy-id aen@centos-s1

#Test key based authentication to centos-s1
ssh aen@centos-s1
whoami
exit

#Active Directory Authentication
#log into windows-s1 with an AD account, nope didn't have to configure anything
ssh aen@lab.centinosystems.com@windows-s1
whoami
exit

#Time to setup AD authentication on our linux host, log into the target with a local account
ssh aen@centos-s1
whoami

#install the required components on the target on centos-s1
sudo yum install realmd krb5-workstation oddjob oddjob-mkhomedir sssd samba-common-tools -y

#Join the domain, it's really this easy!
sudo realm join lab.centinosystems.com -U 'aen@LAB.CENTINOSYSTEMS.COM' -v

#Look at all the hard work sssd did for you, set up your kerberos realms
more /etc/krb5.conf

#groups and users now come from files and sss
more /etc/nsswitch.conf

#authentication is from files and sss
more /etc/sssd/sssd.conf

#Test it out by finding our AD User
id aen@lab.centinosystems.com
exit

#Test logging in to linux via AD authentication
ssh aen@lab.centinosystems.com@centos-s1
exit

#Combining key and AD authentication, what do you think is going to happen?
#Who is the authenticator here?
/usr/bin/ssh-copy-id aen@lab.centinosystems.com@centos-s1
ssh -v aen@lab.centinosystems.com@centos-s1
whoami












#Copy the key to the Windows serve windows-s1, because of 'StrictModes yes' we need to manage permissions
ssh aen@windows-s1
cd ~
ssh aen@windows-s1 'mkdir .ssh'
scp ~/.ssh/id_rsa.pub aen@windows-s1:".ssh\my_authorized_keys"

ssh aen@windows-s1 'type .ssh\my_authorized_keys >> .ssh\authorized_keys && del .ssh\my_authorized_keys'
ssh aen@windows-s1 'icacls C:\users\aen\.ssh\authorized_keys /inheritance:r'
ssh aen@windows-s1 'icacls C:\users\aen\.ssh\authorized_keys /grant "SYSTEM":(R)'
ssh aen@windows-s1 'icacls C:\users\aen\.ssh\authorized_keys /grant "aen":(R)'

#Test key based authentication to windows-s1.
ssh aen@windows-s1 









