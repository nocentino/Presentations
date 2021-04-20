cd ../demo3

#Run a container with no limits, but a stable name and a restart policy.
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo3a' \
    --hostname 'sqldemo3a' \
    --publish 31433:1433 \
    --restart unless-stopped \
    --detach sqlimagedemo1

#Now we have a stable server name
docker ps
sqlcmd -S localhost,31433 -U sa -Q "SELECT @@SERVERNAME AS [ServerName]" -P 'S0methingS@Str0ng!'  -W


#Query the CPU and Memory configuration of the container.
#SQL Server on Linux see 80% of RAM from the base OS. 8GB * .80 ~=6GB
free -m
sqlcmd -S localhost,31433 -U sa -Q "SELECT cpu_count AS [CPU Count], physical_memory_kb / 1024 / 1024 as [MemoryGB] FROM sys.dm_os_sys_info" -P 'S0methingS@Str0ng!' 


#Docker stats
#Definitions from - https://docs.docker.com/engine/reference/commandline/stats/
#CONTAINER ID and Name  - The ID and name of the container
#CPU % and MEM % 	    - Percentage of the host’s CPU and memory the container is using. If yuo're on Mac or Windows, that's the percentage of memory of the VM backing your docker containers
#MEM USAGE / LIMIT      - The total memory the container is using, and the total amount of memory it is allowed to use. If no limit, it's the max set in docker config Preferences->Resources
#NET I/O                - The amount of data the container has sent and received over its network interface
#BLOCK I/O              - The amount of data the container has read to and written from block devices on the host
#PIDs                   - The number of processes or threads the container has created
docker stats


#Start another container with a 4GB memory limit and 1 CPU limit
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo3b' \
    --hostname 'sqldemo3b' \
    --memory 4GB \
    --cpus 1 \
    --publish 31434:1433 \
    --detach sqlimagedemo1


#Two containers running on two different ports
docker ps


#Query the CPU and Memory configuration of the container...we said 4GB but got 3GB, and we said 2CPU and see 4 why?
#SQL Server on Linux uses 80% of RAM and our container has 4GB assigned...so 3GB
#Using --CPUs impacts the scheduling on to the cores not limits access to the core same.
sqlcmd -S localhost,31434 -U sa -Q "SELECT cpu_count, physical_memory_kb / 1024 / 1024 as Memory FROM sys.dm_os_sys_info" -P 'S0methingS@Str0ng!' 


#Start a workload and background the workload
sqlcmd -S localhost,31434 -U sa -P 'S0methingS@Str0ng!' -i workload.sql -o /dev/null

docker stats

#Run docker stats in another window
docker update sqldemo3b --cpus .5
docker update sqldemo3b --cpus .1


#But remember, yes they're containers, but they're just processes running on the base OS too.
sudo ps -aux --forest


#clean up the demo
docker rm -f sqldemo3a sqldemo3b 
