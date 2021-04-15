#!/bin/bash

#Give SQL Server 15 seconds to get started before attempting to restore
sleep 15

for i in {1..60};
do
    echo "Attempting to connect to SQL Server..."
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "SELECT 1 FROM sys.databases" 2>&1 > /dev/null
    if [ $? -eq 0 ]
    then
        echo "SQL Server ready!"
        RESTORE=0
        break
    else
        sleep 1
    fi
done

if [ $RESTORE -eq 0 ]
then
    echo "RESTORING DATABASE"
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -d master -i /scripts/restore_testdb1.sql
fi


#Common questions...
# 0. How can this be extented to restore multiple databases?
# 1. How can this be extended to attach databases rather than restore? 


#Other examples of automation...
# 1. Call to a script to create a databases
# 2. Process a collection of sql scripts to init databases or restore more than one database
# 3. Call to dbatools Restore-DbaDatabase to restore a stack of backups