#1 - Creating a dotnet core web application
#Install Docker, .NET Core and Azure CLI

#Change to the parent 
cd ~/Dropbox/Talks/PracticalContainerScenarios/demos/


#Create a dotnet core application
dotnet new webApp -o myWebApp --no-https


#Creates a default application in our current working director
ls myWebApp


#Copy in our custom Index.csthml page
cp ./mypages/Index.cshtml ./myWebApp/Pages


#Test out our application locally, change into our app dir and run
cd ./myWebApp
dotnet run
open http://localhost:5000


#Stop our application
ctrl+c


#Compile our application for release
dotnet publish -c Release


#Change back into the parent directory
cd ..


#2 - Creating a container based application, but look at the Dockerfile first
docker build -t mywebappimage .


#Check out the local images on our system
docker image ls | grep mywebappimage


#Run our container based application for testing
docker run --name mywebapp --publish 8080:80 --detach  mywebappimage
open http://localhost:8080
docker ps


#3 - Build the container in a private Azure Container Registry
az account set --subscription 'Demonstration Account'


#Create Resource Group for our Lab
LOCATION='centralus'
RESOURCEGROUP='PracticalContainerScenarios'
az group create --name $RESOURCEGROUP  --location $LOCATION
az group show --name $RESOURCEGROUP 
open https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/PracticalContainerScenarios/overview


#Create an Azure Container Registry
ACRNAME='centinosystems'
az acr create \
    --resource-group $RESOURCEGROUP \
    --name $ACRNAME \
    --sku Standard \
    --location $LOCATION    


az acr show --name $ACRNAME

#Let's check it out in the portal
open https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/PracticalContainerScenarios/overview


#Build our container image inside ACR. Similar to how we did it with docker build, but this time in the cloud
#We could use docker push, but I don't want to upload a 200MB+ image
az acr build --image "mywebappimage:v1" --registry $ACRNAME .


#4 - Create a Kubernetes Cluster and deploy our application
#Grant AKS generated Service Principal to ACR
#Get the id of the service principal configured for AKS
#Create our AKS Cluster. This will create a three node cluster.
AKSCLUSTERNAME="AKS-PracticalContainerScenarios"
VERSION=$(az aks get-versions -l $LOCATION --query 'orchestrators[-1].orchestratorVersion' -o tsv)


echo $VERSION


#Create our k8s cluster, three nodes. 2 vCPUs, 7GB RAM each.
az aks create \
    --resource-group $RESOURCEGROUP \
    --name $AKSCLUSTERNAME \
    --location $LOCATION \
    --kubernetes-version $VERSION \
    --generate-ssh-keys


#Check out our cluster
az aks show --resource-group $RESOURCEGROUP --name $AKSCLUSTERNAME  | more 


#Give our Cluster permission to our Azure Container Registry.
CLIENT_ID=$(az aks show --resource-group $RESOURCEGROUP --name $AKSCLUSTERNAME --query "servicePrincipalProfile.clientId" --output tsv)


#Get the ACR registry resource id.
ACR_ID=$(az acr show --name $ACRNAME --resource-group $RESOURCEGROUP --query "id" --output tsv)


#Create role assignment, we're using the serivce principal methods. Username/Password is documented here: https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-aks
az role assignment create --assignee $CLIENT_ID --role acrpull --scope $ACR_ID


#Install kubectl
sudo az aks install-cli


#Get our cluster context which will have our cluster location, username and authentication method
az aks get-credentials --resource-group $RESOURCEGROUP --name $AKSCLUSTERNAME --overwrite-existing


#Check connectivity
kubectl cluster-info
kubectl get nodes


#Create a deployment from our container image and create a service to load balance
kubectl apply -f service.yaml
kubectl apply -f deployment.yaml


#Check out the deployment
kubectl get deployment
kubectl get replicaset
kubectl get pods 

#Get the IP Address of our load balancer...pending we'll come back to that
kubectl get service --watch
SERVICEIP=$(kubectl get service | grep webapp | awk '{ print $4 }')
curl -s  http://$SERVICEIP:80 | grep  "System"


#5 - Scaling our application
kubectl scale deployment.v1.apps/webapp-deployment --replicas=10


#Check out how many pods...so fast
kubectl get pods 


#Let's scale our application to 50 Pods
kubectl scale deployment.v1.apps/webapp-deployment --replicas=50


#Check out how many pods...so so fast!
kubectl get pods 


#Access our application again, workload should be load balanced.
curl -s  http://$SERVICEIP:80 | grep  "System"


#Time to clean up
rm -rf ~/Dropbox/Talks/PracticalContainerScenarios/demos/myWebApp
docker stop mywebapp
docker rm mywebapp
docker rmi mywebappimage
kubectl delete deployment webapp-deployment
#kubectl delete service webapp
kubectl config delete-cluster AKS-PracticalContainerScenarios
kubectl config use-context CSCluster
az acr repository delete --name $ACRNAME --image mywebappimage:v1 --yes
az acr repository delete --name $ACRNAME --repository mywebappimage --yes
#az aks delete --resource-group $RESOURCEGROUP --name $AKSCLUSTERNAME --yes