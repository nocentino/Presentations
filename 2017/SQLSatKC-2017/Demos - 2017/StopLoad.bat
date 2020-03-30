taskkill /IM SQLCMD.EXE  /F
sqlcmd -S.\SQL17 -i.\LoadScripts\AGLoadCleanup.sql
pause
