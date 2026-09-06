# Moodle Site Backup

This repository stores the database dump and the restore scripts for the local Moodle environment. The large server runtime bundle is kept outside Git and is downloaded separately from the link below.

## Prerequisites

Before restoring, ensure you have the following installed:

### 1. Moodle 4.5.x for Windows

Download from: https://download.moodle.org/windows/

Extract it to `C:\Users\[YourUsername]\moodle-dev\server\` (create the folders if needed).

### 2. 7-Zip

Download from: https://www.7-zip.org/download.html

This is required for extracting the `server.zip` backup file efficiently.

## What this backup contains

- `moodle_backup.sql` — the latest MySQL dump for the Moodle database
- `restore-moodle-backup.ps1` — the restore script for rebuilding the local Moodle server
- `server.zip` — the local Moodle application runtime to restore the `moodle/` and `moodledata/` directories

## Cloning this repository

When cloning this repository, **the initial clone may appear frozen for a few minutes**. This is normal—`server.zip` is a large file (234 MB) and is tracked with Git LFS. Please be patient and let the clone complete.

```powershell
git clone https://github.com/TejasNair9977/MoodleNGO.git
cd MoodleNGO
```

## Recommended restore process

### 1. Prepare the local server folder

Make sure your local server folder exists. In most setups it looks like this:

- `C:\Users\tejas\moodle-dev\server`

If the folder already contains an old `moodle` or `moodledata` folder, delete it before restoring the new data.

### 2. Restore the database

Import the SQL dump into the local Moodle database.

Command Prompt:

```cmd
mysql -u root moodle < moodle_backup.sql
```

Then reset the Moodle site identifier so the site is treated as a fresh install:

```sql
DELETE FROM mdl_config WHERE name = 'siteidentifier';
```

### 3. Stop Moodle

**Important:** Before running the restore script, you must stop the Moodle server.

If Moodle is currently running, click the **Stop Moodle.exe** application in your `C:\Users\tejas\moodle-dev\` folder to shut it down.

### 4. Run the restore script

The restore script will:
- Extract `server.zip` automatically
- Generate a fresh `config.php` with the correct paths for your system
- Import the database backup
- Set up everything needed

The script handles all path configuration automatically, so you don't need to manually edit `config.php`.

### 5. Start Moodle

Click the **Start Moodle.exe** application in your `C:\Users\tejas\moodle-dev\` folder to start the Moodle server.

Then open the site in the browser and check the homepage, admin area, and sample content.

## Login credentials

After the restore, use these credentials:

- Admin: `admin` / `Qwerty123!`
- User: `user` / `Qwerty123!`

If the credentials were changed later, update this section accordingly.

## Restore script

The PowerShell restore script is designed to rebuild the local environment using the backup SQL and the extracted runtime folders.

Example usage:

```powershell
powershell -ExecutionPolicy Bypass -File .\restore-moodle-backup.ps1 `
  -BackupRoot "C:\Users\tejas\MoodleNGO" `
  -LocalRoot "C:\Users\tejas\moodle-dev\server" `
  -SiteUrl "http://localhost" `
  -DatabaseName "moodle" `
  -DbUser "root" `
  -DbPassword "" `
  -DbHost "127.0.0.1" `
  -Force
```

What the script does:

- validates required backup and server paths
- creates a backup of the current local Moodle data if it exists
- restores the `moodledata` folder from the backup or archive
- drops and recreates the local MariaDB/MySQL database
- imports the SQL backup
- resets the site identifier so Moodle regenerates it
- writes a fresh `config.php` pointing to the local server and database

## H5P and content deployment

Moodle uses a centralized content bank for interactive resources such as H5P activities.

### 1. Stage the asset

- Open the course
- Go to More > Content bank
- Upload or create the H5P package

### 2. Add the activity

- Turn on Edit mode
- Add an activity or resource
- Choose H5P
- Fill in the required fields and save

### 3. Link the H5P package

- Open the H5P activity settings
- Select the uploaded file from the content bank
- Configure grading options if needed
- Save and display

## Notes

- The large runtime bundle is intentionally kept outside Git because GitHub rejects large files over the 100 MB limit.
- The project is meant to store the restore scripts and SQL backup, while the actual Moodle server runtime is restored from the external archive.
- If you move the project to a new machine, download the `server.zip` file again and extract it into the target server folder before running the restore script.

## Docker setup

Install and start [Docker Desktop](https://www.docker.com/products/docker-desktop/) before using Docker.

### MariaDB setup with the backup

Use this option to start Moodle with MariaDB and initialize the database from `moodle_backup.sql`:

```powershell
# Extract server.zip into this repository first so moodle/ and moodledata/ exist.
7z x server.zip -o. -y

docker compose -f docker-compose-with-backup.yml up -d
```

Open Moodle at http://localhost:8080. Follow the container logs while it starts:

```powershell
docker compose -f docker-compose-with-backup.yml logs -f moodle
```

The SQL file is imported only when the database volume is created for the first time. To completely reset the Docker database and import the backup again:

```powershell
docker compose -f docker-compose-with-backup.yml down -v
docker compose -f docker-compose-with-backup.yml up -d
```

### PostgreSQL setup

Use the default Compose file for a clean PostgreSQL-based Moodle container:

```powershell
# Extract server.zip into this repository first so moodle/ exists.
7z x server.zip -o. -y

docker compose up -d
```

Open Moodle at http://localhost:8080. View logs or stop the services with:

```powershell
docker compose logs -f moodle
docker compose down
```

The default Compose setup uses PostgreSQL and does not automatically import `moodle_backup.sql`. Do not run both Compose files at the same time because they use the same Moodle port.
