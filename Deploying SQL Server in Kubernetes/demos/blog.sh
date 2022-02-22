#Set up an environment variable and SA password stored as a cluster secret
PASSWORD='S0methingS@Str0ng!'
kubectl create secret generic mssql --from-literal=SA_PASSWORD=$PASSWORD


#Create SQL Server and Deployment
kubectl apply -f storage.yaml
kubectl apply -f deployment-sql.yaml

#Get the initial pod name
kubectl get pods 



kubectl get service
SERVICEIP=$(kubectl get service mssql-service -o jsonpath='{ .spec.clusterIP }')
PORT=1433
echo $SERVICEIP,$PORT


sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@SERVERNAME AS SERVERNAME, SERVERPROPERTY('ServerName') AS SERVERPROPERTY, name FROM sys.servers" -P $PASSWORD -W

#Create SQL Server and Deployment
kubectl apply -f deployment-sql.yaml
kubectl apply -f storage.yaml


kubectl get service
SERVICEIP=$(kubectl get service mssql-service -o jsonpath='{ .spec.clusterIP }')
PORT=1433
echo $SERVICEIP,$PORT

sqlcmd -S $SERVICEIP,$PORT -U sa -Q "SELECT @@SERVERNAME AS SERVERNAME, SERVERPROPERTY('ServerName') AS SERVERPROPERTY, name FROM sys.servers" -P $PASSWORD -W


#Delete and recreate volume data on c1-storage for the next presentation
ssh -t aen@c1-storage 'sudo rm -rf /export/volumes/sql1/{backup,system,data,log}'
ssh -t aen@c1-storage 'sudo mkdir -p /export/volumes/sql1/{backup,system,data,log}'
ssh -t aen@c1-storage 'sudo chown -R 10001:10001 /export/volumes/sql1/'
ssh -t aen@c1-storage 'sudo chown -R 10001:10001 /export/volumes/sql1/{backup,system,data,log}'
ssh -t aen@c1-storage 'sudo ls -laR /export/volumes/sql1/'

