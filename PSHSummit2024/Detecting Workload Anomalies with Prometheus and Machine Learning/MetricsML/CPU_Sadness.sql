--From: https://stackoverflow.com/questions/24810905/trying-to-create-an-sql-query-that-will-max-all-cpus-to-100
SELECT MyInt = CONVERT(BIGINT, o1.object_id) + CONVERT(BIGINT, o2.object_id) + CONVERT(BIGINT, o3.object_id)
INTO #temp
FROM sys.objects o1
JOIN sys.objects o2 ON o1.object_id < o2.object_id
JOIN sys.objects o3 ON o1.object_id < o3.object_id

SELECT SUM(CONVERT(BIGINT, o1.MyInt) + CONVERT(BIGINT, o2.MyInt))
FROM #temp o1
JOIN #temp o2 ON o1.MyInt < o2.MyInt