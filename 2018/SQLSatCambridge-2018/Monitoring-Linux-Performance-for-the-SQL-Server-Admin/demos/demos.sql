/*
	Anthony E. Nocentino
	aen@centinosystems.com
	www.centinosystems.com
*/

--Warm up buffer pool
USE TestDB1
SELECT COUNT_BIG(*) FROM t1

--total system memory as exposed by SQLPAL, by default it's 80% of physical
--https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-memory-transact-sql
--https://msdn.microsoft.com/en-us/library/aa366541.aspx
SELECT (total_physical_memory_kb/1024) [Total Physial Memory MB] 
FROM sys.dm_os_sys_memory

--Query the current cache sizes
SELECT TOP 5 [type] [ClerkType], ( ( pages_kb + virtual_memory_committed_kb + shared_memory_committed_kb + awe_allocated_kb ) / 1024) [Pages_MB], *
FROM sys.dm_os_memory_clerks
ORDER BY [Pages_MB] DESC

--Query the buffer pool for size dedicated to this database
SELECT database_id AS DatabaseID, DB_NAME(database_id) AS DatabaseName, COUNT(file_id) * 8/1024 AS BPool_MB
FROM sys.dm_os_buffer_descriptors
GROUP BY DB_NAME(database_id),database_id
ORDER BY BPool_MB DESC 
GO

--When under external pressure with a low mem signal, cache stores and buffer pool "should" shrink and recalc target mem, but....
--From: Amit Banerjee/Sudarshan Narasimhan @ https://blogs.msdn.microsoft.com/sqlserverfaq/2010/08/25/the-hidden-gems-among-dmvs-sys-dm_os_sys_memory/
SELECT
dateadd (ms, (rbf.[timestamp] - tme.ms_ticks), GETDATE()) as [Notification_Time],
cast(record as xml).value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') AS [Notification_type],
cast(record as xml).value('(//Record/MemoryRecord/MemoryUtilization)[1]', 'bigint') AS [MemoryUtilization %],
cast(record as xml).value('(//Record/MemoryNode/@id)[1]', 'bigint') AS [Node Id],
cast(record as xml).value('(//Record/ResourceMonitor/IndicatorsProcess)[1]', 'int') AS [Process_Indicator],
cast(record as xml).value('(//Record/ResourceMonitor/IndicatorsSystem)[1]', 'int') AS [System_Indicator],
cast(record as xml).value('(//Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS [SQL_ReservedMemory_KB],
cast(record as xml).value('(//Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS [SQL_CommittedMemory_KB],
cast(record as xml).value('(//Record/MemoryNode/AWEMemory)[1]', 'bigint') AS [SQL_AWEMemory],
cast(record as xml).value('(//Record/MemoryNode/SinglePagesMemory)[1]', 'bigint') AS [SinglePagesMemory],
cast(record as xml).value('(//Record/MemoryNode/MultiplePagesMemory)[1]', 'bigint') AS [MultiplePagesMemory],
cast(record as xml).value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS [TotalPhysicalMemory_KB],
cast(record as xml).value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS [AvailablePhysicalMemory_KB],
cast(record as xml).value('(//Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS [TotalPageFile_KB],
cast(record as xml).value('(//Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS [AvailablePageFile_KB],
cast(record as xml).value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS [TotalVirtualAddressSpace_KB],
cast(record as xml).value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS [AvailableVirtualAddressSpace_KB],
cast(record as xml).value('(//Record/@id)[1]', 'bigint') AS [Record Id],
cast(record as xml).value('(//Record/@type)[1]', 'varchar(30)') AS [Type]
FROM sys.dm_os_ring_buffers rbf
cross join sys.dm_os_sys_info tme
where rbf.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR' 
ORDER BY rbf.timestamp DESC

--query disk latency, thanks Jimmy May
SELECT *
FROM sys.dm_os_sys_memory
SELECT [Drive], CASE 
		WHEN num_of_reads = 0 THEN 0 
		ELSE (io_stall_read_ms/num_of_reads) 
	END AS [Read Latency], CASE 
		WHEN io_stall_write_ms = 0 THEN 0 
		ELSE (io_stall_write_ms/num_of_writes) 
	END AS [Write Latency], CASE 
		WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 
		ELSE (io_stall/(num_of_reads + num_of_writes)) 
	END AS [Overall Latency], CASE 
		WHEN num_of_reads = 0 THEN 0 
		ELSE (num_of_bytes_read/num_of_reads) 
	END AS [Avg Bytes/Read], CASE 
		WHEN io_stall_write_ms = 0 THEN 0 
		ELSE (num_of_bytes_written/num_of_writes) 
	END AS [Avg Bytes/Write], CASE 
		WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 
		ELSE ((num_of_bytes_read + num_of_bytes_written)/(num_of_reads + num_of_writes)) 
	END AS [Avg Bytes/Transfer]
FROM (SELECT LEFT(mf.physical_name, 2) AS Drive, SUM(num_of_reads) AS num_of_reads, SUM(io_stall_read_ms) AS io_stall_read_ms, SUM(num_of_writes) AS num_of_writes, SUM(io_stall_write_ms) AS io_stall_write_ms, SUM(num_of_bytes_read) AS num_of_bytes_read, SUM(num_of_bytes_written) AS num_of_bytes_written, SUM(io_stall) AS io_stall
	FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs INNER JOIN sys.master_files AS mf WITH (NOLOCK) ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
	GROUP BY LEFT(mf.physical_name, 2)) AS tab
ORDER BY [Overall Latency]
OPTION
(RECOMPILE);
