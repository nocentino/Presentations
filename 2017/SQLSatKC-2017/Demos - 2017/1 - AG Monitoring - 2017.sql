/*
	Switch to SQL CMD Mode!!!

	If you'd like to try this on your own, change the host names on the :CONNECT lines to match the host names of your AG replicas.
	This demo uses three SQL Servers in the Availability Group. Two synchronous replicas on the same subnet,
	one asynchronous replicas on a seperate subnet. Connected with a simulated WAN. Refer to the presentation for
	a network diagram.

	Presentation Setup - Add 10ms network delay on router

	Demo 1 - Current configuration of the AG
	
		1. Check out the synchronization_state_desc synchronized vs. synchronizing when comparing synchronous replicas with async replicas
		2. is_commit_participant
*/

:CONNECT  SQL-A\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , r.availability_mode_desc
      , r.failover_mode_desc
	  , rs.is_commit_participant			--value is only valid on primary replica, 0 is replica is behind or offline
      , rs.synchronization_state_desc		--in synchronous mode - look for synchronized, async should be synchronizing
      , rs.synchronization_health_desc		--in synchronous mode - healthy when synchronized, partially when synchronizing, not healthy when not sync'ing. in asynchnous mode - healthy when synchronizing, not healthy when not sync'ing
      , r.endpoint_url
      , r.session_timeout
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

:CONNECT  SQL-B\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , r.availability_mode_desc
      , r.failover_mode_desc
	  , rs.is_commit_participant			
      , rs.synchronization_state_desc
      , rs.synchronization_health_desc
      , r.endpoint_url
      , r.session_timeout
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

:CONNECT  SQL-C\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , r.availability_mode_desc
      , r.failover_mode_desc
	  , rs.is_commit_participant				--value is only valid on primary replica
      , rs.synchronization_state_desc
      , rs.synchronization_health_desc
      , r.endpoint_url
      , r.session_timeout
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

/*
	Demo 2 - Current state of replication
		
		1. Familiarize yourself with the concepts of last sent, last redo annd last redo, send queue and redo queue.
		2. Most "lsn" fields are not LSNs, but are log block IDs padded with zeros. The only realy LSN is last_redone_lsn
*/

:CONNECT  SQL-A\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , rs.last_sent_time				--time of last send log block.
      , rs.last_received_time			--time of last received log block
      , rs.last_hardened_time			--time of last harded log block
      , rs.last_redone_time				--time of last redone log record
      , rs.last_commit_lsn				--on primary, last committed LSN in the log. On secondary, last committed record redone. An actual LSN
      , rs.last_commit_time
      , rs.log_send_queue_size			--amount of log records in KB not send to secondaries
      , rs.log_send_rate				--send rate in KB
      , rs.redo_queue_size				--amount of log recods in KB not redone on a secondary
      , rs.redo_rate					--redo rate in KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

:CONNECT  SQL-B\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , rs.last_sent_time				--time of last send log block.
      , rs.last_received_time			--time of last received log block
      , rs.last_hardened_time			--time of last harded log block
      , rs.last_redone_time				--time of last redone log record
      , rs.last_commit_lsn				--on primary, last committed LSN in the log. On secondary, last committed record redone. An actual LSN
      , rs.last_commit_time
      , rs.log_send_queue_size			--amount of log records in KB not send to secondaries
      , rs.log_send_rate				--send rate in KB
      , rs.redo_queue_size				--amount of log recods in KB not redone on a secondary
      , rs.redo_rate					--redo rate in KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

:CONNECT  SQL-C\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , rs.last_sent_time				--time of last send log block.
      , rs.last_received_time			--time of last received log block
      , rs.last_hardened_time			--time of last harded log block
      , rs.last_redone_time				--time of last redone log record
      , rs.last_commit_lsn				--on primary, last committed LSN in the log. On secondary, last committed record redone. An actual LSN
      , rs.last_commit_time
      , rs.log_send_queue_size			--amount of log records in KB not send to secondaries
      , rs.log_send_rate				--send rate in KB
      , rs.redo_queue_size				--amount of log recods in KB not redone on a secondary
      , rs.redo_rate					--redo rate in KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

:CONNECT SQL-A\SQL17
INSERT INTO TestAG1.dbo.T1 SELECT NEWID(), REPLICATE('a',7984)
GO

/*
	Setup - start a workload

	Demo 3 - Examine send queue and redo queue
		1. start 1 user workload, examine log_send_rate, redo_rate
		2. start 25 user workload , examine log_send_rate, log_redo_rate and also redo_queue_size. Look for a saturated redo queue
		
		Demos use perfmon counters rather than sys.dm_hadr_database_replica_states for log_send_rate and log_redo_rate. The perfmon counters report 
		incorrect values, I confirmed this by comparing the log_send_rate with actual network bandwidth consumption. The perfmon counters match the
		network usage for log_send_rate. Also confirmed the queue sizes in the DMV are accurate by submitting a fixed quantity of data change to the database 
		engine then measuring the queue sizes. 
		
		To sample the perfmon counters, we take a sample of send/redo wait a second take another sample and take the difference. That value is the
		the correct value of log_send_rate and log_redo_rate. 

		More information on perfmon values
		The calculated log_send_rate is decompressed, I used this in our calculations because send/redo queue sizes are decompressed.

		On the primary
		Use Log Bytes/flushed per second - actual log generation from primary database.
		Use MSSQL$SQL17:Database Replica - Log Bytes Compressed/Sec for how much log is being compressed. This is per replica. 
		Use MSSQL$SQL17:Availability Replica - Bytes Send to Replica/sec for actual compressed send rates. A counter for each replica.
		Use Network Adapter:Interface Name - Bytes Sent/Sec to see what's being transmitted on the network

		On the secondary
		Use MSSQL$SQL17:Database Replica - Log Bytes Deompressed/Sec for how much log is being decompressed on this replica. 
		Use MSSQL$SQL17:Database Replica - Log Bytes Received/sec (log send rate) for actual decompressed send rates 
		Use 'MSSQL$SQL17:Database Replica - Redone Bytes/sec (log redo rate)
		Use Network Adapter:Interface Name - Bytes Received/Sec to see what's coming off the network


*/

:CONNECT SQL-A\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters	
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

:CONNECT SQL-B\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

:CONNECT SQL-C\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

/*
	Demo 4 - Data building in queues due to a WAN outage.


	Setup -	Offline SQL-C while workload running....
			Start 25 user workload, after 30 seconds...

		1. On first query, Check out the state of SQL-C.

		2. On second query, but do not query SQL-C...it's offline. 	
			Look at send queue on primary....NULL! Ugh!!!  Why? Because the secondar is the one that reports the status!
			Check out the redo queue on SQL-B, should see a small amount of queuing

		Online SQL-C after workload completes
		1. Rerun queries, when SQL-C goes to synchronizing, send_queue will be reported. redo_queue will be updates.
		2. SecsBehindPrimary should go to 0
*/
:CONNECT  SQL-A\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , r.availability_mode_desc
      , r.failover_mode_desc
	  , rs.is_commit_participant			--value is only valid on primary replica
      , rs.synchronization_state_desc		--in synchronous mode - look for synchronized, async should be synchronizing
      , rs.synchronization_health_desc		--in synchronous mode - healthy when synchronized, partially when synchronizing, not healthy when not sync'ing. in asynchnous mode - healthy when synchronizing, not healthy when not sync'ing
      , r.endpoint_url
      , r.session_timeout
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO


:CONNECT SQL-A\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

:CONNECT SQL-B\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

/*
	When a secondary is offline, send queue changes to NULL. This query can show you how long since your last committed transaction on a secondary.
*/	
:CONNECT SQL-A\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , ISNULL(DATEDIFF(SECOND, rs.last_commit_time, prs.last_commit_time), 0) AS [SecsBehindPrimary]
      , prs.last_commit_time AS [Primary_last_commit_time]
      , rs.last_commit_time AS [Secondary_last_commit_time]
      , rs.last_redone_time AS [Secondary_last_redone_time]
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
        JOIN sys.dm_hadr_database_replica_states prs ON r.group_id = prs.group_id
                                                        AND prs.group_database_id = rs.group_database_id
                                                        AND rs.is_local = 0
                                                        AND prs.is_primary_replica = 1
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name;

GO
/*
	Send queue to redo queue surge
	1. Bring WAN back online
	2. Query queues and watch the surge of traffic

	Replication delay due to poor network performance
	3. Add 1000ms of network delay on the router
	4. Start workload
	5. Query queues for sizes. Data should queue in the send queue
*/

:CONNECT  SQL-A\SQL17
SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
      , rs.is_local
      , rs.is_primary_replica
      , r.availability_mode_desc
      , r.failover_mode_desc
	  , rs.is_commit_participant			--value is only valid on primary replica
      , rs.synchronization_state_desc		--in synchronous mode - look for synchronized, async should be synchronizing
      , rs.synchronization_health_desc		--in synchronous mode - healthy when synchronized, partially when synchronizing, not healthy when not sync'ing. in asynchnous mode - healthy when synchronizing, not healthy when not sync'ing
      , r.endpoint_url
      , r.session_timeout
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
ORDER BY r.replica_server_name;
GO

:CONNECT SQL-A\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

:CONNECT SQL-B\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO

:CONNECT SQL-C\SQL17
DECLARE @log_flushes1 bigint, @log_flushes2 bigint, @log_flushes bigint, @redo1 bigint, @redo2 bigint, @redo_rate float, @send1 bigint, @send2 bigint, @send_rate float

SET @log_flushes1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo1 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send1 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

WAITFOR DELAY '00:00:01'

SET @log_flushes2 = (SELECT cntr_value FROM sys.dm_os_performance_counters
				WHERE [object_name] = 'MSSQL$SQL17:Databases' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Flushed/sec')

SET @redo2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec')

SET @send2 = (SELECT cntr_value FROM sys.dm_os_performance_counters 
				WHERE [object_name] = 'MSSQL$SQL17:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec')

SET @log_flushes = (SELECT @log_flushes2 - @log_flushes1)
SET @redo_rate = (SELECT @redo2 - @redo1)
SET @send_rate = (SELECT @send2 - @send1)

SELECT  r.replica_server_name
      , DB_NAME(rs.database_id) AS [DatabaseName]
	  , rs.is_primary_replica
	  , CASE WHEN rs.is_primary_replica = 1 THEN (CONVERT(DECIMAL(10,2), @log_flushes / 1024.0)) ELSE null END  [Log KB/sec]
      , rs.log_send_queue_size
      , rs.log_send_rate [log_send_rate - dmv]
	  , @send_rate / 1024.0 [log_send_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN @send_rate = 0 THEN 1 ELSE @send_rate / 1024.0 END)) END [send_latency - sec] --Limit to two decimals, queue is KB, convert @send_rate to KB
      , rs.redo_queue_size
      , rs.redo_rate [redo_rate - dmv]
	  , @redo_rate / 1024.0 [redo_rate KB - perfmon]
	  , CASE WHEN rs.is_local != 1 THEN NULL ELSE (CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN @redo_rate = 0 THEN 1 ELSE @redo_rate / 1024.0 END)) END [redo_latency - sec] --Limit to two decimals, queue is KB, convert @redo_rate to KB
FROM    sys.dm_hadr_database_replica_states rs
        JOIN sys.availability_replicas r ON r.group_id = rs.group_id
                                            AND r.replica_id = rs.replica_id
WHERE   DB_NAME(rs.database_id) = 'TestAG1'
ORDER BY r.replica_server_name 
GO
--stop workload
--take a backup
BACKUP LOG [TestAG1] TO DISK = 'NUL' with init, compression
GO
--checkout what's log_reuse_wait_desc, if we time it right, it should be AVAILABILITY_REPLICA
SELECT name, log_reuse_wait_desc from sys.databases WHERE name = 'TestAG1'
