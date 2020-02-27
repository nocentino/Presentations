#######################################################################################################################################
# Anthony E. Nocentino
# Centino Systems
# aen@centinosystems.com
# Platform: bash on Windows (WSL), Mac or Linux
#######################################################################################################################################


#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
PASSWORD='S0methingS@Str0ng!'


#Pull a container, examine layers.
docker pull mcr.microsoft.com/mssql/server:2019-latest
docker pull mcr.microsoft.com/mssql/server:2019-CU1-ubuntu-16.04
docker pull mcr.microsoft.com/mssql/server:2019-CU2-ubuntu-16.04


#List all available images in a registry...CU2 isn't there...there's an issue with updating the metadata atm
curl -sL https://mcr.microsoft.com/v2/mssql/server/tags/list | jq .tags[]


#list of images on this system
docker images
docker images | grep sql


#Check out the docker image details
docker image inspect mcr.microsoft.com/mssql/server:2019-CU2-ubuntu-16.04 | more
docker image inspect mcr.microsoft.com/mssql/server:2019-latest | more


#Run a container
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql1' \
    --publish 1433:1433 \
    --detach mcr.microsoft.com/mssql/server:2019-CU2-ubuntu-16.04


#Finding help in docker
docker help run | more 


#Let's read the logs
docker logs sql1 | more


#List running containers
docker ps


#Access our application
sqlcmd -S localhost,1433 -U sa -Q 'SELECT @@SERVERNAME' -P 'S0methingS@Str0ng!'
sqlcmd -S localhost,1433 -U sa -Q 'SELECT @@VERSION' -P 'S0methingS@Str0ng!'


#Run a second container, new name, new port, same source image
docker run \
    --name 'sql2' \
    -e 'ACCEPT_EULA=Y' \
    -e 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    -p 1434:1433 \
    -d mcr.microsoft.com/mssql/server:2019-CU2-ubuntu-16.04


#List running containers
docker ps


#Access our second application, discuss servername, connect to specific port
sqlcmd -S localhost,1434 -U sa -Q 'SELECT @@SERVERNAME' -P 'S0methingS@Str0ng!'


#Copy a backup file into the container and set the permissions
docker cp TestDB1.bak sql2:/var/opt/mssql/data
docker exec -u root sql2 chown mssql /var/opt/mssql/data/TestDB1.bak


#Restore a database to our container
sqlcmd -S localhost,1434 -U sa -i restore_testdb1.sql -P 'S0methingS@Str0ng!'


#Connect to the container, start an interactive bash session
docker exec -it sql2 /bin/bash


#Inside container, check out the uploaded and process listing
ps -aux
ls -la /var/opt/mssql/data
exit


#Stopping a container
docker stop sql2


#List running containers
docker ps

#List all containers, including stopped containers. Examine the status and the exit code
docker ps -a


#Starting a container that's already local. All the parameters from the docker run command persist.
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
    -e 'ACCEPT_EULA=Y' \
    -e 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    -p 1433:1433 \
    -v sqldata1:/var/opt/mssql \
    -d mcr.microsoft.com/mssql/server:2019-CU2-ubuntu-16.04


#Copy the database into the Container, set the permissions on the backup file and restore it
docker cp TestDB1.bak sql1:/var/opt/mssql/data
docker exec -u root sql1 chown mssql /var/opt/mssql/data/TestDB1.bak
sqlcmd -S localhost,1433 -U sa -i restore_testdb1.sql -P 'S0methingS@Str0ng!'


#Check out our list of databases
sqlcmd -S localhost,1433 -U sa -Q 'SELECT name from sys.databases' -P 'S0methingS@Str0ng!'
sqlcmd -S localhost,1433 -U sa -Q 'SELECT name, physical_name from sys.master_files' -P 'S0methingS@Str0ng!' -W


#Stop the container then remove it. Which normally would destroy our data..but we're using a volume now.
docker stop sql1
docker rm sql1


#Start the container back up, using the same data volume. We need docker run since we deleted the container.
docker run \
    --name 'sql1' \
    -e 'ACCEPT_EULA=Y' \
    -e 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    -p 1433:1433 \
    -v sqldata1:/var/opt/mssql \
    -d mcr.microsoft.com/mssql/server:2019-CU2-ubuntu-16.04


#Check out our list of databases...wut?
sqlcmd -S localhost,1433 -U sa -Q 'SELECT name from sys.databases' -P 'S0methingS@Str0ng!'


#List our current volumes
docker volume ls


#Dig into the details about our volume
docker volume inspect sqldata1


#stop our container
docker stop sql1


#delete our container
docker rm sql1


#remove the created volume
#THIS WILL DELETE YOUR DATA!!! :(
docker volume rm sqldata1


#remove an image
#docker rmi mcr.microsoft.com/mssql/server:2019-latest


#Remove the containers based on the name
#docker ps -a -q | grep "^k8s" | awk '{print $1}' | xargs docker rm


#Remove a the images based on the name
#docker images | grep "^k8s" | awk '{print $3}' | xargs docker rmi


#if there's a new image available if you pull again only new containers will be sourced from that image.
#You'll need to create a new container and migrate your data to it.