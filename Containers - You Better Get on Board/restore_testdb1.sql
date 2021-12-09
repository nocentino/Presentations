USE [master]
RESTORE DATABASE [TestDB1] 
FROM  DISK = N'/var/opt/mssql/data/TestDB1.bak' 
WITH REPLACE