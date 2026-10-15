# Moodle Site Backup

This repository stores the database dump and the restore scripts for the local Moodle environment. The large server runtime bundle is kept outside Git and is downloaded separately from the link below.

## Prerequisites

Before restoring, ensure you have the following installed:

### 1. Moodle 4.5.x for Windows

Download from: https://download.moodle.org/windows/

Extract it to `C:\Users\[YourUsername]\moodle-dev\` (your choice of folders, you can keep it anywhere, create the folders if needed).

### 2. 7-Zip

Download from: https://www.7-zip.org/download.html

This is recommended for extracting the `server.zip` backup file reliably. Use the 7‑Zip graphical UI (Right‑click → 7‑Zip → Extract Here / Extract to "folder") if possible — it's the simplest and avoids common path/permission problems. If the UI does not work, use the command line instructions below.

## What this backup contains

- `server.zip` — the local Moodle application runtime archive that contains both `moodle/` (code) and `moodledata/` (site files).
- `moodle.sql` — the SQL dump for the Moodle database (located at the repository root).
- `restore-moodle-backup.ps1` — the original restore script (left unchanged).
- `restore-moodle-backup-windows10.ps1` — an alternative script with Windows 10 compatibility improvements.

## Cloning this repository

When cloning this repository, **the initial clone may appear frozen for a few minutes**. This is normal—`server.zip` is a large file and is tracked with Git LFS. Please be patient and let the clone finish.

```powershell
git clone https://github.com/TejasNair9977/MoodleNGO.git
cd MoodleNGO
```

## Recommended restore process

### 1. Prepare the local server folder

Make sure your local server folder exists. In most setups it looks like this:

- `C:\Users\tejas\moodle-dev\server`

If the folder already contains an old `moodle` or `moodledata` folder, delete or move it before restoring the new data.

**Important:** The restore script requires the Moodle site to have been initialized at least once. If you're restoring to a fresh installation, run the Moodle setup wizard first, then run the script.

### 2. Stop Moodle

**Important:** Before running the restore script, you must stop the Moodle server.

If Moodle is currently running, click the **Stop Moodle.exe** application in your Moodle installation folder to shut it down.

### 3. Run the restore script

Make sure you replace the directories at the top of the PowerShell script to the appropriate directories.

LocalRoot is where your moodle install is located.
BackupRoot is where your git repo is located.

Run this from the repository folder in PowerShell. Prefer the Windows 10 script if you ran into issues previously:

```powershell
# preferred: Windows 10 friendly script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\restore-moodle-backup-windows10.ps1

# or original (unchanged) script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\restore-moodle-backup.ps1
```

The script asks for confirmation before replacing local Moodle data. It removes existing Moodle folders without making backups, extracts `server.zip`, writes `config.php` including Moodle's required settings, creates the database and imports the SQL, purges caches and prompts you to verify the restored site.

### 4. Verify the restore

When the script opens the site and asks you to verify it, login with the admin credentials and check that the plugins are installed before typing DONE.

After this, change nothing and click save changes.

After typing `DONE` and letting the script finish, manually change the theme to **Degrade** and set its color to **green1** if required by the project instructions.

To set theme:

Site Administration > Appearance > Themes 

To set color:

Site Administration > Appearance > Custom theme settings > Degrade - Advanced settings 


### 5. Restart recommended

After the restore completes, a restart of Moodle (and any helper services) is recommended to ensure all services are running cleanly.

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

Use this option to start Moodle with MariaDB and initialize the database from `moodle.sql`:

```powershell
# Extract server.zip into this repository first so moodle/ and moodledata/ exist.
# Use the 7-Zip GUI if possible: Right-click -> 7-Zip -> Extract to "server\" or "Extract Here"
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
# Prefer the 7-Zip GUI; fall back to the command-line if the UI doesn't work.
7z x server.zip -o. -y

docker compose up -d
```

Open Moodle at http://localhost:8080. View logs or stop the services with:

```powershell
docker compose logs -f moodle
docker compose down
```

The default Compose setup uses PostgreSQL and does not automatically import `moodle.sql`. Do not run both Compose files at the same time because they use the same Moodle port.


## Restore troubleshooting and manual recovery notes

If the automated restore script fails, especially during extraction, follow these steps manually. The archive `server.zip` contains both the `moodle/` and `moodledata/` folders, and the SQL dump is available at the repository root as `moodle.sql`.

### 1. Confirm the backup contents (visual check)

Make sure the repository root contains `server.zip` and `moodle.sql`, and that `server.zip` contains both `moodle/` and `moodledata/` when opened with your archive tool.

### 2. Extract the server archive (7-Zip GUI preferred)

Use the 7-Zip graphical interface if possible:

- Right-click `server.zip` → 7-Zip → "Extract Here" or "Extract to server\".

If the GUI extraction fails or isn't available, use the 7-Zip command-line as a fallback:

```powershell
"C:\Program Files\7-Zip\7z.exe" x -y "-oC:\temp\a\server" "C:\path\to\repo\server.zip"
```

Do not rely on other extraction fallbacks; 7‑Zip is the supported method in this guide.

### 3. Restore the database manually (command prompt recommended)

If the script fails while importing SQL, run the import manually in `cmd.exe`:

```cmd
"C:\path\to\mysql.exe" -h localhost -u root -p -e "DROP DATABASE IF EXISTS moodle; CREATE DATABASE moodle;"
"C:\path\to\mysql.exe" -h localhost -u root -p moodle < "C:\path\to\repo\moodle.sql"
```

Then remove the stale site identifier:

```cmd
"C:\path\to\mysql.exe" -h localhost -u root -p -e "DELETE FROM moodle.mdl_config WHERE name = 'siteidentifier';"
```

### 4. Create the config.php manually

If the script does not write the config file correctly, create it by hand at `C:\temp\a\server\moodle\config.php` (adjust paths/credentials):

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

- Ensure you're using the 7‑Zip GUI first, and only use the 7‑Zip command-line if needed.
- Extract to a short path (e.g., `C:\moodle-restore`) to avoid long-path issues.
- Ensure 7‑Zip is installed and accessible at `C:\Program Files\7-Zip\7z.exe` or on PATH.
- Confirm `mysql.exe` and `php.exe` are accessible.
- Check that the backup file is not locked or being scanned by antivirus.

This section is intended as a manual fallback when the automated restore script does not complete successfully on Windows 10.
