cd ../demo2


#Demo 1 - Mount and external volume into the container and restore "large" backups
#You can COPY the database into the container during the build, but then this can cause your container to grow
#This will keep the weight of the databases outside of the container.
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo2a' \
    --publish 31433:1433 \
    --volume sqldata2a:/var/opt/mssql \
    --volume ~/content/Containers-WhatsNext/backups:/backup \
    --detach sqlimagedemo1


#You can copy backups into the container...but why???  Time...space???
#docker cp ../backups/TestDB1.bak sqldemo2a:/backup
#docker exec -u root sqldemo2a chown mssql /var/opt/mssql/data/TestDB1.bak
#sqlcmd -S localhost,31433 -U sa -i restore_testdb1.sql -P 'S0methingS@Str0ng!'


#Check out the contents of the mounted backup folder
ls -lah ~/content/Containers-WhatsNext/backups
docker exec -it sqldemo2a ls -lah /backup
sqlcmd -S localhost,31433 -U sa -i ./scripts/restore_testdb1.sql -P 'S0methingS@Str0ng!'


#Get a list of databases
sqlcmd -S localhost,31433 -U sa -Q 'SELECT name from sys.databases' -P 'S0methingS@Str0ng!' -W


#Clean up from demo
docker rm -f sqldemo2a
docker volume rm sqldata2a



#Demo 2 - Mount and external volume into the container and restore backups on container startup
#Build a new image pointing CMD to /scripts/configure-db.sh 
docker build -t sqlimagedemo2 . 


#Run a container that will restore a database automatically
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo2b' \
    --publish 31434:1433 \
    --volume sqldata2b:/var/opt/mssql \
    --volume ~/content/Containers-WhatsNext/backups:/backup \
    --detach sqlimagedemo2


#Attach to the log to watch the start up process...one the engine is online, the restore will start
docker logs sqldemo2b --follow


#Get a list of databases
sqlcmd -S localhost,31434 -U sa -Q 'SELECT name from sys.databases' -P 'S0methingS@Str0ng!' -W


#Let's look at where those files and backups are inside the container
docker exec -it sqldemo2b /bin/bash
ls /backup
ls /scripts
ps -aux --forest
exit


#Clean up from demo
docker rm -f sqldemo2b 
docker volume rm sqldata2b
