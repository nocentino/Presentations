#!/bin/bash

############################################################################################################
# 7. Complete Cleanup
#    This script stops Ollama instances, cleans up SQL objects, and stops Docker containers
############################################################################################################

############################################################################################################
# Stop all Ollama instances
############################################################################################################

echo "Stopping all Ollama server processes..."
pkill -f "ollama serve"
sleep 2
echo "Ollama instances stopped"

############################################################################################################
# Cleanup SQL objects
############################################################################################################

docker exec -it sql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'S0methingS@Str0ng!' -C -d StackOverflow_Embeddings_Small -Q "
    -- Drop external models
    IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = 'ollama_lb')
        DROP EXTERNAL MODEL ollama_lb;
    
    IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = 'ollama_single')
        DROP EXTERNAL MODEL ollama_single;   
    
    -- Disable change tracking on Posts table
    IF EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID('dbo.Posts'))
        ALTER TABLE dbo.Posts DISABLE CHANGE_TRACKING;
    
    -- Disable change tracking on database
    ALTER DATABASE StackOverflow_Embeddings_Small SET CHANGE_TRACKING = OFF;
    
    -- Drop sync log table
    IF OBJECT_ID('dbo.PostEmbeddingsSyncLog', 'U') IS NOT NULL
        DROP TABLE dbo.PostEmbeddingsSyncLog;
    
    -- Drop embeddings table
    IF OBJECT_ID('dbo.PostEmbeddings', 'U') IS NOT NULL
        DROP TABLE dbo.PostEmbeddings;
    
    -- Remove file and filegroup if they exist (must be empty first)
        IF EXISTS (SELECT 1 FROM sys.database_files WHERE name = 'StackOverflowEmbeddings')
        BEGIN
            ALTER DATABASE StackOverflow_Embeddings_Small REMOVE FILE StackOverflowEmbeddings;
        END

        IF EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'EmbeddingsFileGroup')
        BEGIN
            ALTER DATABASE StackOverflow_Embeddings_Small REMOVE FILEGROUP EmbeddingsFileGroup;
        END

    PRINT 'SQL cleanup complete';
"


############################################################################################################
# Restore original post data
############################################################################################################

echo ""
echo "Restoring original post data..."

docker exec -it sql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'S0methingS@Str0ng!' -C -d StackOverflow_Embeddings_Small -Q "
    UPDATE dbo.Posts
    SET 
        Body = '<p>I want to assign the decimal variable &quot;trans&quot; to the double variable &quot;this.Opacity&quot;.</p>
<pre class=\"lang-cs prettyprint-override\"><code>decimal trans = trackBar1.Value / 5000;
this.Opacity = trans;
</code></pre>
<p>When I build the app it gives the following error:</p>
<blockquote>
<p>Cannot implicitly convert type decimal to double</p>
</blockquote>
>',
        Title = 'Help assigning decimal variables to doubles'
    WHERE 
        Id = 4;
"

echo "Original post data restored"


############################################################################################################
# Stop Docker containers
############################################################################################################

echo "Stopping Docker containers..."
docker compose down
