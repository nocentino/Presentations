#Log into master node to drive demos
ssh aen@c1-master1


cd ~/content/Kubernetes/demos


#Set up an environment variable and SA password stored as a cluster secret
PASSWORD='S0methingS@Str0ng!'
kubectl create secret generic mssql --from-literal=SA_PASSWORD=$PASSWORD


#Deploying SQL Server in a Deployment with Persistent Storage
#Disk Topology
kubectl apply -f sql.pv.yaml
kubectl apply -f sql.pvc.yaml


#Deploy 'production ready' SQL Instance with an advanced disk topology
kubectl apply -f deployment-advanced-disk.yaml


#Status is now Running
kubectl get pods


#Get access to the service
kubectl get service
SERVICEIP=$(kubectl get service mssql-deployment -o jsonpath='{ .spec.clusterIP }')
PORT=31433
echo $SERVICEIP


#Check out the servername and the version in the container, 2019 CU1
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@VERSION" -P $PASSWORD 


#ADD CREATING A DATABASE
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "CREATE DATABASE TestDB1" -P $PASSWORD 


#List the physical path of the files in the SQL Server pod
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD -W


#Look at the actual path of the database files on our storage system...
#Kubernetes makes sure that these are mapped on the Node and Exposed inside the pod
ssh -t aen@c1-storage 'sudo ls -la /export/volumes/sql2/system' 
ssh -t aen@c1-storage 'sudo ls -la /export/volumes/sql2/system/data'
ssh -t aen@c1-storage 'sudo ls -la /export/volumes/sql2/{data,log}'


#Setting Resource Limits
#Let's update the existing deployment with 1 CPUs and 8GB RAM.
kubectl apply -f deployment-advanced-disk-resource-limits.yaml 


#Status is now Pending, but restarted due to the config change. But this Pod was NOT able to get scheduled.
#We requested 8GB of memory but our Nodes have only 2GB
kubectl get pods


#Events will show Insufficient memory
kubectl describe pods


#Set memory Requests to a value lower than the resources available in a Node, in this case 1GB
kubectl apply -f deployment-advanced-disk-resource-limits-correct.yaml


#Status is now running, the pod was able to get scheduled
kubectl get pods


#Did SQL Server start up?
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@VERSION" -P $PASSWORD 


#Backing up SQL Server in Kubernetes
#Attach a backup disk in the Pod Configuration
kubectl apply -f deployment-advanced-disk-resource-limits-correct-withbackup.yaml


#Ensure the Pod is Running and the disk is attached
kubectl get pod 




#We can use dbatools...
pwsh
$Username = 'sa'
$Password =  ConvertTo-SecureString -String "S0methingS@Str0ng!" -AsPlainText -Force
$SaCred = New-Object System.Management.Automation.PSCredential $Username,$Password

kubectl get service
$SERVICEIP = kubectl get service mssql-deployment -o jsonpath='{ .spec.clusterIP }'
$PORT=31433


#Test our connectivity to the instance...to specify a port, use a quoted string
Connect-DbaInstance -SqlInstance "$SERVICEIP,$PORT" -SqlCredential $SaCred


#Let's take a backup...
Backup-DbaDatabase -SqlInstance "$SERVICEIP,$PORT" -SqlCredential $SaCred -path '/backup'


#Leave pwsh back into bash...
exit


#...but that file is really stored on the NFS Server
ssh -t aen@c1-storage 'sudo ls -al /export/volumes/sql2/backup'



#Delete our resources to clean— up after our demos
kubectl delete secret mssql
kubectl delete -f deployment-advanced-disk-resource-limits-correct-withbackup.yaml
kubectl delete -f sql.pvc.yaml
kubectl delete -f sql.pv.yaml

#Double check everything is gone...
kubectl get all
kubectl get pvc
kubectl get pv


#Delete and recreate volume data on c1-storage for the next presentation
ssh -t aen@c1-storage 'sudo rm -rf /export/volumes/sql2/{backup,system,data,log}'
ssh -t aen@c1-storage 'sudo mkdir -p /export/volumes/sql2/{backup,system,data,log}'
ssh -t aen@c1-storage 'sudo chown mssql:mssql -R /export/volumes/sql2/'
ssh -t aen@c1-storage 'sudo ls -laR /export/volumes/sql2/'
