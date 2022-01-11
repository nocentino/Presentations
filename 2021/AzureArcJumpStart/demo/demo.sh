ssh aen@docker0
cd ~/content/AzureArcJumpStart/demo


#Run a container with no limits and a stable hostname
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo1' \
    --hostname 'sqldemo1' \
    --publish 31433:1433 \
    --detach mcr.microsoft.com/mssql/server:2019-CU9-ubuntu-18.04 


#Query the CPU and Memory configuration of the container.
#SQL Server on Linux see 80% of RAM from the base OS. 16GB * .80 ~=12.8GB
sqlcmd -S localhost,31433 -U sa \
    -Q "SELECT cpu_count AS [CPU Count], physical_memory_kb / 1024 / 1024 as [MemoryGB] FROM sys.dm_os_sys_info" \
    -P 'S0methingS@Str0ng!' 
free -m


#Start another container with a 4GB memory limit and 1 CPU limit
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sqldemo2' \
    --hostname 'sqldemo2' \
    --memory 4GB \
    --cpus 1 \
    --publish 31434:1433 \
    --detach mcr.microsoft.com/mssql/server:2019-CU9-ubuntu-18.04 


#Two containers running on two different ports
docker container ls -a --format "table {{.Names }}\t{{ .Image }}\t{{ .Status }}\t{{.Ports}}"


#Query the CPU and Memory configuration of the container...we said 4GB but got 3GB, and we said 2CPU and see 4 why?
#SQL Server on Linux uses 80% of RAM and our container has 4GB assigned...so 3GB
#Using --CPUs impacts the scheduling on to the cores not limits access to the core same.
sqlcmd -S localhost,31434 -U sa \
    -Q "SELECT cpu_count, physical_memory_kb / 1024 / 1024 as Memory FROM sys.dm_os_sys_info" \
    -P 'S0methingS@Str0ng!' 



docker stats


#clean up the demo
docker rm -f sqldemo1 sqldemo2


#Let's check out an Azure Arc enabled Managed instance
ssh aen@arc01

#az sql mi-arc create --name sqldemo01 --k8s-namespace arc --use-k8s
az sql mi-arc list --k8s-namespace arc --use-k8s --output table


sqlcmd -S arc01,32474 -U arcadmin \
    -Q "SELECT cpu_count AS [CPU Count], physical_memory_kb / 1024 / 1024 as [MemoryGB] FROM sys.dm_os_sys_info" \
    -P 'S0methingS@Str0ng!' 
lscpu
free -m
