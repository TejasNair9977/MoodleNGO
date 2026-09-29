param(
    [string]$BackupRoot = "C:\Users\tejas\MoodleNGO",
    [string]$LocalRoot = "C:\temp\n\server",
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

function Get-BrandingFile {
    param(
        [string]$BrandingRoot,
        [string[]]$PossibleNames
    )

    if (-not (Test-Path -LiteralPath $BrandingRoot)) {
        return $null
    }

    $files = Get-ChildItem -LiteralPath $BrandingRoot -File -ErrorAction SilentlyContinue
    foreach ($possible in $PossibleNames) {
        $match = $files | Where-Object { $_.Name -ieq $possible } | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    foreach ($possible in $PossibleNames) {
        $match = $files | Where-Object { $_.Name -ilike "*$possible*" } | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    return $null
}

function Invoke-BrandingSetup {
    param(
        [string]$BrandingRoot,
        [string]$MoodleRoot,
        [string]$PhpExe
    )

    $searchRoots = @()
    if (Test-Path -LiteralPath $BrandingRoot) {
        $searchRoots += $BrandingRoot
    }

    $backupRoot = Split-Path -Parent $BrandingRoot
    if ($backupRoot -and (Test-Path -LiteralPath $backupRoot) -and ($BrandingRoot -ne $backupRoot)) {
        $searchRoots += $backupRoot
    }

    if ($searchRoots.Count -eq 0) {
        Write-Host "No branding folder found at $BrandingRoot. Skipping branding setup."
        return
    }

    $logo = $null
    $favicon = $null
    $background = $null
    $loginBackground = $null
    $loginLogo = $null

    foreach ($searchRoot in $searchRoots) {
        if (-not $logo) { $logo = Get-BrandingFile -BrandingRoot $searchRoot -PossibleNames @('logo.png', 'logo.jpg', 'logo.jpeg', 'logo.svg', 'site-logo.png', 'site-logo.jpg', 'site-logo.svg') }
        if (-not $favicon) { $favicon = Get-BrandingFile -BrandingRoot $searchRoot -PossibleNames @('favicon.ico', 'favicon.png', 'favicon.svg', 'site-favicon.ico', 'site-favicon.png', 'site-favicon.svg') }
        if (-not $background) { $background = Get-BrandingFile -BrandingRoot $searchRoot -PossibleNames @('background.jpg', 'background.jpeg', 'background.png', 'site-background.jpg', 'site-background.png', 'home-background.jpg') }
        if (-not $loginBackground) { $loginBackground = Get-BrandingFile -BrandingRoot $searchRoot -PossibleNames @('login-background.jpg', 'login-background.jpeg', 'login-background.png', 'login-bg.jpg', 'login-bg.png', 'background-login.jpg') }
        if (-not $loginLogo) { $loginLogo = Get-BrandingFile -BrandingRoot $searchRoot -PossibleNames @('login-logo.png', 'login-logo.svg', 'login-logo.jpg', 'login-logo.jpeg', 'small-logo.png', 'small-logo.svg') }

        if ($logo -and $favicon -and $background -and $loginBackground -and $loginLogo) {
            break
        }
    }

    $assetMap = [ordered]@{
        logo = $logo
        favicon = $favicon
        background = $background
        loginBackground = $loginBackground
        loginLogo = $loginLogo
    }

    $missing = @()
    foreach ($entry in $assetMap.GetEnumerator()) {
        if (-not $entry.Value) {
            $missing += $entry.Key
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "Skipping branding setup because these files are missing from $BrandingRoot: $($missing -join ', ')"
        return
    }

    $phpBrandScript = @"
<?php
require_once('$MoodleRoot/config.php');
require_once(
    \$CFG->dirroot . '/lib/filelib.php'
);

function save_brand_file(string \$component, string \$filearea, string \$sourcepath, int \$itemid = 0): void {
    if (!file_exists(\$sourcepath)) {
        throw new RuntimeException('Missing file: ' . \$sourcepath);
    }

    \$context = context_system::instance();
    \$fs = get_file_storage();
    \$fs->delete_area_files(\$context->id, \$component, \$filearea, \$itemid);

    \$filename = basename(\$sourcepath);
    \$fs->create_file_from_pathname([
        'contextid' => \$context->id,
        'component' => \$component,
        'filearea' => \$filearea,
        'itemid' => \$itemid,
        'filepath' => '/',
        'filename' => \$filename,
    ], \$sourcepath);

    set_config(\$filearea, '/' . \$filename, \$component);
}

save_brand_file('core_admin', 'logo', '$logo');
save_brand_file('core_admin', 'logocompact', '$logo');
save_brand_file('core_admin', 'favicon', '$favicon');
save_brand_file('theme_degrade', 'backgroundimage', '$background');
save_brand_file('theme_degrade', 'loginbackgroundimage', '$loginBackground');
save_brand_file('theme_degrade', 'loginlogo', '$loginLogo');

purge_caches();
printf("Branding updated from repo folder.\\n");
"@

    $tempBrandingScript = Join-Path $env:TEMP 'moodle-branding-apply.php'
    $phpBrandScript | Set-Content -LiteralPath $tempBrandingScript -Encoding UTF8

    Write-Host 'Applying branding from the repo branding folder...'
    & $PhpExe $tempBrandingScript
    if ($LASTEXITCODE -ne 0) {
        throw 'Moodle branding update failed.'
    }

    $purgeCachesScript = Join-Path $MoodleRoot 'admin\cli\purge_caches.php'
    if (Test-Path -LiteralPath $purgeCachesScript) {
        Write-Host 'Clearing Moodle caches after branding update...'
        & $PhpExe $purgeCachesScript
        if ($LASTEXITCODE -ne 0) {
            throw 'Cache purge failed after branding update.'
        }
    }

    $stopMoodleExe = Join-Path (Split-Path $MoodleRoot -Parent) 'Stop Moodle.exe'
    $startMoodleExe = Join-Path (Split-Path $MoodleRoot -Parent) 'Start Moodle.exe'

    if (Test-Path -LiteralPath $stopMoodleExe) {
        Write-Host 'Stopping Moodle to apply branding cleanly...'
        Start-Process -FilePath $stopMoodleExe -WorkingDirectory (Split-Path -Parent $stopMoodleExe) -Wait
    }

    if (Test-Path -LiteralPath $startMoodleExe) {
        Write-Host 'Restarting Moodle after branding update...'
        Start-Process -FilePath $startMoodleExe -WorkingDirectory (Split-Path -Parent $startMoodleExe) -WindowStyle Normal
    }
    else {
        Write-Warning 'Start Moodle.exe was not found; branding was updated but Moodle was not restarted automatically.'
    }
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

$repoBrandingRoot = Join-Path $BackupRoot 'branding'
Invoke-BrandingSetup -BrandingRoot $repoBrandingRoot -MoodleRoot $localCode -PhpExe $phpExe

Wait-ForMoodleSetup -Url $SiteUrl

Write-Host 'Restore script completed.'
Write-Host 'Next step: complete any setup or configuration steps necessary for your Moodle installation by going to localhost.'
