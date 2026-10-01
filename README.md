# Moodle Site Backup

This repository stores the database dump and the restore scripts for the local Moodle environment. The large server runtime bundle is kept outside Git and is downloaded separately from the link below.

## Prerequisites

Before restoring, ensure you have the following installed:

### 1. Moodle 4.5.x for Windows

Download from: https://download.moodle.org/windows/

Extract it to `C:\Users\[YourUsername]\moodle-dev\` (your choice of folders, you can keep it anywhere, create the folders if needed).

### 2. 7-Zip

Download from: https://www.7-zip.org/download.html

This is required for extracting the `server.zip` backup file efficiently.

## What this backup contains

- `moodle_backup.sql` — the latest MySQL dump for the Moodle database
- `restore-moodle-backup.ps1` — the restore script for rebuilding the local Moodle server
- `server.zip` — the local Moodle application runtime to restore the `moodle/` and `moodledata/` directories

## Cloning this repository

When cloning this repository, **the initial clone may appear frozen for a few minutes**. This is normal—`server.zip` is a large file (234 MB) and is tracked with Git LFS. Please be patient and let it complete.

```powershell
git clone https://github.com/TejasNair9977/MoodleNGO.git
cd MoodleNGO
```

## Recommended restore process

### 1. Prepare the local server folder

Make sure your local server folder exists. In most setups it looks like this:

- `C:\Users\tejas\moodle-dev\server`

If the folder already contains an old `moodle` or `moodledata` folder, delete it before restoring the new data.

### 2. Stop Moodle

**Important:** Before running the restore script, you must stop the Moodle server.

If Moodle is currently running, click the **Stop Moodle.exe** application in your Moodle installation folder to shut it down.

### 3. Run the restore script

Run this from the repository folder in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\restore-moodle-backup.ps1
```

The script asks for confirmation before replacing local Moodle data. It backs up existing Moodle folders, extracts `server.zip`, writes `config.php` including Moodle's required `lib/setup.php` bootstrap, starts the Moodle server, imports the database, and applies branding.

**Important:** The restore script requires the Moodle site to have been initialized at least once. If you're restoring to a fresh installation, run the Moodle setup wizard first, then run this script.

### 4. Verify the restore

After the script reports completion, open the site and check the homepage, admin area, and sample content.

### 5. Restart recommended

After the restore completes, a restart of Moodle is recommended to ensure all services are running cleanly.

## Login credentials

After the restore, use these credentials:

- Admin: `admin` / `Qwerty123!`
- User: `user` / `Qwerty123!`

If the credentials were changed later, update this section accordingly.

## H5P and content deployment

H5P is a simple way to add interactive learning content, such as quizzes, videos, and activities, inside Moodle.

### 1. Put the file in the course library

- Open your course
- Click More > Content bank
- Upload or create the H5P item

### 2. Add the activity to the course

- Turn on Edit mode
- Click Add an activity or resource
- Choose H5P
- Fill in the needed details and save

### 3. Connect the H5P file

- Open the H5P settings
- Select the file you uploaded from the content bank
- Set any grade or score options if needed
- Save it and show it to students

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
