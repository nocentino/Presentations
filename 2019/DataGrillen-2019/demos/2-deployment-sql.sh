ssh aen@c1-node1 
sudo su - 
rm -rf /data/mssql-data
mkdir -p /data/mssql-data
exit
exit
ssh aen@c1-master1

cd ~/content/Talks/Data\ Grillen-2019/demos

#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
PASSWORD='S0methingS@Str0ng!'
kubectl create secret generic mssql --from-literal=SA_PASSWORD=$PASSWORD

kubectl apply -f storage.yaml
kubectl apply -f deployment-sql.yaml --record

kubectl get deployment
kubectl get replicasets
kubectl get pods

kubectl get service
SERVERIP=$(kubectl get service | grep mssql-deployment | awk {'print $3'})
PORT=31433

#Check out the servername and the version in the container, 2017 CU14
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD 

#ADD CREATING A DATABASE
sqlcmd -S $SERVERIP,$PORT -U sa -Q "CREATE DATABASE TestDB1" -P $PASSWORD 

#Look at the actual path of the database file
ssh aen@c1-node1 'ls -al /data/mssql-data/'
ssh aen@c1-node1 'ls -al /data/mssql-data/data'

#List the physical path of the files in the SQL Server pod
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD 

#That's because of the PV/PVC being presented into the container as /var/opt/mssql. 
#Look at the Volumes and Mounts in this output.
kubectl describe pods mssql-deployment

#Crash SQL Server, do this too many times too quickly it will start to back off...initially 15s
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SHUTDOWN WITH NOWAIT" -P $PASSWORD 

#Notice the restart count, that's due to the container's restart policy
kubectl get pods

#Check out the events
kubectl describe pods mssql-deployment

#Delete the pod
kubectl delete pod mssql-deployment-[tab][tab]

#This time we get a new Pod, check out the name and the events
kubectl get pods

#We still have our databases, because of the PV/PVC being presented as /var/opt/mssql/
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD 

#Change out the version of SQL Server from CU14->CU15, could use YAML or kubectl edit too
kubectl --record deployment set image mssql-deployment mssql=mcr.microsoft.com/mssql/server:2017-CU15-ubuntu

#Check the status of our rollout
kubectl rollout status deployment mssql-deployment

#1. Key thing here is to shut down the current pod before deploying the new pod. the default is to add one, then remove the old.
#2. Check out the pod template hashed changed, old scaled to 0, new scaled to 1
kubectl describe deployment mssql-deployment
kubectl get replicaset

#Check out the servername and the new version in the Pod...still upgrading or ready to go?
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD 

#Check the logs of our pod, SQL Error log writes to stdout, which is captured by the pod
kubectl logs mssql-deployment-[tab][tab]

#Check out the deployment history to see what's been done to this deployment
kubectl rollout history deployment mssql-deployment

#Let's roll back, b/c we can do that between CUs
kubectl rollout undo deployment mssql-deployment --to-revision=1 

#ReplicaSet goes from 1->0 on CU15 and from 0-1-> on CU14. Resued the old replicaset, see pod template hash
kubectl describe deployment mssql-deployment

#Check out the servername in the container, scripts are downgrading the databases.
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD 

#We still have our databases, because of the PV/PVC being presented as /var/opt/mssql/
sqlcmd -S $SERVERIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD 

#We can watch our progress here
kubectl logs mssql-deployment-[tab][tab]


kubectl delete service mssql-deployment
kubectl delete deployment mssql-deployment
kubectl delete pvc pvc-sql-data
kubectl delete pv pv-sql-data
kubectl delete sc local-storage
kubectl delete secret mssql


#ssh aen@c1-node1
#sudo su - 
#rm -rf /data/mssql-data
#mkdir -p /data/mssql-data
exit
exit