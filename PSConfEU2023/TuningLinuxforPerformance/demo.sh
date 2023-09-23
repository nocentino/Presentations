########################################################################################
#   Setup overview...
#   VM - 4 vCPUs 12GB RAM / 1 150GB data volume (/data), 1 100GB system volume (all other mounts)
#   Ubuntu 20.04 LTS
#	  Freshly booted system
#	  SQL Instance Max Memory 8192
#
#     wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
#     sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"
#     sudo apt-get update
#     sudo apt-get install -y mssql-server
#     sudo /opt/mssql/bin/mssql-conf setup
#     curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
#     curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
#     sudo apt-get update
#     sudo apt-get install mssql-tools unixodbc-dev curl sysbench  
#     echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
#
#     Run demo-setup.sql to create the database and populate it with data
########################################################################################


#Connect to our Linux server via ssh
ssh aen@linux01
cd demos/PSConfEU/LinuxPerf/


########################################################################################
#Demo 1 - Tuning tools and techniques
########################################################################################
# * Dedicated tools - cpupower, x86_energy_perf_policy, blockdev, or changing file system behaviour on mount
# * sysctl parameters - changes kernel parameters at runtime
# * OS specific tools like tuned, SUSE Linux Enterprise Server 12 SP5, Ubuntu 18.04, and Red Hat Enterprise Linux 7.x
########################################################################################
#Get a listing of all configuration parameters
sudo sysctl -a


#You can persist settings in /etc/sysctl.conf
sudo more /etc/sysctl.conf


#You may want to consider using an OS specific tool like tuned, this gives you a 
#standard interface across distributions and consolidates much of the tuning activities 
#such as kernel parameters, tools and more into to this one tool and persists between reboots.
systemctl status tuned


#List the available profiles in our tuned config
tuned-adm list | more 


#Ask tuned to make a recommendation based off the system's configuration
tuned-adm recommend


#Check out the current running profile
tuned-adm active


#Let's examine the virtual-guest profile
more  /usr/lib/tuned/virtual-guest/tuned.conf


#virtual-guest inherits throughput-performance
#This includes all of the power settings we're going to add below and will persist between reboots.
more /usr/lib/tuned/throughput-performance/tuned.conf
########################################################################################



########################################################################################
#Demo 1 - CPU Tuning and Benchmarking
########################################################################################
# * Dimensions to tune on
#   * Proper sizing - number of processors/cores
#   * Clock Rate - is it fast enough? Also, actual and power saved clock rate
#   * Scheduler influence
#   * Processor utilization isn’t a key metric
########################################################################################
#Let's get some CPU information with cpuinfo
# ** Sleep (C-states)
# ** Frequency and voltage (P-states) - https://www.kernel.org/doc/Documentation/cpu-freq/intel-pstate.txt
#From - https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/monitoring_and_managing_system_status_and_performance/tuning-cpu-frequency-to-optimize-energy-consumption_monitoring-and-managing-system-status-and-performance

# ** Each C-state is deeper and the exit latency is longer, increasing the power savings

# ** C0 - In this state, the CPU is working and not idle at all.
# ** C1, Halt - In this state, the processor is not executing any instructions but is typically not in a lower power state. The CPU can continue processing with practically no delay. All processors offering C-states need to support this state. Pentium 4 processors support an enhanced C1 state called C1E that actually is a state for lower power consumption.
# ** C2, Stop-Clock - In this state, the clock is frozen for this processor but it keeps the complete state for its registers and caches, so after starting the clock again it can immediately start processing again. This is an optional state.
# ** C3, Sleep - In this state, the processor goes to sleep and does not need to keep its cache up to date. Due to this reason, waking up from this state needs considerably more time than from the C2 state. This is an optional state.cpupower -c all idle-info


#############################################################
# Reccomended power settings for a high performance system
#############################################################
#Examine the C-states configuration and set the frequency governor to performance
#Settings managed by cpupower and/or tuned
# * CPU frequency governor - performance
# * C-States - C1 only
# * min_perf_pct - 100 # this is a P-state config for controlling percent CPU frequency
#############################################################

####Output from a test system################################
# cpupower shows us the c-states supported by this CPU, 
# This system has 4 cores, this is CPU 0 only, other core's output ommitted
#############################################################
cpupower idle-info

CPUidle driver: intel_idle
CPUidle governor: menu
analyzing CPU 0:

Number of idle states: 6
Available idle states: POLL C1 C6N C6S C7 C7S
POLL:
Flags/Description: CPUIDLE CORE POLL IDLE
Latency: 0
Usage: 2089817
Duration: 17824306
C1:
Flags/Description: MWAIT 0x00
Latency: 1
Usage: 11309610
Duration: 4414589296
C6N:
Flags/Description: MWAIT 0x58
Latency: 80
Usage: 950147
Duration: 713663353
C6S:
Flags/Description: MWAIT 0x52
Latency: 200
Usage: 7008795
Duration: 16929335522
C7:
Flags/Description: MWAIT 0x60
Latency: 1200
Usage: 5151542
Duration: 30534644563
C7S:
Flags/Description: MWAIT 0x64
Latency: 10000
Usage: 11085616
Duration: 1830000900289
#############################################################



####Output from a test system################################
# cpupower also shows the p-states supported by this CPU. 
# This system has 4 cores, this is CPU 0 only, other core's output ommitted
#############################################################
cpupower -c all frequency-info

analyzing CPU 0:
  driver: intel_pstate
  CPUs which run at the same hardware frequency: 0
  CPUs which need to have their frequency coordinated by software: 0
  maximum transition latency: Cannot determine or is not supported.
  hardware limits: 480 MHz - 2.08 GHz
  available cpufreq governors: performance powersave
  current policy: frequency should be within 480 MHz and 2.08 GHz.
                  The governor "powersave" may decide which speed to use
                  within this range.
  current CPU frequency: Unable to call hardware
  current CPU frequency: 669 MHz (asserted by call to kernel)
  boost state support:
    Supported: yes
    Active: yes
#############################################################


####Output from a test system################################
# cpupower is used to set the frequency to high performance
# This disables all c-states except C0 and C1
#############################################################
cpupower -c all frequency-set -g performance
Setting cpu: 0
Setting cpu: 1
Setting cpu: 2
Setting cpu: 3


####Output from a test system################################
# Use ENERGY_PERF_BIAS to performance to disable p-states by 
# setting all cores to 100% of their CPU clock frequency
#############################################################
x86_energy_perf_policy performance
#############################################################


#We're going to use the throughput-performance as our baseline today and 
#we'll extend it with some other settings. This includes all of the power settings 
#above and will persist between reboots.
more /usr/lib/tuned/throughput-performance/tuned.conf



#Controlling access to cores via taskset. 
#This tells the scheduler to limit this process to the specified processors

#Open htop on another screen, notice two things...
#  1. how we're restricted to two cores
#  2. That the CPU usage is nearly entirely green (User mode)
sysbench cpu --threads=4 --cpu-max-prime=10000 run
taskset --cpu-list 0,2 sysbench cpu --threads=4 --cpu-max-prime=10000 run


#Examining niceness, using htop look for processes that are less nice
#Niceness controlls the scheduling priority of processes
#You can launch a program with nice or modify a running process
#The PRI column shows niceness
# Are there any processes that are less nice...aka higher priority?
htop 
########################################################################################




########################################################################################
#Demo 2 - Memory tuning and benchmarking
# * Dimensions to tune on
#    * Having enough memory for your workload
#    * Goal prevent swapping (but really its anonymous paging)
#       * Anonymous paging - bad paging 
#       * File system paging - memory mapped files
#    * Page Size - reduces TLB pressure and CPU utilization on high IO systems
########################################################################################
#Step 1 - Query a large table, then query it again in memory, note the runtime
#With htop running, notice the amount of kernel time (the red part of the graph)
# * Key point, memory access costs CPU.
# * Lots of memory access can cost lots of CPU!!!
# * Lots of small page allocations and the disk IO keeps is in kernel mode longer
time sh ./mysqlcmd.sh readtablesmall.sql


#Linux uses 4KB page sizes by default
#AnonPages:       5240960 kB - most of the buffer pool is in regular 4k pages
#AnonHugePages:    198656 kB - not much is allocated in huge pages
#https://access.redhat.com/solutions/406773 for more details on each metric
more /proc/meminfo 

##Second run, warm buffer pool
time sh ./mysqlcmd.sh readtablesmall.sql


#Confirm that transparent huge pages are turned on
#Which value is default depends on your distribution, this one is [madvise].
#When the systems is under memory pressure, madvise can be called by the 
#application to tell the kernel its ok to release pages rather than page out to disk.
#On this system we'll get 2MB pages, this is 500 4KB pages
cat /sys/kernel/mm/transparent_hugepage/enabled


#Here's the code to change it to always.
sudo bash -c 'echo always > /sys/kernel/mm/transparent_hugepage/enabled'
cat /sys/kernel/mm/transparent_hugepage/enabled



#Enable trace flag 834 to use large page allocations
#With 834 all memory is loaded on startup, so this can take a bit
#Leave htop running, you'll see the memory allocation at startup.
sudo /opt/mssql/bin/mssql-conf traceflag 834 on 
sudo systemctl restart mssql-server.service


#Look for 'Using large pages in the memory manager'
#Buffer Pool: Allocating 2097152 bytes for 1495040 hashPages.
sudo more /var/opt/mssql/log/errorlog


#Query a large table again, then query it again in memory, note the runtime
#With htop running, there should be much less kernel time
##First run, cold buffer pool, a LOT less kernel mode time on the start....much less red and a shorter run time
time sh ./mysqlcmd.sh readtablesmall.sql


#Look at AnonPages, AnonHugePages and Hugepagesize
#Nearly all allocations are from AnonHugePages
#But AnonPages includes both regular pages and huge pages
#AnonPages:       8111064 kB
#AnonHugePages:   7481344 kB
more /proc/meminfo 


#Let's check out how much memory is dedicated to the file system cache
free -m


#Create a 1GB file
yes a | head -c 1073741824 > /home/aen/file.txt


#Let's read a 1GB file and get it in our file system cache
cat /home/aen/file.txt > /dev/null


#You can look at the memory allocations with free. Specifically buff/cache.
free -m


#Apply external memory pressure, but not enough to fill the swap file
htop
./memtest 6144 > /dev/null & 


#Kill off our memory allocator
fg + ctrl+c

#You can look at the memory allocations with free. buff/cache should be nearly empty
#Since the page cache was cleared to make room for anonymous pages
free -m


# The swappiness parameter controls the tendency of the kernel to move
# processes out of physical memory and onto the swap disk.
# Defaults to 30, our tuned profile will set it to 10. 
# Is this a good value? Higher or lower?
sysctl vm.swappiness

########################################################################################


########################################################################################
#Demo 3 - Persisting our settings with tuned
########################################################################################

#Examine the profiles interesting to our workload
#vm.max_map_count=262144 - inceases the size of memory mapped files
more /usr/lib/tuned/mssql/tuned.conf 

more /usr/lib/tuned/throughput-performance/tuned.conf 


#Switch to our new profile
sudo tuned-adm profile mssql

#Here's some of the settings we've looked at and more.
sysctl vm.swappiness
sysctl vm.max_map_count

#List the active profile
tuned-adm active


########################################################################################
#Clean up - Reset our instance back to defaults
#Disable our profile
sudo tuned-adm profile virtual-guest
sudo /opt/mssql/bin/mssql-conf traceflag 834 off
sudo systemctl restart mssql-server.service
sudo init 6
########################################################################################









########################################################################################
#ADDITIONAL DEMOS
########################################################################################
#Demo XX - Filesystem Tuning and Benchmarking
########################################################################################
#Step 1 - Examine the file meta data, specifically the access time...this is update EVERY time the file is accessed
sudo stat /data/mssql/TestDB1_log.ldf 

echo 1 > /data/mssql/file1
stat /data/mssql/file1


#Why isn't the access time increasing on subsequent reads? 
more /data/mssql/file1
stat /data/mssql/file1


#Let's write some data into the file to invalidate the page cache...this updates the Change time
echo 2 >> /data/mssql/file1
stat /data/mssql/file1


#Did the atime change, no not until we read it? 
more /data/mssql/file1
stat /data/mssql/file1

sudo systemctl stop mssql-server.service

#Unmount /data let's turn off atime, add noatime to the filesystem
sudo vi /etc/fstab
systemctl daemon-reload
sudo mount -a

sudo systemctl start mssql-server.service


#Let's change the file and see if access time gets update
echo 3 >> /data/mssql/file1
more /data/mssql/file1
stat /data/mssql/file1


echo 4 >> /data/mssql/file1
more /data/mssql/file1
stat /data/mssql/file1
##################################################################

########################################################################################
#Demo XX - Disk Tuning and Benchmarking
########################################################################################
#Step 1 - Measure runtime of read
time sh ./mysqlcmd.sh readtableonce.sql


#Configuring block read-ahead. When would this be good? 
#Default block readahead (RA) - 256 B, SQL Server suggested value is 4KB
sudo blockdev --report /dev/sdb


#Set readahead (RA) on the disk supporting the /data volume
sudo blockdev --setra  4096 /dev/sdb

#Check out our value, to persist this we'll use tuned later
sudo blockdev --report /dev/sdb
########################################################################################