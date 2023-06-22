#Demo 1a - Creating a dotnet core web application
#Install Docker and Azure CLI

########################################################################################
#Demo 1 - Build and test our sample web applications
########################################################################################
#Step 1 - Time to build the container and tag it...the build is defined in the Dockerfile
docker build -f ./v1/Dockerfile -t webappimage:v1 .


#Step 2 - Run the container locally and test it out
docker run --name webapp --publish 8080:80 --detach webappimage:v1
http://localhost:8080  #<-- CMD + Click this link to launch the webpage.


#Delete the running webapp container
docker stop webapp
docker rm webapp
########################################################################################




########################################################################################
#Demo 2 - Create an ACR and build our application using ACR Tasks
########################################################################################
#Step 1 - Build the container in a private Azure Container Registry
az account set --subscription 'Demonstration Account'


#Create Resource Group for our Lab
LOCATION='centralus'
RESOURCEGROUP='PracticalContainerScenarios'
az group create --name $RESOURCEGROUP  --location $LOCATION
az group show --name $RESOURCEGROUP 


#Create an Azure Container Registry
#SKUs include standard and premium (speed, replication, advanced security features)
#https://docs.microsoft.com/en-us/azure/container-registry/container-registry-skus#sku-features-and-limits
ACRNAME='centinosystems' #<---- change this to your own globall unique name
az acr create \
    --resource-group $RESOURCEGROUP \
    --name $ACRNAME \
    --sku Standard \
    --location $LOCATION    


#Confirm all is well.
az acr show --name $ACRNAME


#Let's check it out in the portal
open https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/PracticalContainerScenarios/overview



#Build our container image inside ACR using Tasks. Similar to how we did it with docker build, but this time in the cloud.
#We could use docker push, but I don't want to upload a 200MB+ image
az acr build --image "webappimage:v1" --registry $ACRNAME --file ./v1/Dockerfile .
az acr build --image "webappimage:v2" --registry $ACRNAME --file ./v2/Dockerfile .
########################################################################################





########################################################################################
#Demo 3a - Create a Kubernetes Cluster and deploy our application
#Create our AKS Cluster. This will create a three node cluster.
########################################################################################
AKSCLUSTERNAME="AKS-PracticalContainerScenarios"

#Create our k8s cluster, three nodes. 2 vCPUs, 7GB RAM each. It's just VMs :P
az aks create \
    --resource-group $RESOURCEGROUP \
    --name $AKSCLUSTERNAME \
    --location $LOCATION \
    --attach-acr $ACRNAME \
    --generate-ssh-keys


#Check out our cluster
az aks show --resource-group $RESOURCEGROUP --name $AKSCLUSTERNAME  | more 
open https://portal.azure.com/#@nocentinohotmail.onmicrosoft.com/resource/subscriptions/fd0c5e48-eea6-4b37-a076-0e23e0df74cb/resourceGroups/PracticalContainerScenarios/providers/Microsoft.ContainerService/managedClusters/AKS-PracticalContainerScenarios/overview



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
SERVICEIP=$(kubectl get svc webapp -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
curl -s  http://$SERVICEIP:80 
########################################################################################


########################################################################################
#Demo 3b - Scaling our application
########################################################################################
kubectl scale deployment.v1.apps/webapp-deployment --replicas=10


#Check out how many pods...so fast
kubectl get pods 


#Let's scale our application to 50 Pods
kubectl scale deployment.v1.apps/webapp-deployment --replicas=50


#Check out how many pods...so so fast!
kubectl get pods 


#Access our application again, workload should be load balanced.
curl -s  http://$SERVICEIP:80 



#Now lets update our deployment with v2
kubectl apply -f deploymentv2.yaml


#Monitor the status of the rollout
kubectl rollout status deployment webapp-deployment


#Check the application, v2?
curl -s  http://$SERVICEIP:80
########################################################################################




########################################################################################
#Time to clean up
docker rmi webappimage:v1
kubectl config delete-cluster AKS-PracticalContainerScenarios
kubectl delete service webapp
kubectl delete deployment webapp-deployment
#This deletes the whole resource group, AKS Cluster and ACR.
#az aks delete --resource-group $RESOURCEGROUP --name $AKSCLUSTERNAME --yes
########################################################################################
