#!/bin/bash
############################################################################################################
# 3. Multi-Instance Setup with Infrastructure
#    Running Multiple Ollama Instances with Nginx Load Balancing and SQL Server Integration
#    This script sets up multiple Ollama instances, configures nginx as a load balancer, and integrates
#    with SQL Server 2025 for vector embeddings storage and retrieval.
############################################################################################################

############################################################################################################
# Stop any existing Ollama instances
############################################################################################################

# Kill all running Ollama server processes
pkill -f "ollama serve"

############################################################################################################
# Start multiple Ollama instances on different ports
############################################################################################################

# Start 4 Ollama instances on ports 11434-11437
# Each instance runs independently and can handle requests simultaneously

OLLAMA_HOST=127.0.0.1:11434 ollama serve &
OLLAMA_HOST=127.0.0.1:11435 ollama serve &
OLLAMA_HOST=127.0.0.1:11436 ollama serve &
OLLAMA_HOST=127.0.0.1:11437 ollama serve &

# Wait for all instances to fully start
sleep 10

############################################################################################################
# Starting up four indepentent ollama instances
############################################################################################################
#
#     ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
#     │ Ollama │ │ Ollama │ │ Ollama │ │ Ollama │
#     │ :11434 │ │ :11435 │ │ :11436 │ │ :11437 │
#     └────────┘ └────────┘ └────────┘ └────────┘
#
############################################################################################################
# Pull the nomic-embed-text model on all instances
############################################################################################################

# Download the embedding model on each Ollama instance
# This runs in parallel to speed up the download process
OLLAMA_HOST=127.0.0.1:11434 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11435 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11436 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11437 ollama pull nomic-embed-text &

#     ┌────────┐ ┌────────┐  ┌────────┐ ┌────────┐
#     │ Pull 1 │ │ Pull 2 │  │ Pull 3 │ │ Pull 4 │
#     └────────┘ └────────┘  └────────┘ └────────┘
#         |          |           |          |
#         v          v           v          v
#     ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
#     │ Ollama │ │ Ollama │ │ Ollama │ │ Ollama │
#     │ :11434 │ │ :11435 │ │ :11436 │ │ :11437 │
#     └────────┘ └────────┘ └────────┘ └────────┘
#
############################################################################################################
# Verify models are pulled on all instances
############################################################################################################

# List the pulled model on each instance to confirm successful download
OLLAMA_HOST=127.0.0.1:11434 ollama list nomic-embed-text:latest
OLLAMA_HOST=127.0.0.1:11435 ollama list nomic-embed-text:latest
OLLAMA_HOST=127.0.0.1:11436 ollama list nomic-embed-text:latest
OLLAMA_HOST=127.0.0.1:11437 ollama list nomic-embed-text:latest



############################################################################################################
# Test each Ollama instance and warm up the models
############################################################################################################

# Send test requests to each instance to verify they're running
# This also loads the models into memory for faster subsequent requests
curl -X POST http://localhost:11434/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11434"
  }'

curl -X POST http://localhost:11435/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11435"
  }'

curl -X POST http://localhost:11436/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11436"
  }'

curl -X POST http://localhost:11437/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11437"
  }'


############################################################################################################
# Review configuration files
############################################################################################################

# Examine the docker-compose.yml file to see our nginx load balancer and SQL Server 2025 setup
code docker-compose.yml


# Examine the nginx.conf file to see how the load balancing is configured
code ./config/nginx.conf


############################################################################################################
# Start Docker services (nginx and SQL Server)
############################################################################################################

# Start nginx load balancer and SQL Server 2025 in detached mode
docker compose up -d

echo "Started 4 ollama instances, nginx load balancer, and SQL Server 2025"

############################################################################################################
# SINGLE BACKEND ARCHITECTURE (Port 444):
############################################################################################################
#
#          Client Request
#                |
#                v
#         ┌──────────────┐
#         │   NGINX:444  │
#         └──────────────┘
#                |
#                |
#                |
#                v
#         ┌──────────────┐
#         │ Ollama:11434 │
#         └──────────────┘
#
#
############################################################################################################
# LOAD BALANCED ARCHITECTURE (Port 443):
############################################################################################################
#
#             Client Request
#                  |
#                  v
#           ┌─────────────┐
#           │  NGINX:443  │
#           └─────────────┘
#                  |
#            (round-robin)
#                  |
#     ┌────────┬───┴──────┬────────┐
#     |        |          |        |
#     v        v          v        v
# ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
# │Ollama │ │Ollama │ │Ollama │ │Ollama │
# │ 11434 │ │ 11435 │ │ 11436 │ │ 11437 │
# └───────┘ └───────┘ └───────┘ └───────┘
#
############################################################################################################
# COMBINED VIEW WITH DOCKER CONTAINERS:
############################################################################################################
#
#     ┌────────────────────────────────────┐
#     │      SQL Server Container          │
#     │         (Port 1433)                │
#     │   Stores vector embeddings         │
#     └────────────────────────────────────┘
#              /                \
#             /                  \
#            v                    v
#     ┌────────────────────────────────────┐
#     │         NGINX Container            │
#     │  ┌─────────┐      ┌─────────┐      │
#     │  │Port 444 │      │Port 443 │      │
#     │  └─────────┘      └─────────┘      │
#     └────────────────────────────────────┘
#             |                |
#             |                |
#        Single Route     Load Balancer 
#             |                |
#             |                |
#             |                v
#     ┌─────────────────────────────────────────────┐
#     │       |    Host Machine (Ollama)            │
#     │       v                                     │
#     │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐    │
#     │  │ 11434 │ │ 11435 │ │ 11436 │ │ 11437 │    │
#     │  └───────┘ └───────┘ └───────┘ └───────┘    │
#     └─────────────────────────────────────────────┘
#

############################################################################################################

############################################################################################################
# Test the nginx load balancer
############################################################################################################

# Test the load balancer on port 443
# This should distribute requests across all 4 Ollama instances using round-robin
curl -k -X POST https://localhost:443/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 443"
  }'


# Test the single backend on port 444
# This should route to only one specific Ollama instance
curl -k -X POST https://localhost:444/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 444"
  }'


############################################################################################################
# Download and prepare StackOverflow database
############################################################################################################

# Download StackOverflow2013 database from:
# https://www.brentozar.com/archive/2015/10/how-to-download-the-stack-overflow-database-via-bittorrent/
# Using the medium version which is ~50GB


############################################################################################################
# Copy database files to SQL Server container
############################################################################################################

# Copy all database files to the SQL Server container in parallel
docker cp StackOverflow2013_1.mdf   sql-server:/var/opt/mssql/data/ &
docker cp StackOverflow2013_2.ndf   sql-server:/var/opt/mssql/data/ &
docker cp StackOverflow2013_3.ndf   sql-server:/var/opt/mssql/data/ &
docker cp StackOverflow2013_4.ndf   sql-server:/var/opt/mssql/data/ &
docker cp StackOverflow2013_log.ldf sql-server:/var/opt/mssql/data/ &


############################################################################################################
# Set proper file permissions in SQL Server container
############################################################################################################

# Change ownership of database files to the mssql user
# This is required for SQL Server to access the files
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_1.mdf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_2.ndf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_3.ndf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_4.ndf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_log.ldf


############################################################################################################
# Attach the StackOverflow database to SQL Server
############################################################################################################

# Use sqlcmd to attach the database files to SQL Server
# The -C flag is used to trust the server certificate
docker exec -it sql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'S0methingS@Str0ng!' -C -d master -Q \
  "CREATE DATABASE StackOverflow_Embeddings_Small ON \
  (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_1.mdf'), \
  (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_2.ndf'), \
  (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_3.ndf'), \
  (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_4.ndf') \
  LOG ON (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_log.ldf') FOR ATTACH;"

############################################################################################################
# Generate vector embeddings
############################################################################################################

# Open the SQL script to generate vector embeddings for all posts in the StackOverflow database
code 4-vector-demos.sql
