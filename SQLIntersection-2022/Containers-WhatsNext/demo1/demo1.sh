#log into our linux host
ssh aen@docker0
cd ../demo1


#Let's build that image
docker build -t sqlimagedemo1 . 


#Run a container
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo1' \
    --hostname 'sqldemo1' \
    --volume sqldata1:/var/opt/mssql \
    --publish 31433:1433 \
    --detach sqlimagedemo1


#Is the container running?
docker ps


#Can I connect to SQL Server?
sqlcmd -S localhost,31433 -U sa -Q 'SELECT @@SERVERNAME' -P 'S0methingS@Str0ng!'
sqlcmd -S localhost,31433 -U sa -Q 'SELECT @@VERSION' -P 'S0methingS@Str0ng!'


#Which user is running mssql? And let's check out the mssql-conf file
docker exec -it sqldemo1 /bin/bash
ps -aux --forest
cat /var/opt/mssql/mssql.conf
env
ls -la /var/opt/mssql
ls -la /var/opt/mssql/data
exit


#Where is the volume really?
docker volume inspect sqldata1
sudo ls -la /var/lib/docker/volumes/sqldata1/_data
sudo ls -la /var/lib/docker/volumes/sqldata1/_data/data


#Stop and delete that container
docker rm -f sqldemo1 #container
docker volume rm sqldata1 #removed the volume
sudo ls -la /var/lib/docker/volumes
