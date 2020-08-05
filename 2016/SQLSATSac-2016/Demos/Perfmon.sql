/*
	Example code for pulling data from perfmon counters and calculating log_send_rate and log_redo_rate. DMVs report
	inaccurate data, where perfmon reports accurate data. Confirmed throughput rates of perfmon when using a network monitor 
	for bandwidth used.
*/

:CONNECT  SQL14-A

DECLARE @redo1 bigint, @redo2 bigint, @redo_rate float

SELECT @redo1 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec'

WAITFOR DELAY '00:00:01'

SELECT @redo2 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec'

SELECT @redo_rate = (@redo2-@redo1) / 1048576.0 --, @redo2-@redo1, @redo1, @redo2

GO

:CONNECT  SQL14-B

DECLARE @counter1 bigint, @counter2 bigint

SELECT @counter1 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec'

WAITFOR DELAY '00:00:01'

SELECT @counter2 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec'

SELECT (@counter2-@counter1) / 1048576.0, @counter2-@counter1, @counter1, @counter2

GO



:CONNECT  SQL14-C

DECLARE @counter1 bigint, @counter2 bigint

SELECT @counter1 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec'

WAITFOR DELAY '00:00:01'

SELECT @counter2 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Redone Bytes/sec'

SELECT (@counter2-@counter1) / 1048576.0 , @counter2-@counter1, @counter1, @counter2

GO



select * from sys.dm_os_performance_counters where [object_name] = 'SQLServer:Availability Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec'

select * from sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec'



DECLARE @send1 bigint, @send2 bigint, @send_rate float

SELECT @send1 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec'

WAITFOR DELAY '00:00:01'

SELECT @send2 = cntr_value FROM sys.dm_os_performance_counters where [object_name] = 'SQLServer:Database Replica' and instance_name = 'TestAG1' and counter_name = 'Log Bytes Received/sec'

SELECT @send_rate = (@send2-@send1) / 1048576.0

GO