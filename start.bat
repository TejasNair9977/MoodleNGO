@echo off
TITLE Starting MoodleNGO Docker Environment...
echo ========================================================
echo Starting MoodleNGO Development Stack with Backup...
echo ========================================================

docker compose -f docker-compose-with-backup.yml up -d

echo.
echo Containers are starting up! 
echo Access your site at: http://localhost:8080
echo.
pause