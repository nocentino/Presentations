taskkill /IM SQLCMD.EXE  /F
sqlcmd -S. -i.\LoadScripts\AGLoadCleanup.sql
pause
