@echo off
for /F "usebackq tokens=1,3 delims=;	 " %%i in (
	`wmic process call create "cmd /k cd \Users\Games\Documents\GitHub\coffee-ide && run %1 %2 %3"^, .`
) do (
	if /I %%i==ProcessId set serverpid=%%j
)
echo server started with pid: %serverpid%