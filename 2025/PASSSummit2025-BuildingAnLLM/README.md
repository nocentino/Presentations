# Building an LLM on Your Laptop

This repository demonstrates a complete local LLM workflow using:
- **Ollama** (multiple local instances with load balancing)
- **NGINX** (TLS termination, load balancing, and single-backend routing)
- **SQL Server 2025** (vector embeddings, similarity search, change tracking)

## Key Features Demonstrated

- **Load Balancing:** NGINX distributes embedding requests across 4 Ollama instances for improved throughput
- **Vector Storage:** SQL Server stores 768-dimensional embeddings with dedicated filegroup for performance
- **Semantic Search:** VECTOR_DISTANCE with cosine similarity for finding related content
- **Change Tracking:** Automatic detection of data changes to trigger embedding updates
- **TLS Security:** Self-signed certificates for secure API communication (demo purposes)


## File Structure

```
├── 1-demo.sh               # Basic Ollama installation
├── 2-demo.ps1              # PowerShell API testing
├── 3-demo.sh               # Multi-instance setup
├── 4-vector-demos.sql      # SQL vector setup
├── 5-vector-demos.ps1      # Semantic search demo
├── 6-embedding-updates.sql # Change tracking demo
├── 7-cleanup.sh            # Complete cleanup
├── docker-compose.yml      # Container orchestration
├── config/nginx.conf       # Load balancer configuration
├── certs/                  # TLS certificate generation
└── README.md               # This file
```

## Demo Flow

### 1. Install and Start Single Ollama Instance
**Script:** `1-demo.sh`
- Installs Ollama via Homebrew
- Starts basic Ollama service for initial testing

### 2. Basic API Testing
**Script:** `2-demo.ps1`
- Demonstrates PowerShell API calls using Invoke-RestMethod
- Tests basic chat and embedding endpoints

### 3. Multi-Instance Setup with Infrastructure
**Script:** `3-demo.sh`
- Starts 4 Ollama instances on ports 11434-11437
- Downloads nomic-embed-text model to each instance in parallel
- Builds and starts Docker services:
  - cert-generator: Creates self-signed TLS certificates
  - nginx-lb: Load balancer with TLS termination
  - sql-server: SQL Server 2022/2025 container
- Validates both endpoints:
  - https://localhost:443 (load balanced)
  - https://localhost:444 (single backend)

### 4. SQL Vector Setup and Embedding Generation
**Script:** `4-vector-demos.sql`
- Creates dedicated EmbeddingsFileGroup for performance
- Creates PostEmbeddings table with VECTOR(768) column
- Registers external model endpoints (load balanced and single)
- Generates embeddings for posts using AI_GENERATE_EMBEDDINGS
- Includes performance timing measurements

### 5. Semantic Search from PowerShell
**Script:** `5-vector-demos.ps1`
- Connects to SQL Server using dbatools
- Generates query embedding via Ollama
- Performs similarity search using VECTOR_DISTANCE
- Returns semantically similar posts ranked by cosine distance

### 6. Change Tracking for Live Embedding Updates
**Script:** `6-embedding-updates.sql`
- Enables Change Tracking on database and Posts table
- Demonstrates updating a post and capturing changes
- Shows how to build automated re-embedding workflows
- Includes stored procedure for processing change events

### 7. Complete Cleanup
**Script:** `7-cleanup.sh`
- Stops all Ollama instances
- Removes SQL objects (tables, models, change tracking, filegroup)
- Reverts sample data changes
- Stops Docker containers and networks


## Architecture Overview

```
COMBINED VIEW WITH DOCKER CONTAINERS:

             External Clients
            /                \
           /                  \
          v                    v
┌────────────────────────────────────┐
│         NGINX Container            │
│  ┌─────────┐      ┌─────────┐      │
│  │Port 443 │      │Port 444 │      │
│  └─────────┘      └─────────┘      │
└────────────────────────────────────┘
         |                |
         |                |
    Load Balance      Single Route
         |                |
         |                v
         |          ┌───────┐
         |          │ 11434 │
         |          └───────┘
         |
         v
┌─────────────────────────────────────────────┐
│            Host Machine (Ollama)            │
│                                             │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐    │
│  │ 11434 │ │ 11435 │ │ 11436 │ │ 11437 │    │
│  └───────┘ └───────┘ └───────┘ └───────┘    │
│                                             │
└─────────────────────────────────────────────┘

┌────────────────────────────────────┐
│      SQL Server Container          │
│         (Port 1433)                │
│   Stores vector embeddings         │
└────────────────────────────────────┘
```

**Ports:**
- NGINX 443: Load balanced across Ollama 11434-11437
- NGINX 444: Single backend to Ollama 11434
- SQL Server 1433

## Prerequisites

- Ollama: 
  - Mac via Homebrew - `brew install ollama`
  - Linux - `curl -fsSL https://ollama.com/install.sh | sh` 
  - Windows - https://ollama.com/download/windows
- PowerShell: `brew install powershell` or download from Microsoft
- dbatools PowerShell module: `Install-Module dbatools -Scope CurrentUser`
- Optional: StackOverflow sample database files for full-scale testing


## Security Notes

This is a demonstration setup not intended for production:
- Uses self-signed certificates (hence `curl -k`)
- SA password is hardcoded in scripts
- No authentication on Ollama endpoints
- No rate limiting or request validation

For production deployment, implement proper certificate management, authentication, authorization, and monitoring.
