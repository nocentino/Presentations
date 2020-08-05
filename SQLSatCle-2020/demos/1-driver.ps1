#######################################################################################################################################
# Anthony E. Nocentino
# Centino Systems
# aen@centinosystems.com
# Platform: bash on Windows (WSL), Mac or Linux
#######################################################################################################################################


cd ./m7-demos


#Demo 1 - Creating a dotnet core web application
#Install Docker and .NET Core from a powershell prompt with an administrative priviledges
#RUN WITH ADMINISTRATIVE PRIVILEDGES
choco install dotnetcore-sdk

#Create a dotnet core application...I AM NOT a DEVELOPER.
#I bring sophisticated programs like hello world at scale in the cloud ;)
#You may need to close and reopen Code if you just installed dotnet core sdk
dotnet new webApp -o myWebApp --no-https


#Creates a default application in our current working director
ls myWebApp


#Copy in our custom Index.csthml page
cp ./mypages/Index.cshtml ./myWebApp/Pages


#Test out our application locally, change into our app dir and run
cd ./myWebApp
dotnet run
open a broswer to  http://localhost:5000


#Stop our application
ctrl+c


#Compile our application for release
dotnet publish -c Release


#Change back into the parent directory
cd ..


#Demo 2 - Creating a container based application, but look at the Dockerfile first
more Dockerfile
docker build -t mywebappimage:v1 .


#Check out the local images on our system
docker image ls
docker image ls | Select-String mywebappimage


#Run our container based application for testing, hostname is now the container image ID
docker run --name mywebapp --publish 8080:80 --detach  mywebappimage:v1
open a broswer to http://localhost:8080
docker ps




#Demo 3 - Push a container to a container registry
#To create a repository in our registry, follow the directions here
#Create an account at http://hub.docker.com
#https://docs.docker.com/docker-hub/repos/
#https://docs.docker.com/docker-hub/repos/#private-repositories


#Then let's log into docker using the account above.
docker login 


#Check out the list of local images for our image we want to upload
docker image ls mywebappimage


#Tag our image in the format your registry repository/image:tag
#You'll be using your own repository, so update that information here. 
docker tag mywebappimage:v1 nocentino/mywebappimage:v1


#Now push that locally tagged image into our repository at docker hub
#You'll be using your own repository, so update that information here. 
docker push nocentino/mywebappimage:v1

open a browser to your repository https://hub.docker.com/repository/docker/nocentino/mywebappimage


#Demo 4 - Create a Kubernetes Cluster and deploy our application


#Let's rollout our service
kubectl apply -f service.yaml
kubectl get service

#You need to update the image in the deployment.yaml prior to deploying
#Set the image to YOUR image in docker hub
kubectl apply -f deployment.yaml


#Check out the status
kubectl get deployment
kubectl get replicaset
kubectl get pods 


#Get the IP Address of our load balancer...if pending we'll come back to that
$SERVICEIP=$(kubectl get svc webapp -o jsonpath='{ .status.loadBalancer.ingress[].hostname }')
#Open a browser to http://localhost:80


#5 - Scaling our application
kubectl scale deployment.v1.apps/webapp-deployment --replicas=10


#Check out how many pods...so fast
kubectl get pods -o wide


#Let's scale our application to 50 Pods
kubectl scale deployment.v1.apps/webapp-deployment --replicas=50


#Check out how many pods...so so fast!
kubectl get pods 


#Access our application again, workload should be load balanced.
#In a broswer you'll need to force a refresh
#Firefox CTRL+SHIFT+R
#Edge CTRL+F5
#Open a browser to http://localhost:80


#Let's update our application to verison 2
cp ./mypages/Indexv2.cshtml ./myWebApp/Pages/Index.cshtml


#Compile our application for release
cd ./myWebApp
dotnet publish -c Release


#Build a docker container image
cd ../
docker build -t mywebappimage:v2 .


#We still have all of our previous versions
docker image ls mywebappimage 


#Tag the new image as v2
docker tag mywebappimage:v2 nocentino/mywebappimage:v2


#Now push that locally tagged image into our repository at docker hub
#You'll be using your own repository, so update that information here. 
#Notice only the new layer gets uploaded
docker push nocentino/mywebappimage:v2


#Check it out in docker hub
open https://hub.docker.com/repository/docker/nocentino/mywebappimage


#Now lets update our deployment with v2, update this image with YOUR repository information
kubectl apply -f deploymentv2.yaml --record

#During the rollout check the status of the rollout with these commands 
kubectl get deployment
kubectl desribe deployment
kubectl rollout status deployment webapp-deployment


#Check the application, v2?
#In a broswer you'll need to force a refresh
#Firefox CTRL+SHIFT+R
#Edge CTRL+F5
#Open a browser to http://localhost:80



#Time to clean up
Remove-Item ./myWebApp
docker stop mywebapp
docker rm mywebapp
docker rmi mywebappimage:v1
docker rmi mywebappimage:v2
docker rmi nocentino/mywebappimage:v1
docker rmi nocentino/mywebappimage:v2
kubectl delete deployment webapp-deployment
kubectl delete service webapp
