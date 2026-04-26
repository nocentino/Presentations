------------------------------------------------------------
-- 6. Change Tracking for Live Embedding Updates
--    Using Change Tracking events to drive AI outcomes
--    This demo showcases SQL Server's Change Tracking feature to efficiently maintain AI embeddings
------------------------------------------------------------

------------------------------------------------------------
-- Step 1: Enable Change Tracking on the database and table
------------------------------------------------------------
/*
    First, enable Change Tracking at the database level with a 2-day retention period.
    Change Tracking provides an efficient mechanism to track data modifications
    with minimal storage overhead for change metadata.
*/
ALTER DATABASE StackOverflow_Embeddings_Small
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
GO

USE StackOverflow_Embeddings_Small;
GO

/*
    Enable Change Tracking on the Posts table with column tracking.
    Column tracking provides detailed information about which specific
    columns were modified in each change.
*/
ALTER TABLE dbo.Posts
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

------------------------------------------------------------
-- Step 2: Retrieve a sample row to modify for demonstration
------------------------------------------------------------
/*
    Select a sample row to modify for our change tracking demonstration.
    This query joins the Posts table with the PostEmbeddings table to show
    the current state before making changes.
*/
SELECT TOP 1 
    p.Id, 
    p.Body, 
    pe.Embedding, 
    pe.CreatedAt, 
    pe.UpdatedAt 
FROM 
    dbo.Posts AS p
INNER JOIN 
    dbo.PostEmbeddings AS pe ON p.Id = pe.PostID
WHERE 
    p.Id = 4;
GO

------------------------------------------------------------
-- Step 3: Update a post to trigger Change Tracking
------------------------------------------------------------
/*
    Update a single post, which will be tracked by Change Tracking.
    This modification will trigger the change tracking system to record
    the change for later processing.
*/
UPDATE dbo.Posts
SET 
    Body = '<p>I want to assign the decimal variable &quot;trans&quot; to the float variable &quot;this.Opacity&quot;.</p>',
    Title = 'Updated Post Title'
WHERE 
    Id = 4;
GO

------------------------------------------------------------
-- Step 4: Create a stored procedure to process changes and update embeddings
------------------------------------------------------------
/*
    This stored procedure uses Change Tracking to identify modified rows,
    then automatically generates new AI embeddings for those changes.
    This enables automatic maintenance of AI embeddings as data changes.
*/
CREATE OR ALTER PROCEDURE dbo.UpdatePostEmbeddings
AS
BEGIN
    SET NOCOUNT ON;

    -- Get the last synchronization version
    DECLARE @LastSyncVersion BIGINT = ISNULL(
        (SELECT MAX(SyncVersion) FROM dbo.PostEmbeddingsSyncLog),
        0
    );

    -- Get the current version
    DECLARE @CurrentVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION();

    /*
        Process newly inserted rows.
        This section identifies new posts and generates embeddings for them.
    */
    INSERT INTO dbo.PostEmbeddings (PostID, Embedding, CreatedAt)
    SELECT 
        p.Id,
        AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama_lb) AS Embedding, -- Generate embeddings
        GETDATE() AS CreatedAt
    FROM 
        CHANGETABLE(CHANGES dbo.Posts, @LastSyncVersion) AS ct
    JOIN 
        dbo.Posts p ON ct.Id = p.Id
    WHERE 
        ct.SYS_CHANGE_OPERATION IN ('I') -- Inserted rows
        AND NOT EXISTS (
            SELECT 1 FROM dbo.PostEmbeddings pe WHERE pe.PostID = p.Id
        );

    /*
        Update embeddings for modified rows.
        This section identifies updated posts and regenerates their embeddings
        to keep the AI data current with the latest changes.
    */
    UPDATE pe
    SET 
        pe.Embedding = AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama_lb), 
        pe.UpdatedAt = GETDATE()
    FROM 
        dbo.PostEmbeddings pe
    JOIN 
        CHANGETABLE(CHANGES dbo.Posts, @LastSyncVersion) AS ct
        ON pe.PostID = ct.Id
    JOIN 
        dbo.Posts p ON ct.Id = p.Id
    WHERE 
        ct.SYS_CHANGE_OPERATION = 'U'; -- Updated rows

    -- Log the synchronization version
    INSERT INTO dbo.PostEmbeddingsSyncLog (SyncVersion, SyncTime)
    VALUES (@CurrentVersion, GETDATE());
END;
GO

------------------------------------------------------------
-- Step 5: Create tracking table for synchronization versions
------------------------------------------------------------
/*
    Create a table to track synchronization versions.
    This table maintains a record of when changes were processed,
    enabling incremental processing of changes.
*/
CREATE TABLE dbo.PostEmbeddingsSyncLog (
    SyncVersion BIGINT PRIMARY KEY,
    SyncTime DATETIME NOT NULL
);
GO

------------------------------------------------------------
-- Step 6: Execute the procedure and verify results
------------------------------------------------------------
/*
    Execute the procedure to process changes and update embeddings.
    This demonstrates how the change tracking system automatically
    maintains AI embeddings as data is modified.
*/
EXEC dbo.UpdatePostEmbeddings;

-- Check the synchronization log
SELECT * FROM dbo.PostEmbeddingsSyncLog

/*
    Verify that the embedding for the modified post has been updated.
    This confirms that the change tracking system successfully detected
    and processed the changes to maintain data consistency.
*/
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings
WHERE PostID = 4;



