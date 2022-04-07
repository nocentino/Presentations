CREATE DATABASE TestDB1
ON PRIMARY 
    (NAME = test_db1,  
    FILENAME = '/var/opt/mssql/data/TestDB1.mdf',  
    SIZE = 20GB,
    FILEGROWTH = 1GB)
LOG ON   
   (NAME = test_log1,  
    FILENAME = '/var/opt/mssql/data/TestDB1.ldf',  
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
while ( @i < 536870 ) --approximately 4GB of data of 8K pages
BEGIN
	INSERT INTO  t1
	VALUES ('a')
	SET @i = @i + 1
END
GO
CHECKPOINT
GO
