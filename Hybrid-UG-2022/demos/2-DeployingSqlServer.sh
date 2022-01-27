#Log into control plane node to drive demos
ssh aen@c1-cp1
cd ~/content/Talks/Kubernetes/demos
source <(kubectl completion bash)


#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
PASSWORD='S0methingS@Str0ng!'
kubectl create secret generic mssql --from-literal=SA_PASSWORD=$PASSWORD


#Create our storage and also begin our SQL Server deployment
kubectl apply -f storage.yaml
kubectl apply -f deployment-sql-2019.yaml 


#Did the pod create?
kubectl get pods


#Let's access our Service, which points to our SQL Server Pod
kubectl get service
SERVICEIP=$(kubectl get service mssql-service -o jsonpath='{ .spec.clusterIP }')
PORT=1433
echo $SERVICEIP,$PORT


#Check out the servername and the version in the container, 2019 CU13
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD -W 


#ADD CREATING A DATABASE
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "CREATE DATABASE TestDB1" -P $PASSWORD 


#Look at the actual path of the database files on our storage system...
#Kubernetes makes sure that these are mapped on the Node and Exposed inside the pod
ssh -t aen@c1-storage 'sudo ls -la /srv/exports/volumes/sql-instance-1/' 
ssh -t aen@c1-storage 'sudo ls -la /srv/exports/volumes/sql-instance-1/data' 


#List the physical path of the files in the SQL Server pod
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD -W



#Crash SQL Server, do this too many times too quickly it will start to back off...initially 15s
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SHUTDOWN WITH NOWAIT" -P $PASSWORD 


#Check out the events
kubectl describe pods mssql-deployment
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD 


#Delete the pod
kubectl delete pod mssql-deployment-[tab][tab]


#This time we get a new Pod, check out the name and the events
kubectl get pods


#We still have our databases, because of the PV/PVC being presented as /var/opt/mssql/
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT Physical_Name FROM sys.master_files" -P $PASSWORD -W


#Change out the version of SQL Server from CU13->CU14, could use YAML or kubectl edit too
kubectl set image deployment mssql-deployment \
    mssql=mcr.microsoft.com/mssql/server:2019-CU14-ubuntu-18.04


#Check the status of our rollout
kubectl rollout status deployment mssql-deployment


#1. Key thing here is to shut down the current pod before deploying the new pod. the default is to add one, then remove the old.
#2. Check out the pod template hashed changed, old scaled to 0, new scaled to 1
kubectl describe deployment mssql-deployment
kubectl get replicaset
kubectl get pods

#Check out the servername and the new version in the Pod...still upgrading or ready to go?
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD -W


#Check the logs of our pod, SQL Error log writes to stdout, which is captured by the pod
kubectl logs mssql-deployment-[tab][tab]



####BONUS MATERIALS - Rolling back SQL Server to the previous CU.

#Check out the deployment history to see what's been done to this deployment
kubectl rollout history deployment mssql-deployment
kubectl rollout history deployment mssql-deployment --revision=1


#Let's roll back, b/c we can do that between CUs
kubectl rollout undo deployment mssql-deployment --to-revision=1


#ReplicaSet goes from 1->0 on CU13 and from 0->1 on CU14. Resued the old replicaset, see pod template hash
kubectl describe deployment mssql-deployment


#Check out the servername in the container, scripts are downgrading the databases.
sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@SERVERNAME,@@VERSION" -P $PASSWORD 


#We can watch our progress here
kubectl logs mssql-deployment-[tab][tab] --follow


kubectl delete service mssql-service
kubectl delete deployment mssql-deployment
kubectl delete pvc pvc-nfs-instance
kubectl delete pv pv-nfs-instance
kubectl delete secret mssql


#Delete and recreate volume data on c1-storage for the next presentation
ssh -t aen@c1-storage 'sudo rm -rf /srv/exports/volumes/sql-instance-1/'
ssh -t aen@c1-storage 'sudo mkdir -p /srv/exports/volumes/sql-instance-1'
ssh -t aen@c1-storage 'sudo chown mssql:mssql /srv/exports/volumes/sql-instance-1'
ssh -t aen@c1-storage 'sudo ls -laR /srv/exports/volumes/sql-instance-1'


