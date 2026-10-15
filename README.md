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

When cloning this repository, **the initial clone may appear frozen for a few minutes**. This is normal—`server.zip` is a large file (234 MB) and is tracked with Git LFS. Please be patient and let the clone finish.

```powershell
git clone https://github.com/TejasNair9977/MoodleNGO.git
cd MoodleNGO
```

## Recommended restore process

### 1. Prepare the local server folder

Make sure your local server folder exists. In most setups it looks like this:

- `C:\Users\tejas\moodle-dev\server`

If the folder already contains an old `moodle` or `moodledata` folder, delete it before restoring the new data.

**Important:** The restore script requires the Moodle site to have been initialized at least once. If you're restoring to a fresh installation, run the Moodle setup wizard first, then run this script.


The initialization above must be completed, where the server binaries are installed, after which you must also add placeholder values for necessary fields for the initialization, after which you will be able to continue with the restore.

At the above image, it's safe to proceed.

### 2. Stop Moodle

**Important:** Before running the restore script, you must stop the Moodle server.

If Moodle is currently running, click the **Stop Moodle.exe** application in your Moodle installation folder to shut it down.

### 3. Run the restore script

Make sure you replace the directories at the top of the PowerShell script to the appropriate directories.

LocalRoot is where your moodle install is located.
BackupRoot is where your git repo is located.

Run this from the repository folder in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\restore-moodle-backup.ps1
```

The script asks for confirmation before replacing local Moodle data. It removes existing Moodle folders without making backups, extracts `server.zip`, writes `config.php` including Moodle's required settings, creates the database and imports the SQL, purges caches and prompts you to verify the restored site.



### 4. Verify the restore

When the script opens the site and asks you to verify it, login with the below credentials and then click the **Home** button in the top-left and check that the plugins are installed before typing DONE.

After this, change nothing and click save changes.

After typing `DONE` and letting the script finish, manually change the theme to **Degrade** and set its color to **green1**.

To set theme:

Site Administration > Appearance > Themes 

To set color:

Site Administration > Appearance > Custom theme settings > Degrade - Advanced settings 


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


## Restore troubleshooting and manual recovery notes

If the automated restore script fails, especially during extraction, follow these steps manually.

### 1. Confirm the backup contents

Check that the backup folder contains the files you need:

- `moodle/` or `server.zip`
- `moodledata/` or `moodledat.zip`
- `moodle.sql`

Example:

```powershell
Get-ChildItem -LiteralPath "C:\path\to\backup" -Force | Format-Table Name,Length
```

### 2. Extract the server archive manually

If extraction fails, use 7-Zip first. 7-Zip is the most reliable tool for Windows archives:

```powershell
"C:\Program Files\7-Zip\7z.exe" t "C:\path\to\backup\server.zip"
"C:\Program Files\7-Zip\7z.exe" x -y "-oC:\temp\a\server" "C:\path\to\backup\server.zip"
```

If 7-Zip is not installed, use PowerShell:

```powershell
Expand-Archive -LiteralPath "C:\path\to\backup\server.zip" -DestinationPath "C:\temp\a\server" -Force
```

If `Expand-Archive` fails, try the .NET fallback:

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory('C:\path\to\backup\server.zip','C:\temp\a\server')
```

If you still hit long-path errors, extract to a shorter path such as `C:\moodle-restore`.

### 3. Restore the database manually

If the script fails while importing SQL, run the import manually in `cmd.exe`:

```cmd
"C:\path\to\mysql.exe" -h localhost -u root -p -e "DROP DATABASE IF EXISTS moodle; CREATE DATABASE moodle;"
"C:\path\to\mysql.exe" -h localhost -u root -p moodle < "C:\path\to\backup\moodle.sql"
```

Then remove the stale site identifier:

```cmd
"C:\path\to\mysql.exe" -h localhost -u root -p -e "DELETE FROM moodle.mdl_config WHERE name = 'siteidentifier';"
```

### 4. Create the config.php manually

If the script does not write the config file correctly, create it by hand:

```php
<?php
unset($CFG); global $CFG; $CFG = new stdClass();
$CFG->dbtype = 'mariadb'; $CFG->dblibrary = 'native'; $CFG->dbhost = 'localhost'; $CFG->dbname = 'moodle'; $CFG->dbuser = 'root'; $CFG->dbpass = 'secret'; $CFG->prefix = 'mdl_';
$CFG->dboptions = array('dbpersist'=>0,'dbport'=>'','dbsocket'=>'','dbcollation'=>'utf8mb4_unicode_ci');
$CFG->wwwroot = 'http://localhost'; $CFG->dataroot = 'C:\temp\a\server\moodledata'; $CFG->admin = 'admin'; $CFG->directorypermissions = 0777;
require_once(__DIR__ . '/lib/setup.php');
```

### 5. Purge caches and verify

Run the cache purge explicitly:

```powershell
"C:\path\to\php.exe" "C:\temp\a\server\moodle\admin\cli\purge_caches.php"
```

Then open the site in a browser and verify the installation manually.

### 6. If the script still fails

- Extract to a shorter path.
- Ensure 7-Zip is installed or available in PATH.
- Confirm `mysql.exe` and `php.exe` are accessible.
- Check that the backup folder is not locked or being scanned by antivirus.
- Re-run the import from `cmd.exe` rather than PowerShell if the PowerShell pipeline is causing issues.

This section is intended as a manual fallback when the automated restore script does not complete successfully on Windows 10.
