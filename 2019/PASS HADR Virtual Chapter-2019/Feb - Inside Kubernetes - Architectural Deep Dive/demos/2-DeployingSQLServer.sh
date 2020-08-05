#Create /data/mssql-data on each node in the cluster
ssh aen@c1-node1
sudo mkdir -p /data/mssql-data
exit

ssh aen@c1-master1

#Install sqlcmd on the client if needed.
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update 
sudo apt-get install mssql-tools unixodbc-dev
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
PASSWORD='S0methingS@Str0ng!'

#create a secret to store the SA password to be passed into SQL Server's setup
kubectl create secret generic mssql --from-literal=SA_PASSWORD=$PASSWORD

#Create our disks, a peristent volume and a persistent volume claim
more pv.yaml
more pvc.yaml
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml

#Even more details about our PV and PVC, we want to ensure that our PVC is contained in the PV
kubectl get pv pv-sql-data
kubectl get pvc pvc-sql-data

#With our storage configured, let's push our deployment which is a pod. 
#The container may need to download. Can take some time.
#https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker?view=sql-server-2017
more sql.yaml
kubectl apply -f sql.yaml
kubectl get pods --watch
kubectl get pods
kubectl describe pods | more

#Deploy a persistent network Service to send traffic to our SqlServer pod
more service-sql.yaml
kubectl apply -f service-sql.yaml

#Get the service IP
kubectl get service
SERVERIP=10.105.14.154
PORT=1433

#Check out the servername in the container
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT @@SERVERNAME" -P $PASSWORD 

#ADD CREATING A DATABASE
sqlcmd -S $SERVERIP,$PORT -U sa -Q "CREATE DATABASE TestDB1" -P $PASSWORD 

#Look at the actual path of the database file
ssh aen@c1-node1 'ls -al /data/mssql-data/'
ssh aen@c1-node1 'ls -al /data/mssql-data/data'

#List the physical path of the files in the SQL Server pod
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD 

#Crash SQL Server
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SHUTDOWN WITH NOWAIT" -P $PASSWORD 

kubectl get pods

#Pull the logs from the pod to look at the restart time.
kubectl logs mssql-deployment[tab]

kubectl delete pod mssql-deployment[tab]

#Let's check the status of the service now that we crashed SQL Server
kubectl get pods
kubectl get services 

#Our databases are still there!!!
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT name from sys.databases" -P $PASSWORD 

kubectl delete service mssql-deployment
kubectl delete deployment mssql-deployment
kubectl delete pvc pvc-sql-data
kubectl delete pv pv-sql-data
kubectl delete sc local-storage
kubectl delete secret mssql

kubectl get all

ssh aen@c1-node1
sudo rm -rf /data/mssql-data




kubectl exec -it mssql-deployment-5479887959-6nqbt -- /bin/bash
