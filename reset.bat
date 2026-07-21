@echo off
TITLE Resetting MoodleNGO Environment...
echo ========================================================
echo WARNING: This will wipe the database volume and re-import!
echo ========================================================
choice /C YN /M "Are you sure you want to completely reset and re-import the backup"
if errorlevel 2 goto cancel

echo.
echo Stopping containers and deleting old volumes...
docker compose -f docker-compose-with-backup.yml down -v

echo.
echo Spinning up fresh stack and re-importing SQL dump...
docker compose -f docker-compose-with-backup.yml up -d

echo.
echo Reset complete! Access your site at: http://localhost:8080
goto end

:cancel
echo Reset aborted.

:end
pause