
ssh aen@webinar.nocentino.lab


kinit aen@NOCENTINO.LAB

sudo /opt/mssql/bin/mssql-conf unset network.kerberoskeytabfile 
sudo /opt/mssql/bin/mssql-conf unset network.privilegedadaccount
sudo systemctl restart mssql-server
sudo rm  /var/opt/mssql/secrets/mssql.keytab

adutil user delete --name sqluser --distname CN=sqluser,CN=Users,DC=NOCENTINO,DC=LAB -y

sqlcmd -S localhost -U sa -Q 'DROP LOGIN [NOCENTINO\aen]'
