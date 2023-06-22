USE TestDB1
DECLARE @i BIGINT
SET @i = 0
while ( @i < 100 ) 
BEGIN
	SELECT COUNT(*) FROM t2
	SET @i = @i + 1
END