#Setup, centos-s1 in domain. Group sshusers exists aen@lab.centinosystems.com is in the group
#Server configuration overview
#On CENTOS-S1
ssh aen@centos-s1

#verify user is in sshusers group
id aen@lab.centinosystems.com 

vi /etc/ssh/sshd_config
Add - AllowGroups sshusers@lab.centinosystems.com

systemctl restart sshd

#Open new window, don't close current and launch a new session
ssh aen@centos-s1
ssh aen@lab.centinosystems.com@centos-s1

#Client configuration overview
more /etc/ssh/ssh_config
more ~/.ssh/config

vi ~/.ssh/config

Host linux
    User aen
    Hostname centos-s1
    IdentityFile ~/.ssh/id_rsa.pub

Host windows
    User aen
    Hostname windows-s1
    IdentityFile ~/.ssh/windows.pub

ssh windows