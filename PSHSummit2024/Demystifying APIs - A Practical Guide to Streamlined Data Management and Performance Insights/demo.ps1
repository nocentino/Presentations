# Install-Module PureStoragePowerShellSDK2
Import-Module PureStoragePowerShellSDK2


# Connect to our FlashArray
$Credential = Get-Credential -UserName "anocentino" -Message 'Enter your credential information...'


# Connect to the FlashArray, negotiate highest supported API version on the arrray.
Connect-Pfa2Array -EndPoint sn1-x90r2-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError -Verbose



# Connect and create a variable for reference
$FlashArray = Connect-Pfa2Array -EndPoint sn1-x90r2-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError 



#######################################################################################################################################
###Demo 1: Connecting to your FlashArray API and using sort, limit and filter to scope your API calls to the information that you want
#######################################################################################################################################
# We can interact with the REST API directly with Invoke-Pfa2RestCommand...
# We need to authenticate, locate on the network, pass in a method and a resource we want to interact with
Invoke-Pfa2RestCommand -Array $FlashArray -Method GET -RelativeUri '/api/api_version'
Invoke-Pfa2RestCommand -Array $FlashArray -Method GET -RelativeUri 'volumes'


# We can also specify objects by name my modifying the Uri
Invoke-Pfa2RestCommand -Array $FlashArray -Method GET -RelativeUri 'volumes?names=vvol-aen-sql-22-a-1-3d9acfdd-vg%2fData-47094663' | ConvertFrom-Json

#Use Invoke-Pfa2RestCommand to get a listing of snapshots on the array
Invoke-Pfa2RestCommand -Array $FlashArray -Method GET -RelativeUri 'snapshots' | ConvertFrom-Json

# Under the hood, the PowerShell module is using the REST API to communicate to the array, 
# 1. Request hits the API endpoint, the reply comes back in JSON which is formatted on the client side
Get-Pfa2Volume -Array $FlashArray -Name 'vvol-aen-sql-22-a-1-3d9acfdd-vg/Data-47094663' -Verbose 


Get-Command -Module PureStoragePowerShellSDK2



# Let's look at the cmdlets that have performance in the name to see what's available to us to work with
# They're essentially all the CRUD operations we discussed
Get-Command -Module PureStoragePowerShellSDK2 | Where-Object { $_.Name -like "*volume*" } 
Get-Command -Module PureStoragePowerShellSDK2 | Where-Object { $_.Name -like "*array*" } 
Get-Command -Module PureStoragePowerShellSDK2 | Where-Object { $_.Name -like "*performance" } 



# Let's talk about performance when working with large sets of objects
# Get a count of how many volumes are returned when we use this cmdlet...aka how many volumes are in our array
Get-Pfa2Volume -Array $FlashArray | Measure-Object 



# Let's get the top 10 volumes in terms of TotalPhysical capacity using sorting and filtering via PowerShell
# In PowerShell v7+ you can use the Sort-Object -Top 10 parameter, in PowerShell 5.1 you will use Select-Object -First 10
Get-Pfa2Volume -Array $FlashArray | 
    Select-Object Name -ExpandProperty Space | 
    Sort-Object -Property TotalPhysical -Descending | 
    Select-Object -First 10 |
    Format-Table



# Now, let's push the heavy lifting into the array, sorting by total_physical and limiting to the top 10, 
# with Sort and Limit the hard work happens on the server side and the results are returned locally
# Where did I find that sort property...
# https://support.purestorage.com/FlashArray/PurityFA/Purity_FA_REST_API/FlashArray_REST_API_Reference_Guides 
# total_physical is The total physical space occupied by system, shared space, volume, and snapshot data. Measured in bytes.
Get-Pfa2Volume -Array $FlashArray -Sort "space.total_physical-" -Limit 10 | 
    Select-Object Name -ExpandProperty Space | 
    Format-Table



# Let's see how long each method takes to get the data from the array, first let's look at sorting and filtering via PowerShell
Measure-Command {
    Get-Pfa2Volume -Array $FlashArray | 
    Select-Object Name -ExpandProperty Space | 
    Sort-Object -Property TotalPhysical -Descending | 
    Select-Object -First 10 |
    Format-Table
} | Select-Object TotalMilliseconds



# Next, let's see how long it takes to sort and filter on the array and return just the results we want
Measure-Command {
    Get-Pfa2Volume -Array $FlashArray -Sort "space.total_physical-" -Limit 10 | 
    Select-Object Name -ExpandProperty Space | 
    Format-Table
} | Select-Object TotalMilliseconds



# Let's use filtering on a listing of volumes...first with PowerShell
Get-Pfa2Volume -Array $FlashArray | Where-Object { $_.Name -like "*aen-sql-22*" } | 
    Select-Object Name



# Now, let's push that into the array and sort in the API and use a filter to limit the amount of data returned to the client
# Examine the API endpoint call with the filter as part of the query string
Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen-sql-22*'" -Verbose | 
    Select-Object Name


Measure-Command {
    Get-Pfa2Volume -Array $FlashArray | Where-Object { $_.Name -like "*aen-sql-22*" } | 
    Select-Object Name
} | Select-Object TotalMilliseconds


Measure-Command {
    Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen-sql-22*'" | 
    Select-Object Name
} | Select-Object TotalMilliseconds

#######################################################################################################################################
#  Key take away: 
#    Use sort, limit and filter to scope your API calls to what you want to get. Will significantly increase performance
#######################################################################################################################################


#######################################################################################################################################
###Demo 2 - Identify and address bottlenecks by pinpointing hot volumes using the FlashArray API
#######################################################################################################################################
# Kick off a backup to generate some read workload
Start-Job -ScriptBlock {
    $username = "sa"
    $password = 'S0methingS@Str0ng!' | ConvertTo-SecureString -AsPlainText
    $SqlCredential = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
    Backup-DbaDatabase -SqlInstance 'aen-sql-22-a' -SqlCredential $SqlCredential -Database 'FT_Demo' -Type Full -FilePath NUL 
}


# Finding hot volumes in a FlashArray, examine the properties returned by the cmdlet
Get-Pfa2VolumePerformance -Array $FlashArray | Get-Member



# Using our sorting method from earlier, I'm going to look for something that's generating a lot of reads, 
# and limit the output to the top 10
# Get the Sort field from the API Documentation, the PowerShell object is camelcase, the array API response property has a different format
# ReadsPerSec is that PowerShell property, reads_per_sec is the array API response property. 
# Notice the underscores are removed from the PowerShell propery and the API response property is lower case and is case sensitive.
#. Sorting defaults to ascending, add a - to sort descending
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 | 
    Select-Object Name, Time, ReadsPerSec, BytesPerRead



# But what if I want to look for total IOPs, we'll I have to calculate that locally.
$VolumePerformance = Get-Pfa2VolumePerformance -Array $FlashArray
$VolumePerformance | 
    Select-Object Name, ReadsPerSec, WritesPerSec, @{label="IOsPerSec";expression={$_.ReadsPerSec + $_.WritesPerSec}} | 
    Sort-Object -Property IOsPerSec -Descending | 
    Select-Object -First 10



# Let's learn how to look back in time...
# What's the default resolution for this sample...in other words how far back am I looking in the data available?
# The default resolution on storage objects like Volumes is 30 seconds window starting when the cmdlet is run
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 | 
    Select-Object Name, Time, ReadsPerSec, BytesPerRead


# Let's look at 48 hours ago over a one day window
# In PowerShell 7 you can use Get-Date -AsUTC, In PowerShell 5.1 you can use (Get-Date).ToUniversalTime()
$Today = (Get-Date).ToUniversalTime()
$StartTime = $Today.AddDays(-3)
$EndTime = $Today.AddDays(-2)


# Let's find the to 10 highest read volumes 2 days ago. 1800000 is 30 minutes
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 `
    -StartTime $StartTime -EndTime $EndTime -resolution 1800000 |
    Select-Object Name, Time, ReadsPerSec



# Let's find the to 10 highest read volumes 2 days ago, where they have the string aen in the name.
Get-Pfa2VolumePerformance -Array $FlashArray -Limit 10 `
    -StartTime $StartTime -EndTime $EndTime -resolution 1800000 `
    -Filter "name='*aen-sql-22-a*'" -Sort 'reads_per_sec-'  | 
    Sort-Object ReadsPerSec -Descending |
    Select-Object Name, Time, ReadsPerSec



# This isn't just for volumes, hosts as well, the performance model exposed by the API
# is the same for nearly all objects
Get-Pfa2HostPerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 `
    -StartTime $StartTime -EndTime $EndTime -resolution 1800000 | 
    Select-Object Name, Time, ReadsPerSec, BytesPerRead


Get-Pfa2HostPerformance -Array $FlashArray -Sort 'writes_per_sec-' -Limit 10 `
    -StartTime $StartTime -EndTime $EndTime -resolution 1800000 | 
    Select-Object Name, Time, ReadsPerSec, WritesPerSec



#######################################################################################################################################
#  Key take aways: 
#   1. You can easily find volume level performance information via PowerShell and also our API.
#   2. Continue to use the filtering, sorting and limiting techniques discussed.
#   3. Its not just Volumes, you can do this for other objects too, Hosts, HostGroups, Pods, Directories, and the Array as a whole
#######################################################################################################################################


#######################################################################################################################################
###Demo 3 - Categorize, search and manage your FlashArray resources efficiently
#######################################################################################################################################
# Group a set of volumes with tags and get and performance metrics based on those tags
# * https://support.purestorage.com/?title=FlashArray/PurityFA/PurityFA_General_Administration/Tags_in_Purity_6.0_-_User%27s_Guide
# * https://www.nocentino.com/posts/2023-01-25-using-flasharray-tags-powershell/ 

# Let's get two sets of volumes using our filtering technique
$VolumesSqlA = Get-Pfa2Volume -Array $FlashArray -Filter "name='*vvol-aen-sql-22-a*'" | 
    Select-Object Name -ExpandProperty Name

$VolumesSqlB = Get-Pfa2Volume -Array $FlashArray -Filter "name='*vvol-aen-sql-22-b*'" | 
    Select-Object Name -ExpandProperty Name



#Output those to veridy the data is what we want.
$VolumesSqlA 
$VolumesSqlB



# Now, let's define some parameters for our Tags, their keys, values and namespace.
# A namespace is like a folder, a way to classify a subset of tags. 
# A tag is a key/value pair that can be attached to an object in FlashArray, like a volume or a snapshot. 
# Using tags enables you to attach additional metadata to objects for classification, sorting, and searching.
$TagNamespace = 'AnthonyNamespace'
$TagKey = 'SqlInstance'
$TagValueSqlA = 'aen-sql-22-a'
$TagValueSqlB = 'aen-sql-22-b'



#Assign the tags keys and values to the sets of volumes we're working with 
Set-Pfa2VolumeTagBatch -Array $FlashArray -TagNamespace $TagNamespace -ResourceNames $VolumesSqlA -TagKey $TagKey -TagValue $TagValueSqlA
Set-Pfa2VolumeTagBatch -Array $FlashArray -TagNamespace $TagNamespace -ResourceNames $VolumesSqlB -TagKey $TagKey -TagValue $TagValueSqlB



#Let's get all the volumes that have the Key = SqlInstance...or in other words all the volumes associated with SQL Servers in our environment
$SqlVolumes = Get-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Filter "Key='SqlInstance'" 
$SqlVolumes



# Now, let's perform an operation on each of the volumes that are in our set of volumes.
# We'll use Id since it can take an Array/List. 
# Name generally only takes a single value, some cmdlets take an Array/List for the Id. 
# So we'll use that parameter here to operate on the set of data in SqlVolumes.
$SqlVolumes.Resource.Id

Get-Pfa2VolumeSpace -Array $FlashArray -Id $SqlVolumes.Resource.Id -Sort "space.data_reduction" | 
    Select-Object Name -ExpandProperty Space | 
    Format-Table



# Similarly on performance cmdlets..remember this is still REST, let's look at the verbose output
Get-Pfa2VolumePerformance -Array $FlashArray -Id $SqlVolumes.Resource.Id -Verbose |
    Select-Object Name, BytesPerRead, BytesPerWrite, ReadBytesPerSec, ReadsPerSec, WriteBytesPerSec, WritesPerSec, UsecPerReadOp, UsecPerWriteOp | 
    Format-Table



# And when we're done, we can clean up our tags
Remove-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Keys $TagKey -ResourceNames $VolumesSqlA
Remove-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Keys $TagKey -ResourceNames $VolumesSqlB


#######################################################################################################################################
#  Key take aways: 
#   1. You can classify objects in the array to give your integrations more information about
#      what's in the object...things like volumes and snapshots and the applications and systems the objects are supporting
#   2. What can you do with tags? Execute operations on sets of data, volumes, snapshots, clones, accounting, performance monitoring
#######################################################################################################################################


#######################################################################################################################################
###Demo 4 - Streamline snapshot management with powerful API-driven techniques
#######################################################################################################################################
# * https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/a_Windows_PowerShell/How-To%3A_Working_with_Snapshots_and_the_Powershell_SDK_v2#Volume_Snapshots_2

# Let's take a Protection Group Snapshot
$PgSnapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceNames 'aen-sql-22-a-pg' 
$PgSnapshot



# Let's take a look at ProtectionGroupSnapshot object model
$PgSnapshot | Get-Member



# Using a snapshot suffix, take a PG Snapshot with a suffix
$PgSnapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceNames 'aen-sql-22-a-pg' -Suffix "DWCheckpoint1"
$PgSnapshot



# Get a PG Snapshot by suffix
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray | Where-Object { $_.Suffix -eq 'DWCheckpoint1'}
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceNames 'aen-sql-22-a-pg' -Filter "suffix='DWCheckpoint1'" 



# Find snapshots that are older than a specific date, we need to put the date into a format the API understands
# In PowerShell 7 you can use Get-Date -AsUTC, In PowerShell 5.1 you can use (Get-Date).ToUniversalTime()
$Today = (Get-Date).ToUniversalTime()
$Created = $Today.AddDays(-30)
$StringDate = Get-Date -Date $Created -Format "yyy-MM-ddTHH:mm:ssZ"



# There's likely lots of snapshots, so let's use array side filtering to 
# limit the set of objects and find snapshots older than a month on our array
Get-Pfa2VolumeSnapshot -Array $FlashArray -Filter "created<'$StringDate'" -Sort "created" |
    Select-Object Name, Created



#Similarly we can do this for protection groups 
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Filter "created<'$StringDate'" -Sort "created" |
    Select-Object Name, Created



# Let's get a listing of PG snapshots older than 30 days    
$PgSnapshots = Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceName 'aen-sql-22-a-pg' 
$PgSnapshots.Id



# You can remove snapshots with these cmdlets
#Remove-Pfa2VolumeSnapshot -Array $FlashArray -Id $PgSnapshots



#We can remove as snapshot, but this places it in the eradication bucket rather than deleting it straigh away
Remove-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Name 'aen-sql-22-a-pg.DWCheckpoint1' 



#If you want to delete the snapshot right now, you can add the Eradicate parameter
Remove-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Name 'aen-sql-22-a-pg.DWCheckpoint1' -Eradicate 





#Top 10 volumes sorted by worst DRR
$DRR = 4.0
Get-Pfa2VolumeSpace -Array $FlashArray -Filter "space.data_reduction<='$DRR'" -Sort "space.data_reduction"




#######################################################################################################################################
###Demo 4 - Setup and deploy the OpenMetrics Exporter, enabling you to collect and analyze data from your Pure Storage arrays
#######################################################################################################################################
# * Offical Repository - https://github.com/PureStorage-OpenConnect/pure-fa-openmetrics-exporter
# * Blog Post -  https://www.nocentino.com/posts/2022-12-20-monitoring-flasharray-with-openmetrics/
Set-Location ~/Documents/GitHub/pure-fa-openmetrics-exporter/examples/config/docker
docker compose up --detach
http://localhost:3000
docker compose down 
Set-Location ~

#######################################################################################################################################
#  Key take away: 
#   1. Leverage our API to give you cross-domain insight into your systems, applications and platforms.
#######################################################################################################################################
