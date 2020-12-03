FROM ubuntu:18.04

#Create mssql user
RUN useradd -u 10001 mssql

#Install required packages
RUN apt-get update && \
    apt-get install -y apt-transport-https curl gnupg2 
    
#Install MS repositories and packages
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl -sL https://packages.microsoft.com/config/ubuntu/18.04/mssql-server-2019.list > /etc/apt/sources.list.d/mssql-server-2019.list && \
    curl -sL https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/msprod.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-server mssql-tools unixodbc-dev

#Clean
RUN apt-get clean && \
    rm -rf /var/apt/cache/* /tmp/* /var/tmp/* /var/lib/apt/lists

#Create directories for sql server, since this is a non-root container we need to lay this out and set permissions
RUN mkdir -p /var/opt/mssql/ && \
    chown mssql:mssql -R /var/opt/mssql 

#Configure SQL Server
RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true && \
    /opt/mssql/bin/mssql-conf traceflag 3226 on

#Expose SQL Server port
EXPOSE 1433

#switch to mssql user
USER mssql

#Start up sql server
CMD /opt/mssql/bin/sqlservr
