FROM ubuntu:20.04 

#Create file layout for SQL and set permissions
RUN useradd -M -s /bin/bash -u 10001 -g 0 mssql
RUN mkdir -p -m 770 /var/opt/mssql/security/ca-certificates && chgrp -R 0 /var/opt/mssql/security/ca-certificates

# Installing system utilities
RUN apt-get update && \
    apt-get install -y apt-transport-https curl gnupg2 && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list  > /etc/apt/sources.list.d/msprod.list

# Installing SQL Server drivers and tools
RUN apt-get update && \
    apt-get install -y mssql-server-polybase && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists

RUN /opt/mssql/bin/mssql-conf traceflag 13702 on

# Run SQL Server process as non-root
USER mssql
CMD /opt/mssql/bin/sqlservr