# Moodle Site Backup

This repository stores the database dump and the restore scripts for the local Moodle environment. The large server runtime bundle is kept outside Git and is downloaded separately from the link below.

## What this backup contains

- `moodle_backup.sql` — the latest MySQL dump for the Moodle database
- `restore-moodle-backup.ps1` — the restore script for rebuilding the local Moodle server
- `server.zip` — the local Moodle application runtime to restore the `moodle/` and `moodledata/` directories

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

### 3. Restore the Moodle runtime files

Download the `server.zip` bundle from the link above and extract it into the local server folder.

This should restore the `moodle/` and `moodledata/` folders directly inside the target server directory.

Example:

```powershell
Expand-Archive -LiteralPath "C:\path\to\server.zip" -DestinationPath "C:\Users\tejas\moodle-dev\server" -Force
```

### 4. Start Moodle

Open the Moodle startup application for your local environment and complete the setup wizard if the site asks for it.

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
