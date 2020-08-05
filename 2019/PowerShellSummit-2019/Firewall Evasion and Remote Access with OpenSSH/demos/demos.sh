#0 - We're going to log into a local Linux VM to run our demos from
LOCALVM='172.16.94.100'
ssh aen@$LOCALVM


#1 - Basic SSH login. Using SSH as a jump box
az login --subscription "Demonstration Account"
az account set --subscription "Demonstration Account"
az vm list-ip-addresses --name "server1" --output table | grep server1 | awk ' { print $2 } '
REMOTEVM=$(az vm list-ip-addresses --name "server1" --output table | grep server1 | awk ' { print $2 } ')

REMOTEVM='40.86.81.72'
ssh aen@$REMOTEVM
exit

#2 - Socks Proxy
#Proxying HTTP/HTTPS connections with SocksProxy
#Creates a Sock4/5 Proxy. Port must be greater than 1024 or root.
ssh -D 8080 aen@$REMOTEVM

#In a new terminal window.
LOCALVM='172.16.94.100'
ssh aen@$LOCALVM

#Listenting on localhost on 8080
sudo netstat -plant | grep '8080'

#Set the Proxy to localhost:8080 in Network Proxies
#open http://www.ipchicken.com in Chrome

curl http://ifconfig.me/ip

curl --proxy socks5h://localhost:8080 http://ifconfig.me/ip

#Let's start up a socks proxy on our local system listening on 8080
#Command line options  
#   -C Compression
#   -n attach stdin -> /dev/null
#   -f background our ssh process
#   -N Don't execute any command. 
#   -D Dynamic Port Fowarding
ssh -CnfND 8080 aen@$REMOTEVM

#Our proxy went straight to the background and we have our LOCAL terminal back.
sudo netstat -plant | grep 8080

#Now, we can access web pages via the Socks Proxy, check out our external IP now :P
curl --proxy socks5h://localhost:8080 http://ifconfig.me/ip

#We need to kill our ssh process.
killall ssh

#2 - Accessing Remote Resources on a single host blocked by a firewall
#Only port open on our Azure NSG is 22.
az network nsg rule list -g MC_k8s-BDC-Cloud_BDCluster_centralus --nsg-name aks-agentpool-15491064-nsg -o table

#Accessing Remote application services with SSH Tunneling (local port forwarding)
echo $REMOTEVM
curl http://$REMOTEVM #this won't work, due to our NSG's rules

#Let's check to see if our web server is listening. It is, and is listenting on all IP.
ssh aen@$REMOTEVM 
sudo netstat -plant  | grep httpd
exit

#We can't access the webserver over the Internet...oh...yes we can!
#Let's use local port fowarding to access our application, listenting on localhost
ssh -L 4321:localhost:80 aen@$REMOTEVM

#It opened an interactive session. So let's test this from a new console window, and ssh back into $LOCALVM
LOCALVM='172.16.94.100'
ssh aen@$LOCALVM

#Let's use local port fowarding to access our application, listenting on localhost
#which means only we can connect to this port
sudo netstat -plant | grep 4321
curl http://localhost:4321

#Let's close our tunnel. Jump back over to the interactive remotevm SSH session and exit
exit
exit
exit

#But what if we want our console back rather than logging directly into the remote host, add -f to fork a process.
ssh -f -L 4321:localhost:80 aen@$REMOTEVM

#The command we're forking is sleep 10, which basically holds the tunnel up for 10 seconds waiting for a connection
ssh -f -L 4321:localhost:80 aen@$REMOTEVM sleep 10

#We kept our local terminal so we didn't have to start a new session...let's try connecting again.
curl http://localhost:4321

#Check the process list for our ssh connection...then it goes away after 10 seconds.
sudo netstat -plant | grep 4321

#3 - Reverse port forwarding time. Here's the resource on our LOCALVM we want the remote VM to access.
curl http://localhost:80

#We can SSH into our remote VM, then access a service on the LOCALVM
#This time we want an interactive terminal...
ssh -R localhost:4321:localhost:80 aen@$REMOTEVM

#Bound only to localhost, GatewayPorts option would allow us to bind this to a network interface.
sudo netstat -plant | grep 4321
curl http://localhost:4321
exit

#4 - Building SSH connections for multi-hop remote access using ProxyHosts 
ssh aen@$REMOTEVM

PRIVATEVM='10.240.0.8'
ssh aen@$PRIVATEVM
exit
exit

#From LOCALVM we can open an SSH connention through REMOTEVM to PRIVATEVM
# $LOCALVM -> public key from $LOCALVM -> $REMOVEVM -> public key from $REMOVEVM -> $PRIVATEVM
PRIVATEVM='10.240.0.8'
ssh -J aen@$REMOTEVM:22 aen@$PRIVATEVM 
exit

more .ssh/config
pwsh
Enter-PSsession -Host jumpbox
exit
exit

#5 - Accessing remote networks with SSH-based VPN 

#First up...we need to enable the PermitTunnel option on the tunnel target
#You'll also need sudo rights on both hosts.
ssh aen@$REMOTEVM
sudo vi /etc/ssh/sshd_config
sudo systemctl restart sshd
exit

#Local Network (pointtopoint or ethernet)
sudo ip tuntap add dev tun0 mode tun
sudo ifconfig tun0 10.1.1.1 pointopoint 10.1.1.2 netmask 255.255.255.252
sudo ip route add 10.240.0.0/16 dev tun0
sudo /sbin/sysctl -w net.ipv4.ip_forward=1

#Remote Network  
ssh aen@$REMOTEVM  
sudo ip tuntap add dev tun0 mode tun
sudo ifconfig tun0 10.1.1.2 pointopoint 10.1.1.1 netmask 255.255.255.252
sudo ip route add 172.16.94.0/24 dev tun0
exit

#On LOCALVM
ssh -f -w 0:0 aen@$REMOTEVM true 

ping 10.240.0.7

#Using aliases to store these advanced configurations for easy use 
#Enter-PSsession to an alias in a config file

