open https://azuremarketplace.microsoft.com/en-us/marketplace/apps/microsoftsqlserver.sql2019-ubuntupro2004?tab=Overview

#Log into our lab linux server
ssh aen@webinar.nocentino.lab


#Make sure we have a Kerberos credentials, if not use kinit aen@NOCENTINO.LAB to get new ones
kinit aen@NOCENTINO.LAB


#Create our SQL Server service account user in Active Directory
adutil user create --name sqluser --distname CN=sqluser,CN=Users,DC=NOCENTINO,DC=LAB --password 'P@ssw0rd' 


#Create the SPN associated with this user, service, host and port
adutil spn addauto -n sqluser -s MSSQLSvc -H webinar.nocentino.lab -p 1433 -y


#Create the keytab file for the service account, this will populate several SPNs for the principals and specified encryption methods used
adutil keytab createauto -k mssql.keytab -p 1433 -H webinar.nocentino.lab --password 'P@ssw0rd' -s MSSQLSvc -e aes256-cts-hmac-sha1-96,aes128-cts-hmac-sha1-96,aes256-cts-hmac-sha384-192,aes128-cts-hmac-sha256-128,des3-cbc-sha1,arcfour-hmac -y


#Creates key entries for the given principal in a keytab. 
adutil keytab create -k mssql.keytab -p sqluser --password 'P@ssw0rd!' -e aes256-cts-hmac-sha1-96,aes128-cts-hmac-sha1-96,aes256-cts-hmac-sha384-192,aes128-cts-hmac-sha256-128,des3-cbc-sha1,arcfour-hmac


#let's move the keytab into a known SQL Server location for secrets and set the permissions properly
sudo mv mssql.keytab   /var/opt/mssql/secrets/ 
sudo chown mssql:mssql /var/opt/mssql/secrets/mssql.keytab 
sudo chmod 440         /var/opt/mssql/secrets/mssql.keytab


#Let's take a peek inside this keytab file
sudo klist -kte /var/opt/mssql/secrets/mssql.keytab


#Now let's configure SQL Server on linux to use the keytab file and set the AD lookup account
sudo /opt/mssql/bin/mssql-conf set network.kerberoskeytabfile /var/opt/mssql/secrets/mssql.keytab
sudo /opt/mssql/bin/mssql-conf set network.privilegedadaccount sqluser


#Restart the SQL Instance to take the change
sudo systemctl restart mssql-server


#Create a SQL Server login using an Active Directory account
sqlcmd -S localhost -U sa -Q 'CREATE LOGIN [NOCENTINO\aen] FROM Windows'


#Open a second terminal session and log in
ssh -l aen@nocentino.lab webinar.nocentino.lab


#Check for our Kerberos credential and its creation date
klist
date


#Log into SQL Server using integrated login
sqlcmd -S webinar.nocentino.lab

SELECT SYSTEM_USER
GO


#Jump back to our other terminal
sqlcmd -S . -U sa -Q 'SELECT  s.host_name, auth_scheme FROM sys.dm_exec_connections AS C JOIN sys.dm_exec_sessions AS S ON C.session_id = S.session_id;'
