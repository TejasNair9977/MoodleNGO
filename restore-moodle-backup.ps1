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
    if (-not (Test-Path -LiteralPath $Path)) { throw "Required path not found: $Path" }
}

function Invoke-MySqlCommand {
    param([string]$Executable, [string[]]$Arguments)
    $output = & $Executable @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "MySQL command failed: $($output -join [Environment]::NewLine)" }
    return $output
}

function Wait-ForMySql {
    param([string]$Executable, [string]$HostName, [string]$User, [string]$Password)
    $arguments = @('-h', $HostName, '-u', $User)
    if ($Password) { $arguments += @('-p' + $Password) }
    $arguments += @('-N', '-e', 'SELECT 1;')
    Write-Host 'Waiting for the local MySQL server...'
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $null = & $Executable @arguments 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Host 'MySQL is ready.'; return }
        Start-Sleep -Seconds 2
    }
    throw 'MySQL did not become available within 60 seconds. Check that Moodle services are running.'
}

function Expand-ArchiveToFolder {
    param([string]$ArchivePath, [string]$DestinationPath)
    if (-not (Test-Path -LiteralPath $ArchivePath)) { throw "Archive not found: $ArchivePath" }
    $sevenZip = @('C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\7-Zip\7z.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($sevenZip) {
        Write-Host "Extracting $ArchivePath to $DestinationPath using 7-Zip..."
        & $sevenZip x -y "-o$DestinationPath" $ArchivePath
        if ($LASTEXITCODE -ne 0) { throw "Failed to extract archive: $ArchivePath" }
    } else {
        Write-Host "Extracting $ArchivePath to $DestinationPath using Expand-Archive..."
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
    }
}

function Get-BrandingFile {
    param([string]$BrandingRoot, [string[]]$PossibleNames)
    if (-not (Test-Path -LiteralPath $BrandingRoot)) { return $null }
    $files = Get-ChildItem -LiteralPath $BrandingRoot -File -ErrorAction SilentlyContinue
    foreach ($possible in $PossibleNames) {
        $match = $files | Where-Object { $_.Name -ieq $possible } | Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    foreach ($possible in $PossibleNames) {
        $match = $files | Where-Object { $_.Name -ilike "*$possible*" } | Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    return $null
}

function Invoke-BrandingSetup {
    param([string]$BrandingRoot, [string]$MoodleRoot, [string]$PhpExe)
    $searchRoots = @()
    if (Test-Path -LiteralPath $BrandingRoot) { $searchRoots += $BrandingRoot }
    $backupRoot = Split-Path -Parent $BrandingRoot
    if ($backupRoot -and (Test-Path -LiteralPath $backupRoot) -and ($BrandingRoot -ne $backupRoot)) { $searchRoots += $backupRoot }
    if ($searchRoots.Count -eq 0) { Write-Host "No branding folder found at $BrandingRoot. Skipping branding setup."; return }

    $names = [ordered]@{
        logo = @('logo.png','logo.jpg','logo.jpeg','logo.svg','site-logo.png','site-logo.jpg','site-logo.svg')
        favicon = @('favicon.ico','favicon.png','favicon.svg','site-favicon.ico','site-favicon.png','site-favicon.svg')
        background = @('background.jpg','background.jpeg','background.png','site-background.jpg','site-background.png','home-background.jpg')
        loginBackground = @('login-background.jpg','login-background.jpeg','login-background.png','login-bg.jpg','login-bg.png','background-login.jpg')
        loginLogo = @('login-logo.png','login-logo.svg','login-logo.jpg','login-logo.jpeg','small-logo.png','small-logo.svg')
    }
    $assets = [ordered]@{}
    foreach ($key in $names.Keys) { $assets[$key] = $null }
    foreach ($root in $searchRoots) {
        foreach ($key in $names.Keys) { if (-not $assets[$key]) { $assets[$key] = Get-BrandingFile $root $names[$key] } }
    }
    $missing = @($assets.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
    if ($missing.Count -gt 0) { Write-Host "Skipping branding setup because these files are missing from $BrandingRoot: $($missing -join ', ')"; return }

    $phpBrandScript = @"
<?php
require_once('$MoodleRoot/config.php');
require_once(\$CFG->dirroot . '/lib/filelib.php');
function save_brand_file(string \$component, string \$filearea, string \$sourcepath, int \$itemid = 0): void {
    if (!file_exists(\$sourcepath)) { throw new RuntimeException('Missing file: ' . \$sourcepath); }
    \$context = context_system::instance();
    \$fs = get_file_storage();
    \$fs->delete_area_files(\$context->id, \$component, \$filearea, \$itemid);
    \$fs->create_file_from_pathname(['contextid'=>\$context->id,'component'=>\$component,'filearea'=>\$filearea,'itemid'=>\$itemid,'filepath'=>'/','filename'=>basename(\$sourcepath)], \$sourcepath);
    set_config(\$filearea, '/' . basename(\$sourcepath), \$component);
}
save_brand_file('core_admin', 'logo', '$($assets.logo)');
save_brand_file('core_admin', 'logocompact', '$($assets.logo)');
save_brand_file('core_admin', 'favicon', '$($assets.favicon)');
save_brand_file('theme_degrade', 'backgroundimage', '$($assets.background)');
save_brand_file('theme_degrade', 'loginbackgroundimage', '$($assets.loginBackground)');
save_brand_file('theme_degrade', 'loginlogo', '$($assets.loginLogo)');
purge_caches();
"@
    $temp = Join-Path $env:TEMP 'moodle-branding-apply.php'
    $phpBrandScript | Set-Content -LiteralPath $temp -Encoding UTF8
    Write-Host 'Applying branding from the repo branding folder...'
    & $PhpExe $temp
    if ($LASTEXITCODE -ne 0) { throw 'Moodle branding update failed.' }
    $purge = Join-Path $MoodleRoot 'admin\cli\purge_caches.php'
    if (Test-Path -LiteralPath $purge) { & $PhpExe $purge; if ($LASTEXITCODE -ne 0) { throw 'Cache purge failed after branding update.' } }
    $moodleDir = Split-Path $MoodleRoot -Parent
    $stop = Join-Path $moodleDir 'Stop Moodle.exe'; $start = Join-Path $moodleDir 'Start Moodle.exe'
    if (Test-Path -LiteralPath $stop) { Start-Process $stop -WorkingDirectory $moodleDir -Wait }
    if (Test-Path -LiteralPath $start) { Start-Process $start -WorkingDirectory $moodleDir -WindowStyle Normal } else { Write-Warning 'Start Moodle.exe was not found; branding was updated but Moodle was not restarted automatically.' }
}

function Wait-ForMoodleSetup {
    param([string]$Url)
    Write-Host 'Waiting 20 seconds before opening the browser...'; Start-Sleep -Seconds 20
    Write-Host "Opening $Url in your default browser..."; Start-Process -FilePath $Url
    Write-Host 'Please verify the restored Moodle site in the browser.'
    do { $response = Read-Host -Prompt 'Type DONE when verification is complete.' } while ($response -ne 'DONE')
}

$repoCode = Join-Path $BackupRoot 'moodle'; $repoData = Join-Path $BackupRoot 'moodledata'; $repoServerArchive = Join-Path $BackupRoot 'server.zip'; $repoDataArchive = Join-Path $BackupRoot 'moodledata.7z'; $repoSql = Join-Path $BackupRoot 'moodle_backup.sql'
$localCode = Join-Path $LocalRoot 'moodle'; $localData = Join-Path $LocalRoot 'moodledata'; $mysqlBin = Join-Path $LocalRoot 'mysql\bin'; $mysqlExe = Join-Path $mysqlBin 'mysql.exe'; $mysqldumpExe = Join-Path $mysqlBin 'mysqldump.exe'; $phpExe = Join-Path $LocalRoot 'php\php.exe'
if (-not (Test-Path $repoServerArchive) -and -not (Test-Path $repoCode)) { throw "A Moodle runtime archive or code folder was not found in $BackupRoot." }
if (-not (Test-Path $repoServerArchive) -and -not (Test-Path $repoDataArchive) -and -not (Test-Path $repoData)) { throw "A Moodle data backup was not found in $BackupRoot." }
Test-CommandExists $repoSql; Test-CommandExists $LocalRoot; Test-CommandExists $mysqlBin; Test-CommandExists $mysqlExe; Test-CommandExists $mysqldumpExe; Test-CommandExists $phpExe
if (-not $Force -and (Read-Host 'This will overwrite local Moodle data. Type YES to continue') -ne 'YES') { Write-Host 'Restore cancelled.'; return }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (Test-Path $localData) { Rename-Item $localData "$($localData).backup-$timestamp" }
if (Test-Path $localCode) { Rename-Item $localCode "$($localCode).backup-$timestamp" }
New-Item -ItemType Directory -Path $localData -Force | Out-Null
if (Test-Path $repoServerArchive) { Expand-ArchiveToFolder $repoServerArchive $LocalRoot } elseif (Test-Path $repoDataArchive) { Expand-ArchiveToFolder $repoDataArchive $LocalRoot } else { Copy-Item (Join-Path $repoData '*') $localData -Recurse -Force }
if (Test-Path $repoCode) { Copy-Item $repoCode $LocalRoot -Recurse -Force }
$cfg = @"
<?php
unset(`$CFG); global `$CFG; `$CFG = new stdClass();
`$CFG->dbtype = 'mariadb'; `$CFG->dblibrary = 'native'; `$CFG->dbhost = '$DbHost'; `$CFG->dbname = '$DatabaseName'; `$CFG->dbuser = '$DbUser'; `$CFG->dbpass = '$DbPassword'; `$CFG->prefix = 'mdl_';
`$CFG->dboptions = array('dbpersist'=>0,'dbport'=>'','dbsocket'=>'','dbcollation'=>'utf8mb4_unicode_ci');
`$CFG->wwwroot = '$SiteUrl'; `$CFG->dataroot = '$localData'; `$CFG->admin = 'admin'; `$CFG->directorypermissions = 0777;
require_once(__DIR__ . '/lib/setup.php');
"@
[IO.File]::WriteAllText((Join-Path $localCode 'config.php'), $cfg, [Text.UTF8Encoding]::new($false))
$start = Join-Path (Split-Path $LocalRoot -Parent) 'Start Moodle.exe'; if (Test-Path $start) { Start-Process $start -WorkingDirectory (Split-Path $start -Parent) -WindowStyle Normal }
Wait-ForMySql $mysqlExe $DbHost $DbUser $DbPassword
$auth = @('-h',$DbHost,'-u',$DbUser); if ($DbPassword) { $auth += '-p' + $DbPassword }
Invoke-MySqlCommand $mysqlExe ($auth + @('-e',"DROP DATABASE IF EXISTS $DatabaseName; CREATE DATABASE $DatabaseName;")) | Out-Null
$normalized = Join-Path $LocalRoot "moodle-backup-normalized-$timestamp.sql"; (Get-Content $repoSql -Raw) | Set-Content $normalized -Encoding UTF8
Get-Content $normalized | & $mysqlExe ($auth + @($DatabaseName)); if ($LASTEXITCODE -ne 0) { throw 'SQL import failed.' }
Invoke-MySqlCommand $mysqlExe ($auth + @('-e',"DELETE FROM $DatabaseName.mdl_config WHERE name = 'siteidentifier';")) | Out-Null
& $phpExe (Join-Path $localCode 'admin\cli\purge_caches.php'); if ($LASTEXITCODE -ne 0) { throw 'Moodle cache purge failed after database restore.' }

Wait-ForMoodleSetup -Url $SiteUrl

# Branding is intentionally applied after the manual site verification wait.
$repoBrandingRoot = Join-Path $BackupRoot 'branding'
Invoke-BrandingSetup -BrandingRoot $repoBrandingRoot -MoodleRoot $localCode -PhpExe $phpExe

Write-Host 'Restore script completed.'
Write-Host 'Next step: complete any setup or configuration steps necessary for your Moodle installation by going to localhost.'
