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

### 2. Stop Moodle

**Important:** Before running the restore script, you must stop the Moodle server.

If Moodle is currently running, click the **Stop Moodle.exe** application in your Moodle installation folder to shut it down.

### 3. Run the restore script

Run this from the repository folder in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\restore-moodle-backup.ps1
```

The script asks for confirmation before replacing local Moodle data. It backs up existing Moodle folders, extracts `server.zip`, writes `config.php` including Moodle's required `lib/setup.php` bootstrap, starts Moodle services, waits for MySQL, restores `moodle_backup.sql`, resets the site identifier, and purges Moodle caches before opening the site. This order ensures Moodle does not load stale cached data from before the database restore. Afterward, verify the restored site in the browser and type `DONE` in PowerShell. The configured site URL must match the URL and scheme you use in the browser (for example, `http://localhost` versus `https://localhost`). The execution-policy bypass applies only to this PowerShell process.

### 4. Verify the restore

After the script reports completion, open the site and check the homepage, admin area, and sample content.

## Login credentials

After the restore, use these credentials:

- Admin: `admin` / `Qwerty123!`
- User: `user` / `Qwerty123!`

If the credentials were changed later, update this section accordingly.

## Restore script source

The complete current contents of `restore-moodle-backup.ps1` are included below:

```powershell
param(
  [string]$BackupRoot = "C:\Users\tejas\MoodleNGO",
  [string]$LocalRoot = "C:\temp\moo\server",
  [string]$SiteUrl = "https://localhost",
  [string]$DatabaseName = "moodle",
  [string]$DbUser = "root",
  [string]$DbPassword = "",
  [string]$DbHost = "localhost",
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Required path not found: $Path"
  }
}

function Invoke-MySqlCommand {
  param(
    [string]$Executable,
    [string[]]$Arguments
  )

  $output = & $Executable @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "MySQL command failed: $($output -join [Environment]::NewLine)"
  }
  return $output
}

function Wait-ForMoodleSetup {
  param([string]$Url)

  Write-Host 'Waiting 20 seconds before opening the browser...'
  Start-Sleep -Seconds 20

  Write-Host "Opening $Url in your default browser..."
  Start-Process -FilePath $Url

  Write-Host 'Please verify the restored Moodle site in the browser.'
  Write-Host 'When you are done, type DONE and press Enter to finish.'

  while ($true) {
    $response = Read-Host -Prompt 'Type DONE when verification is complete.'
    if ($response -eq 'DONE') {
      Write-Host 'Continuing the restore...'
      return
    }
    Write-Host 'Type DONE when verification is complete.'
  }
}

function Wait-ForMySql {
  param(
    [string]$Executable,
    [string]$HostName,
    [string]$User,
    [string]$Password
  )

  $arguments = @('-h', $HostName, '-u', $User)
  if ($Password) {
    $arguments += @('-p' + $Password)
  }
  $arguments += @('-N', '-e', 'SELECT 1;')

  Write-Host 'Waiting for the local MySQL server...'
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $null = & $Executable @arguments 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host 'MySQL is ready.'
      return
    }
    Start-Sleep -Seconds 2
  }

  throw 'MySQL did not become available within 60 seconds. Check that Moodle services are running.'
}

function Expand-ArchiveToFolder {
  param(
    [string]$ArchivePath,
    [string]$DestinationPath
  )

  if (-not (Test-Path -LiteralPath $ArchivePath)) {
    throw "Archive not found: $ArchivePath"
  }

  if (Test-Path -LiteralPath 'C:\Program Files\7-Zip\7z.exe') {
    Write-Host "Extracting $ArchivePath to $DestinationPath using 7-Zip..."
    & 'C:\Program Files\7-Zip\7z.exe' x -y "-o$DestinationPath" $ArchivePath
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to extract archive: $ArchivePath"
    }
    return
  }

  if (Test-Path -LiteralPath 'C:\Program Files (x86)\7-Zip\7z.exe') {
    Write-Host "Extracting $ArchivePath to $DestinationPath using 7-Zip..."
    & 'C:\Program Files (x86)\7-Zip\7z.exe' x -y "-o$DestinationPath" $ArchivePath
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to extract archive: $ArchivePath"
    }
    return
  }

  Write-Host "Extracting $ArchivePath to $DestinationPath using Expand-Archive..."
  Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
}

$repoCode = Join-Path $BackupRoot 'moodle'
$repoData = Join-Path $BackupRoot 'moodledata'
$repoServerArchive = Join-Path $BackupRoot 'server.zip'
$repoDataArchive = Join-Path $BackupRoot 'moodledata.7z'
$repoSql = Join-Path $BackupRoot 'moodle_backup.sql'
$localCode = Join-Path $LocalRoot 'moodle'
$localData = Join-Path $LocalRoot 'moodledata'
$mysqlBin = Join-Path $LocalRoot 'mysql\bin'
$mysqlExe = Join-Path $mysqlBin 'mysql.exe'
$mysqldumpExe = Join-Path $mysqlBin 'mysqldump.exe'
$phpExe = Join-Path $LocalRoot 'php\php.exe'

if (-not (Test-Path -LiteralPath $repoServerArchive) -and -not (Test-Path -LiteralPath $repoCode)) {
  throw "A Moodle runtime archive or code folder was not found in $BackupRoot. Download server.zip or keep the moodle folder in the backup root."
}

if (-not (Test-Path -LiteralPath $repoServerArchive) -and -not (Test-Path -LiteralPath $repoDataArchive) -and -not (Test-Path -LiteralPath $repoData)) {
  throw "A Moodle data backup was not found in $BackupRoot. Expected server.zip, moodledata.7z, or moodledata/."
}

Test-CommandExists -Path $repoSql
Test-CommandExists -Path $LocalRoot
Test-CommandExists -Path $mysqlBin
Test-CommandExists -Path $mysqlExe
Test-CommandExists -Path $mysqldumpExe
Test-CommandExists -Path $phpExe

if (Test-Path -LiteralPath $localCode) {
  Write-Host "Moodle code already exists at $localCode"
}

Write-Host "Backup root     : $BackupRoot"
Write-Host "Local root      : $LocalRoot"
Write-Host "Moodle code     : $localCode"
Write-Host "Moodle data     : $localData"
Write-Host "Site URL        : $SiteUrl"
Write-Host "Database        : $DatabaseName"

if (-not $Force) {
  $answer = Read-Host "This will overwrite local Moodle data. Type YES to continue"
  if ($answer -ne 'YES') {
    Write-Host 'Restore cancelled.'
    return
  }
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDataFolder = Join-Path $LocalRoot ("moodledata.backup-" + $timestamp)
if (Test-Path -LiteralPath $localData) {
  if (Test-Path -LiteralPath $backupDataFolder) {
    Remove-Item -LiteralPath $backupDataFolder -Recurse -Force
  }
  $backupName = (Split-Path $localData -Leaf) + ".backup-$timestamp"
  Rename-Item -LiteralPath $localData -NewName $backupName
}

if (Test-Path -LiteralPath $localCode) {
  $backupCodeFolder = Join-Path $LocalRoot ("moodle.backup-" + $timestamp)
  if (Test-Path -LiteralPath $backupCodeFolder) {
    Remove-Item -LiteralPath $backupCodeFolder -Recurse -Force
  }
  Rename-Item -LiteralPath $localCode -NewName ((Split-Path $localCode -Leaf) + ".backup-$timestamp")
}

if (-not (Test-Path -LiteralPath $localData)) {
  New-Item -ItemType Directory -Path $localData -Force | Out-Null
}

Write-Host 'Restoring the Moodle runtime bundle before final setup...'
if (Test-Path -LiteralPath $repoServerArchive) {
  Expand-ArchiveToFolder -ArchivePath $repoServerArchive -DestinationPath $LocalRoot
}
elseif (Test-Path -LiteralPath $repoDataArchive) {
  Expand-ArchiveToFolder -ArchivePath $repoDataArchive -DestinationPath $LocalRoot
}
elseif (Test-Path -LiteralPath $repoData) {
  Copy-Item -LiteralPath (Join-Path $repoData '*') -Destination $localData -Recurse -Force
}

if (Test-Path -LiteralPath $repoCode) {
  Copy-Item -LiteralPath $repoCode -Destination $LocalRoot -Recurse -Force
}

$cfgPath = Join-Path $localCode 'config.php'
$cfgContent = @"
<?php
unset(`$CFG);
global `$CFG;
`$CFG = new stdClass();

`$CFG->dbtype    = 'mariadb';
`$CFG->dblibrary = 'native';
`$CFG->dbhost    = '$DbHost';
`$CFG->dbname    = '$DatabaseName';
`$CFG->dbuser    = '$DbUser';
`$CFG->dbpass    = '$DbPassword';
`$CFG->prefix    = 'mdl_';
`$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

`$CFG->wwwroot   = '$SiteUrl';
`$CFG->dataroot  = '$localData';
`$CFG->admin     = 'admin';

`$CFG->directorypermissions = 0777;

require_once(__DIR__ . '/lib/setup.php');
"@

[System.IO.File]::WriteAllText($cfgPath, $cfgContent, [System.Text.UTF8Encoding]::new($false))

$startMoodleExe = Join-Path (Split-Path $LocalRoot -Parent) 'Start Moodle.exe'
if (Test-Path -LiteralPath $startMoodleExe) {
  $startMoodleDir = Split-Path -Parent $startMoodleExe
  Write-Host "Launching Moodle startup application from $startMoodleDir..."
  Start-Process -FilePath $startMoodleExe -WorkingDirectory $startMoodleDir -WindowStyle Normal
}
else {
  Write-Warning "Start Moodle.exe was not found at $startMoodleExe."
}

Wait-ForMySql -Executable $mysqlExe -HostName $DbHost -User $DbUser -Password $DbPassword

$backupSql = Join-Path $LocalRoot ("moodle-backup-before-restore-" + $timestamp + ".sql")
$databaseCheckArgs = @('-h', $DbHost, '-u', $DbUser)
if ($DbPassword) {
  $databaseCheckArgs += @('-p' + $DbPassword)
}
$databaseCheckArgs += @('-N', '-e', "SHOW DATABASES LIKE '$DatabaseName';")
$databaseExistsOutput = & $mysqlExe @databaseCheckArgs 2>$null
if (($LASTEXITCODE -eq 0) -and ($databaseExistsOutput -match [regex]::Escape($DatabaseName))) {
  Write-Host 'Creating a database backup before restore...'
  $dumpArgs = @('-u', $DbUser)
  if ($DbPassword) {
    $dumpArgs += @('-p' + $DbPassword)
  }
  $dumpArgs += @($DatabaseName)
  Write-Host "Running mysqldump against $DatabaseName..."
  $dumpOutput = & $mysqldumpExe @dumpArgs 2>&1
  Write-Host "mysqldump exit code: $LASTEXITCODE"
  if ($LASTEXITCODE -ne 0) {
    throw "Database backup failed. Make sure MySQL is running in XAMPP and that the database '$DatabaseName' exists. Output: $($dumpOutput -join [Environment]::NewLine)"
  }
  Set-Content -LiteralPath $backupSql -Value $dumpOutput -Encoding UTF8
}
else {
  Write-Host "Database '$DatabaseName' does not exist yet; skipping pre-restore backup."
}

Write-Host 'Normalizing SQL dump encoding...'
$normalizedSql = Join-Path $LocalRoot ("moodle-backup-normalized-" + $timestamp + ".sql")
(Get-Content -LiteralPath $repoSql -Raw) | Set-Content -LiteralPath $normalizedSql -Encoding UTF8

Write-Host 'Dropping and recreating the local Moodle database...'
$dropArgs = @('-h', $DbHost, '-u', $DbUser)
if ($DbPassword) {
  $dropArgs += @('-p' + $DbPassword)
}
$dropArgs += @('-e', "DROP DATABASE IF EXISTS $DatabaseName; CREATE DATABASE IF NOT EXISTS $DatabaseName;")
Invoke-MySqlCommand -Executable $mysqlExe -Arguments $dropArgs | Out-Null

Write-Host 'Importing the backup SQL dump...'
$importArgs = @('-h', $DbHost, '-u', $DbUser)
if ($DbPassword) {
  $importArgs += @('-p' + $DbPassword)
}
$importArgs += @($DatabaseName)
Get-Content -LiteralPath $normalizedSql | & $mysqlExe @importArgs
if ($LASTEXITCODE -ne 0) {
  throw "SQL import failed. Verify that the local MySQL server is running and that the user '$DbUser' can connect."
}

Write-Host 'Resetting the site identifier so Moodle generates a fresh one...'
$siteResetArgs = @('-h', $DbHost, '-u', $DbUser)
if ($DbPassword) {
  $siteResetArgs += @('-p' + $DbPassword)
}
$siteResetArgs += @('-e', "DELETE FROM $DatabaseName.mdl_config WHERE name = 'siteidentifier';")
Invoke-MySqlCommand -Executable $mysqlExe -Arguments $siteResetArgs | Out-Null

Write-Host 'Purging Moodle caches after database restore...'
$purgeCachesScript = Join-Path $localCode 'admin\cli\purge_caches.php'
& $phpExe $purgeCachesScript
if ($LASTEXITCODE -ne 0) {
  throw 'Moodle cache purge failed after database restore.'
}

Wait-ForMoodleSetup -Url $SiteUrl

Write-Host 'Restore script completed.'
Write-Host 'Next step: complete any setup or configuration steps necessary for your Moodle installation by going to localhost.'
```

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
