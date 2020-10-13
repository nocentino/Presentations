#Anthony E. Nocentino
#aen@centinosystems.com
#www.centinosystems.com

#Looking at our CPU Topology
#4vCPUs 12GB RAM

#Setup overview...
#	Freshly booted system
#	SQL Instance Max Memory 8192
#	htop configured to show threads and by tree
#	Two SSH connections to SQL on Linux instance
#	Connect VS Code open demos.sql
#   sudo yum install iotop sysstat strace dstat
#   sudo curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/8/prod.repo
#   sudo yum install htop

ssh aen@sql1
cd ~/content/demos

#Set password variable used for sa password for SQL Server - https://www.youtube.com/watch?v=WyBKzBtaKWM
PASSWORD='S0methingS@Str0ng!'

#CPU - Processes and threads
#Launch htop, show that all the VIRT and RSS columns are the same for each thread because of the shared memory space.
htop 
ctrl+c


#Start a workload, background it and start htop again...and review the CPU under load...
#Key Points to look at when running the workload...
# - Primarily in kernel time while reading from disk and allocating pages in memory. 
# - Once the data is in memory, then CPU will drop and well be mostly in user space.
# - Load average goes up to above 2 due to the parallel threads executing
# - Observe different workers doing work, these corresponds to SQL tasks executing in a worker
# - Our table is larger than buffer pool, so PLE dips and we have to wait on IO as pages are pushed out and read in.
# - Review process states R, S and D
sh ./mySqlCmd.sh checkdb.sql & 
htop
dstat -t
ctrl+c


#Stop the workload
kill $(pidof sqlcmd)
fg
ctrl+c


#Exploring procfs
#Listing of all PIDs and other critical system information is exposed in /proc
#/proc is the data source to nearly all of the monitoring tooling available
ls /proc


#Looking at CPU information in /proc
cat /proc/cpuinfo
lscpu


#Looking more closely at process information
#to get our sqlservr processes process IDs (PIDs)
pidof sqlservr


#We can change into the processes directory in /proc and get a TON more infomation
cd /proc/$(pidof sqlservr -s)/
pwd


#Looking around we see things like...
ls


#The actual binary that's running
more cmdline


#Some deep dive process information...we're going to look at this more closely in a second in the memory section
more status 



#Memory - available and usage statistics
#Warm up buffer pool...about 20 seconds.
sqlcmd -S localhost,1433 -U sa -Q 'SELECT COUNT(*) from testdb1.dbo.t1' -P $PASSWORD


#Memory layout, review total, used, free and buff/cache
free -m
cat /proc/meminfo | more


#Start up htop and look as RSS and VSZ
htop


#Process memory deep dive
#Memory utilization and allocation types
pidof sqlservr
cd /proc/$(pidof sqlservr -s)/


#(Review all virtual memory attributes)
#VmPeak: Peak virtual memory usage
#VmSize: Current virtual memory usage
#VmLck:	 Current mlocked memory
#VmHWM:	 Peak resident set size
#VmRSS:	 Resident set size
#VmData: Size of "data" segment
#VmStk:	 Size of stack
#VmExe:	 Size of "text" segment
#VmLib:	 Shared library usage
#VmPTE:  Pagetable entries size
#VmSwap: Swap space used
more status


#External Memory Pressure Demo and Excessive swapping
#change back into the starting directory and start read workload in the background
cd -
sh ./mysqlcmd.sh readtable.sql &


#Review VSZ and RES for sqlservr in htop, should be around 8GB
htop 
ctrl+c
			

#Apply external memory pressure, but not enough to fill the swap file
./memtest 10240 > /dev/null & 


#In htop review RES for both sqlservr and memstat, also swap usage
htop
ctrl+c


#Observe the swap in/out of pages, identify thrasing due to read workload and memtest
vmstat 1 


#Individual process swapping - (minor = uninitialized memory, major = from disk)
pidstat -r 1 


#Find the amount of a process that swapped out
pidof sqlservr
more /proc/$(pidof sqlservr -s)/status


#In VSCode in demos.sql, query sys.dm_os_memory_clerks, bpool still populated even though 1/2 of address space is paged out
#Query ring buffer for resource monitor alerts


#kill memtest, RES of sqlserver will grow since read workload will pull the pages back in
kill $(pidof memtest)
htop 

#kill the workload
kill $(pidof sqlcmd)
fg
ctrl+c


#So whats this mean? 
#Set max memory your instance to control memory allocation and control paging


#Disk monitoring
#Identifying high I/O processes
sh ./mySqlCmd.sh checkdb.sql &

#Total is proces to kernel IO, Actual is kernel to disk IO. May not be equal due to caching and other kernel magic like IO reordering
sudo iotop
sudo pidstat -d 1

#Review iostat column definitions
# r/s w/s - Requests per second (IOs
# rkB/s wkB/s - Amount of data
# rrqm/s wrqm/s - Merged IOs per second
# %rrqm %wrqm - Percent merged 
# r_await w_await - Avg. wait time (ms) 
# Queue size (kb) - rareq-sz wareq-sz  
# Avg queue length - aqu-sz 
# svctm  - service time, deprecated
# %util - percent utilization
sudo iostat -dx

#kill the workload
kill $(pidof sqlcmd)
fg
ctrl+c


#Let's query dm_io_virtual_file_stats in demos.sql


#Using sar to answer what happened when? 
#CPU utilization
sar -u  

#per CPU breakdown
sar -u -P ALL 

#Load averages
sar -q

#Memory 
sar -r

#Swapping/Paging
sar -B

#Disk 
sar -b
 
#Dump Everything
sar -A
sar -A -P ALL | less


#Bonus Material 
sudo pidstat -C "sqlservr"-u -p ALL 1
strace -f -p $(pidof sqlservr -s)

#strace like with durations
sudo perf trace -p $(pidof sqlservr -s)
sudo perf top -p $(pidof sqlservr -s) --sort comm,dso,symbol,cpu

#Bonus Materials - view anonymous pages and memory map
#review anomymous, SFPs and other linux libraries loaded
sudo pmap -x $(pidof sqlservr -s)

#Bonus Material
#Block sizes and file system configuration
sudo xfs_info /
