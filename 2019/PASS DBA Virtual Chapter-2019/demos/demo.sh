#This demo is using bash on a Mac. Some of the OS commands will need to change to match your local environment and working directories.

#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
PASSWORD='S0methingS@Str0ng!'

#Change working directory to demos
cd ~/Dropbox/Talks/Containers\ -\ You\ Better\ Get\ on\ Board/demos

#List available images from DockerHub
docker search mssql-server | sort

#Pull a container, discuss layers. Defaults to pulling the most recent image
docker pull mcr.microsoft.com/mssql/server:2017-CU15-ubuntu
docker pull mcr.microsoft.com/mssql/server:2017-latest
pwsh
#Shout out to Andrew Pruski (@dbafromthecold) for this little gem...
(Invoke-Webrequest https://mcr.microsoft.com/v2/mssql/server/tags/list).content
exit

#list of images on this system
docker images
docker images | grep sql

#Check out the docker image details
docker image inspect mcr.microsoft.com/mssql/server:2017-CU15-ubuntu | more

#Run a container
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD='$PASSWORD \
    --name 'sql1' \
    --publish 1433:1433 \
    --detach mcr.microsoft.com/mssql/server:2017-CU15-ubuntu

#Finding help in docker
docker help run | more 

#Let's read the logs
docker logs sql1 | more

#List running containers
docker ps

#Access our application
sqlcmd -S localhost,1433 -U sa -Q 'SELECT @@SERVERNAME' -P $PASSWORD
sqlcmd -S localhost,1433 -U sa -Q 'SELECT @@VERSION' -P $PASSWORD

#####LET'S LAUNCH Azure Data Studio for Warwick :) ######
#####Be sure to launch the Manage screen too...    ######

#Run a second container, new name, new port, same source image
docker run \
    --name 'sql2' \
    -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD='$PASSWORD \
    -p 1434:1433 \
    -d mcr.microsoft.com/mssql/server:2017-CU15-ubuntu

#List running containers
docker ps

#Access our second application, discuss servername, connect to specific port
sqlcmd -S localhost,1434 -U sa -Q 'SELECT @@SERVERNAME' -P $PASSWORD

#Copy a file into a container
#You can get WideWorldImporters-Full.bak from
#curl https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak
docker cp WideWorldImporters-Full.bak sql2:/var/opt/mssql/data

#Restore a database to our container
sqlcmd -S localhost,1434 -U sa -i restore_wwi.sql -P $PASSWORD

#Connect to the container, start an interactive bash session
docker exec -it sql2 /bin/bash

#Inside container, check out the uploaded and process listing
ps -aux 
ls -la /var/opt/mssql/data
exit

#Stopping a container
docker stop sql2

#List all containers
docker ps
docker ps -a

#Starting a container that's already local. All the parameters from the docker run command perist
docker start sql2
docker ps

#Stop them containers...
docker stop sql{1,2}
docker ps -a

#Stop all containers
#docker stop $(docker ps -a -q)

#Removing THE Container...THIS WILL DELETE YOUR DATA IN THE CONTAINER
docker rm sql{1,2}

#Remove all containers
#docker rm $(docker ps -a -q)

#Even though the containers are gone, we still have the image!
docker image ls | grep sql 
docker ps -a

#Persisting data with a Container
#Start up a container with a Data Volume
docker run \
    --name 'sql1' \
    -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD='$PASSWORD \
    -p 1433:1433 \
    -v sqldata1:/var/opt/mssql \
    -d mcr.microsoft.com/mssql/server:2017-CU15-ubuntu

#Copy the database into the Container and restore it
docker cp WideWorldImporters-Full.bak sql1:/var/opt/mssql/data
sqlcmd -S localhost,1433 -U sa -i restore_wwi.sql -P $PASSWORD

#Check out our list of databases
sqlcmd -S localhost,1433 -U sa -Q 'SELECT name from sys.databases' -P $PASSWORD
sqlcmd -S localhost,1433 -U sa -Q 'SELECT name, physical_name from sys.master_files' -P $PASSWORD -W

#Stop the container then remove it. Which normally would destroy our data
docker stop sql1
docker rm sql1

#Start the container back up, using the same data volume. We need docker run since we deleted the container.
docker run \
    --name 'sql1' \
    -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD='$PASSWORD \
    -p 1433:1433 \
    -v sqldata1:/var/opt/mssql \
    -d mcr.microsoft.com/mssql/server:2019-latest

#Check out our list of databases...wut?
sqlcmd -S localhost,1433 -U sa -Q 'SELECT name from sys.databases' -P $PASSWORD

#List our current volumes
docker volume ls

#Dig into the details about our volume
docker volume inspect sqldata1

#stop our container
docker stop sql1

#delete our container
docker rm sql1

#remove the created volume
docker volume rm sqldata1

#Run PowerShell in a container, that removes itself right after execution...sounds like...serverless?
docker run --rm mcr.microsoft.com/powershell:latest pwsh -c "&{Get-Process}"

#remove the image
#docker rmi mcr.microsoft.com/mssql/server:2017-latest

#Remove the containers based on the name
#docker ps -a -q | grep "^k8s" | awk '{print $1}' | xargs docker rm

#Remove a the images based on the name
#docker images | grep "^k8s" | awk '{print $3}' | xargs docker rmi

#if there's a new image available if you pull again only new containers will be sourced from that image.
#You'll need to create a new container and migrate your data to it.
