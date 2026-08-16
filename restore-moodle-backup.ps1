param(
    [string]$BackupRoot = "C:\Users\tejas\MoodleNGO",
    [string]$LocalRoot = "C:\Users\tejas\moodle-dev\server",
    [string]$SiteUrl = "http://localhost",
    [string]$DatabaseName = "moodle",
    [string]$DbUser = "root",
    [string]$DbPassword = "",
    [string]$DbHost = "127.0.0.1",
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

    Write-Host 'Please finish the Moodle setup in the browser.'
    Write-Host 'When you are done, type DONE and press Enter to continue.'

    while ($true) {
        $response = Read-Host -Prompt 'Type DONE when setup is complete.'
        if ($response -eq 'DONE') {
            Write-Host 'Continuing the restore...'
            return
        }
        Write-Host 'Type DONE when setup is complete.'
    }
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
    Rename-Item -LiteralPath $localCode -NewName (Split-Path $localCode -Leaf) + ".backup-$timestamp"
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

$startMoodleExe = 'C:\Users\tejas\moodle-dev\Start Moodle.exe'
if (Test-Path -LiteralPath $startMoodleExe) {
    $startMoodleDir = Split-Path -Parent $startMoodleExe
    Write-Host "Launching Moodle startup application from $startMoodleDir..."
    Start-Process -FilePath $startMoodleExe -WorkingDirectory $startMoodleDir -WindowStyle Normal
    Wait-ForMoodleSetup -Url $SiteUrl
}
else {
    Write-Warning "Start Moodle.exe was not found at $startMoodleExe."
}

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

$cfgPath = Join-Path $localCode 'config.php'
$cfgContent = @"
<?php
unset(`$CFG);
global `$CFG;
`$CFG = new stdClass();

`$CFG->dbtype    = 'mariadb';
`$CFG->dblibrary = 'native';
`$CFG->dbhost    = '127.0.0.1';
`$CFG->dbname    = '$DatabaseName';
`$CFG->dbuser    = '$DbUser';
`$CFG->dbpass    = '$DbPassword';
`$CFG->prefix    = 'mdl_';
`$CFG->dboptions = [
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '',
    'dbhandlesoptions' => false,
    'dbcollation' => 'utf8mb4_unicode_ci',
];

`$CFG->wwwroot   = '$SiteUrl';
`$CFG->dataroot  = '$localData';
`$CFG->routerconfigured = false;
`$CFG->directorypermissions = 02777;
`$CFG->admin = 'admin';
"@

Set-Content -LiteralPath $cfgPath -Value $cfgContent -Encoding UTF8

Write-Host 'Restore script completed.'
Write-Host 'Next step: complete any setup or configuration steps necessary for your Moodle installation by going to localhost.'
