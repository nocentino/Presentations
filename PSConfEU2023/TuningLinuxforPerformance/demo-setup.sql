/*
    Demo Setup
	Anthony E. Nocentino
	aen@centinosystems.com
	www.centinosystems.com

    1. Install SQL Server on Linux on a VM with 4 vCPUs and 12GB of RAM.
    2. Adjust max server memory to 8GB
    3. Create database with script below
    4. Add the T1 table
    5. Populate the table with approximatly 8GB of data
*/
--Configure a smaller memory allocation inside the instance
sp_configure 'show advanced options', 1;  
GO
RECONFIGURE;  
GO
sp_configure 'max server memory', 8192;  
GO
RECONFIGURE;  
GO
SELECT [name],[value],[value_in_use]
FROM sys.configurations 
where name = 'max server memory (MB)'
GO
/*
USE master
GO
DROP DATABASE TestDB1
GO
*/
--Create a database for our workload.
CREATE DATABASE TestDB1
ON PRIMARY 
    (NAME = Arch1,  
    FILENAME = '/data/mssql/TestDB1.mdf',  
    SIZE = 20GB,
    FILEGROWTH = 1GB)
LOG ON   
   (NAME = Archlog1,  
    FILENAME = '/data/mssql/TestDB1_log.ldf',  
    SIZE = 1GB,
    FILEGROWTH = 1GB)
GO
ALTER DATABASE TestDB1 SET RECOVERY SIMPLE
GO
--Create a table to hold our data, a bespoke crafted 8KB page
USE TestDB1
GO
CREATE TABLE [dbo].[t1]
(
	[c1] int IDENTITY(1,1) NOT NULL,
	[c2] char(7982) 
	CONSTRAINT [c1] PRIMARY KEY CLUSTERED 
	(
		[c1] ASC
	)

) ON [PRIMARY]
GO

--be sure to execute the data load with the NOCOUNT ON in one batch...
SET NOCOUNT ON
GO
--load table with data
DECLARE @i BIGINT
SET @i = 0
while ( @i < 2147482 ) --approximately 16GB of data of 8K pages
BEGIN
	INSERT INTO  t1
	VALUES ('a')
	SET @i = @i + 1
END
GO
CHECKPOINT
GO

--Create a smaller table that's just over 4GB in size
SELECT top 536870 * 
INTO t2 
FROM t1