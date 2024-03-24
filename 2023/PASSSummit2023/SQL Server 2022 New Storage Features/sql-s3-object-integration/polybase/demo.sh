#Start up our environment with docker compose. This can take a second for SQL Server to come online.
#   https://www.nocentino.com/posts/2022-08-13-setting-up-minio-for-sqlserver-object-storage-docker-compose/
cd ./polybase
docker compose build
docker compose up --detach 

##Jump over to demo.sql and run the code there on your SQL Server instance.


##Remove the images we built and also the volumes we created. 
docker compose down --rmi local --volumes
rm -rf ./certs
