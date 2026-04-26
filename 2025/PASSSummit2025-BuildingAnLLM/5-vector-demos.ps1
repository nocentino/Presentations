#!/usr/bin/pwsh
############################################################################################################
# 5. Semantic Search from PowerShell
#    Using Ollama embeddings with a SQL Server database for semantic search
############################################################################################################
Import-Module dbatools

# Configure the SQL Server connection
$adminSqlLogin = "sa"
$password = "S0methingS@Str0ng!"
$databaseName = "StackOverflow_Embeddings_Small"
$SqlCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminSqlLogin, (ConvertTo-SecureString -String $password -AsPlainText -Force)


# Import dbatools module and connect to the SQL instance
# TrustServerCertificate is used to bypass certificate validation for local testing
$SqlInstance = Connect-DbaInstance -SqlInstance localhost -SqlCredential $SqlCredential -TrustServerCertificate
$SqlInstance

############################################################################################################
# Verify Database and Table Structure
############################################################################################################

# Verify the database connection and confirm the database exists
Get-DbaDatabase -SqlInstance $SqlInstance -Database $databaseName


# Check the PostEmbeddings table structure to confirm it's ready for queries
Get-DbaDbTable -SqlInstance $SqlInstance -Database $databaseName -Table "PostEmbeddings"

############################################################################################################
# Generate Search Embedding
############################################################################################################

# Define the search text for semantic similarity search
#$SearchText = 'Find me posts about SQL Server performance."
$SearchText = 'Ayo, bring me them joints droppin'’ science on that SQL Server performance, aight?'

# Create the request body for Ollama's embedding API
$body = @{
    model = "nomic-embed-text"
    input = $SearchText
} | ConvertTo-Json -Depth 10 -Compress


# Call Ollama to generate a vector embedding for the search text
# This connects to the local Ollama instance running on port 11434
$response = Invoke-RestMethod -Uri "http://localhost:11434/api/embed" -Method Post -ContentType "application/json" -Body $body


# Output the embedding response, we have the model, embedding, duration and prompt eval count
$response


# Extract and store the embedding as a JSON string for use in SQL query
$searchEmbedding = ($response.embeddings | ConvertTo-Json -Depth 10 -Compress)
$searchEmbedding

############################################################################################################
# Perform Semantic Search Using Vector Distance
############################################################################################################

# Query the database for similar embeddings using cosine distance
# The VECTOR_DISTANCE function calculates similarity between the search vector and stored embeddings
# Lower distance values indicate higher similarity
$query = @"
    DECLARE @search_vector VECTOR(768) = '$searchEmbedding';

    SELECT TOP(10)
        pe.PostID,
        vector_distance('cosine', @search_vector, pe.Embedding) AS distance,
        p.Title,
        p.Body
    FROM [dbo].[PostEmbeddings] pe
    JOIN [dbo].[Posts] p ON pe.PostID = p.Id
    ORDER BY distance ASC;
"@


# Output the query string
$query


# Execute the query and return the top 10 most similar posts
Invoke-DbaQuery -SqlInstance $SqlInstance -Query $query -Database $databaseName


############################################################################################################
# Notes:
# - The nomic-embed-text model generates 768-dimensional embeddings
# - Cosine distance is used for similarity: 0 = identical, 2 = opposite
# - Results are ordered by distance (ascending) to show most similar posts first
############################################################################################################


