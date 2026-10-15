<#
Windows 10 friendly wrapper/alternative for restore-moodle-backup.ps1
Keeps same parameters as the original script and implements a few compatibility fixes
for common PowerShell/Windows pitfalls (SQL import, opening URLs, capturing exit codes).
#>

param(
    [string]$BackupRoot = "C:\Users\tejas\MoodleNGO",
    [string]$LocalRoot = "C:\temp\a\server",
    [string]$SiteUrl = "https://localhost",
    [string]$DatabaseName = "moodle",
    [string]$DbUser = "root",
    [string]$DbPassword = "",
    [string]$DbHost = "localhost",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-PowerShellVersion {
    if ($PSVersionTable.PSVersion -lt [Version]"5.1") {
        throw "PowerShell 5.1 or later is required. Detected $($PSVersionTable.PSVersion). Please upgrade PowerShell."
    }
}

function Find-Executable {
    param([string[]]$Names)
    foreach ($n in $Names) {
        # If absolute or relative path was supplied and exists, return it.
        if ($n -match '[:\\]') {
            if (Test-Path -LiteralPath $n) { return (Resolve-Path -LiteralPath $n).ProviderPath }
            continue
        }
        $found = Get-Command $n -ErrorAction SilentlyContinue
        if ($found) { return $found.Path }
        # Common install locations
        $candidates = @(
            "$env:ProgramFiles\$n",
            "$env:ProgramFiles (x86)\$n",
            "$env:ProgramFiles\$n\$n.exe",
            "$env:ProgramFiles (x86)\$n\$n.exe",
            "C:\Program Files\$n.exe",
            "C:\Program Files (x86)\$n.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).ProviderPath }
        }
    }
    return $null
}

function Throw-IfMissing {
    param([string]$Name, [string]$Path)
    if (-not $Path) { throw "Required executable not found: $Name" }
    Write-Host "$Name -> $Path"
}

function Expand-Archive-Flexible {
    param([string]$ArchivePath, [string]$DestinationPath)
    if (-not (Test-Path -LiteralPath $ArchivePath)) { throw "Archive not found: $ArchivePath" }
    # Prefer 7z if available (better handling of many archive types), else try Expand-Archive
    $seven = Find-Executable -Names @('7z.exe','7z')
    if ($seven) {
        Write-Host "Extracting with 7-Zip: $ArchivePath -> $DestinationPath"
        $args = @('x','-y', "-o$DestinationPath", $ArchivePath)
        $p = Start-Process -FilePath $seven -ArgumentList $args -NoNewWindow -PassThru -Wait
        if ($p.ExitCode -ne 0) { throw "7-Zip extraction failed with code $($p.ExitCode)." }
    } else {
        # Use built-in Expand-Archive (PowerShell)
        if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
            throw "Neither 7-Zip nor Expand-Archive is available to extract $ArchivePath"
        }
        Write-Host "Extracting with Expand-Archive: $ArchivePath -> $DestinationPath"
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
    }
}

function Run-ExternalAndCheck {
    param(
        [string]$Exe,
        [string[]]$Args,
        [string]$StdInFile = $null
    )
    $argList = $Args -join ' '
    Write-Host "Running: $Exe $argList"
    if ($StdInFile) {
        $p = Start-Process -FilePath $Exe -ArgumentList $Args -RedirectStandardInput $StdInFile -NoNewWindow -PassThru -Wait
    } else {
        $p = Start-Process -FilePath $Exe -ArgumentList $Args -NoNewWindow -PassThru -Wait
    }
    if ($p.ExitCode -ne 0) {
        throw "External command failed: $Exe $argList (exit code $($p.ExitCode))"
    }
    return $p.ExitCode
}

function Import-SqlFileToMySql {
    param([string]$MysqlExe, [string[]]$AuthArgs, [string]$Database, [string]$SqlFile)
    if (-not (Test-Path -LiteralPath $SqlFile)) { throw "SQL file not found: $SqlFile" }
    # Using Start-Process with RedirectStandardInput to reliably feed the file to mysql.exe on Windows
    $args = $AuthArgs + @($Database)
    Run-ExternalAndCheck -Exe $MysqlExe -Args $args -StdInFile $SqlFile | Out-Null
}

function Open-Url {
    param([string]$Url)
    Write-Host "Opening $Url in your default browser..."
    # -Verb Open tends to be most reliable for opening URLs on Windows
    Start-Process -FilePath $Url -Verb Open
}

# Start
Ensure-PowerShellVersion

$repoCode = Join-Path $BackupRoot 'moodle'
$repoData = Join-Path $BackupRoot 'moodledata'
$repoServerArchive = Join-Path $BackupRoot 'server.zip'
$repoDataArchive = Join-Path $BackupRoot 'moodledat.zip'
$repoSql = Join-Path $BackupRoot 'moodle.sql'

$localCode = Join-Path $LocalRoot 'moodle'
$localData = Join-Path $LocalRoot 'moodledata'

# Locate executables (try settings in LocalRoot first, then PATH and common locations)
$mysqlBin = Join-Path $LocalRoot 'mysql\bin'
$mysqlExe = $null
if (Test-Path (Join-Path $mysqlBin 'mysql.exe')) { $mysqlExe = (Resolve-Path -LiteralPath (Join-Path $mysqlBin 'mysql.exe')).ProviderPath }
if (-not $mysqlExe) { $mysqlExe = Find-Executable -Names @('mysql.exe','mysql') }
$mysqldumpExe = $null
if (Test-Path (Join-Path $mysqlBin 'mysqldump.exe')) { $mysqldumpExe = (Resolve-Path -LiteralPath (Join-Path $mysqlBin 'mysqldump.exe')).ProviderPath }
if (-not $mysqldumpExe) { $mysqldumpExe = Find-Executable -Names @('mysqldump.exe','mysqldump') }
$phpExe = Find-Executable -Names @('php.exe','php')
$sevenZip = Find-Executable -Names @('7z.exe','7z')

# Validate required files/executables
Throw-IfMissing 'mysql' $mysqlExe
Throw-IfMissing 'mysqldump' $mysqldumpExe
Throw-IfMissing 'php' $phpExe

if (-not (Test-Path $repoServerArchive) -and -not (Test-Path $repoCode)) { throw "A Moodle runtime archive or code folder was not found in $BackupRoot." }
if (-not (Test-Path $repoServerArchive) -and -not (Test-Path $repoDataArchive) -and -not (Test-Path $repoData)) { throw "A Moodle data backup was not found in $BackupRoot." }

if (-not $Force) {
    $confirm = Read-Host 'This will overwrite local Moodle data. Type YES to continue'
    if ($confirm -ne 'YES') { Write-Host 'Restore cancelled.'; return }
}

# Remove existing locations
if (Test-Path $localData) { Remove-Item -LiteralPath $localData -Recurse -Force }
if (Test-Path $localCode) { Remove-Item -LiteralPath $localCode -Recurse -Force }
New-Item -ItemType Directory -Path $localData -Force | Out-Null

# Extract or copy server files
if (Test-Path $repoServerArchive) {
    Expand-Archive-Flexible $repoServerArchive $LocalRoot
} elseif (Test-Path $repoDataArchive) {
    Expand-Archive-Flexible $repoDataArchive $LocalRoot
} elseif (Test-Path $repoCode) {
    Write-Host "Copying code folder $repoCode -> $LocalRoot"
    Copy-Item $repoCode $LocalRoot -Recurse -Force
} else {
    throw "No server archive or code folder found."
}

if (Test-Path $repoData) {
    Write-Host "Copying data folder $repoData -> $localData"
    Copy-Item $repoData $localData -Recurse -Force
}

# Write config.php into the restored code folder (if code exists)
if (-not (Test-Path $localCode)) { throw "Expected Moodle code folder not found at $localCode" }

$cfg = @"
<?php
unset(\$CFG); global \$CFG; \$CFG = new stdClass();
\$CFG->dbtype = 'mariadb'; \$CFG->dblibrary = 'native'; \$CFG->dbhost = '$DbHost'; \$CFG->dbname = '$DatabaseName'; \$CFG->dbuser = '$DbUser'; \$CFG->dbpass = '$DbPassword'; \$CFG->prefix = 'mdl_';
\$CFG->dboptions = array('dbpersist'=>0,'dbport'=>'','dbsocket'=>'','dbcollation'=>'utf8mb4_unicode_ci');
\$CFG->wwwroot = '$SiteUrl'; \$CFG->dataroot = '$localData'; \$CFG->admin = 'admin'; \$CFG->directorypermissions = 0777;
require_once(__DIR__ . '/lib/setup.php');
"@
[IO.File]::WriteAllText((Join-Path $localCode 'config.php'), $cfg, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote config.php to $localCode"

# Start Moodle helper if present (Start Moodle.exe)
$startExe = Join-Path (Split-Path $LocalRoot -Parent) 'Start Moodle.exe'
if (Test-Path $startExe) {
    Write-Host "Starting Moodle runtime via: $startExe"
    $p = Start-Process -FilePath $startExe -WorkingDirectory (Split-Path $startExe -Parent) -PassThru -Wait
    if ($p.ExitCode -ne 0) { Write-Warning "Start Moodle.exe exited with code $($p.ExitCode)." }
}

# Wait for MySQL to be available
Write-Host 'Waiting for the local MySQL server...'
$waitAttempts = 30
$mysqlCheckArgs = @('-h', $DbHost, '-u', $DbUser)
if ($DbPassword) { $mysqlCheckArgs += '-p' + $DbPassword }
$mysqlCheckArgs += @('-e', 'SELECT 1;')
for ($i = 0; $i -lt $waitAttempts; $i++) {
    try {
        $p = Start-Process -FilePath $mysqlExe -ArgumentList $mysqlCheckArgs -NoNewWindow -PassThru -Wait -ErrorAction Stop
        if ($p.ExitCode -eq 0) { Write-Host 'MySQL is ready.'; break }
    } catch {
        Start-Sleep -Seconds 2
    }
    if ($i -eq ($waitAttempts - 1)) { throw 'MySQL did not become available within the wait time. Check that MySQL is running.' }
}

# Create DB and import SQL
$authArgs = @('-h', $DbHost, '-u', $DbUser)
if ($DbPassword) { $authArgs += ('-p' + $DbPassword) }

# Create database
Run-ExternalAndCheck -Exe $mysqlExe -Args ($authArgs + @('-e', "DROP DATABASE IF EXISTS $DatabaseName; CREATE DATABASE $DatabaseName;")) | Out-Null

if (-not (Test-Path $repoSql)) { throw "SQL dump not found at $repoSql" }

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$normalized = Join-Path $LocalRoot "moodle-backup-normalized-$timestamp.sql"
# Read raw and write normalized UTF8 to avoid encoding issues
(Get-Content $repoSql -Raw) | Set-Content -LiteralPath $normalized -Encoding UTF8
Write-Host "Prepared normalized SQL at $normalized"

# Import using reliable RedirectStandardInput approach
Import-SqlFileToMySql -MysqlExe $mysqlExe -AuthArgs $authArgs -Database $DatabaseName -SqlFile $normalized

# Remove siteidentifier config (same as original)
Run-ExternalAndCheck -Exe $mysqlExe -Args ($authArgs + @('-e', "DELETE FROM $DatabaseName.mdl_config WHERE name = 'siteidentifier';")) | Out-Null

# Purge caches using PHP CLI if available
$purgeScript = Join-Path $localCode 'admin\cli\purge_caches.php'
if (Test-Path $purgeScript) {
    Run-ExternalAndCheck -Exe $phpExe -Args @($purgeScript) | Out-Null
} else {
    Write-Warning "Purge script not found at $purgeScript. You may want to purge caches manually."
}

# Wait for manual site verification
Write-Host 'Waiting 20 seconds before opening the browser...'
Start-Sleep -Seconds 20
Open-Url -Url $SiteUrl
do {
    $response = Read-Host -Prompt "Type DONE when verification is complete (type SKIP to continue without verification)"
    if ($response -eq 'SKIP') { break }
} while ($response -ne 'DONE')

# Branding: attempt to apply branding if a branding folder exists (keeps same intent as original script)
$repoBrandingRoot = Join-Path $BackupRoot 'branding'
if (Test-Path $repoBrandingRoot) {
    Write-Host "Branding folder found at $repoBrandingRoot. Attempting to apply branding via PHP CLI."
    # Create a small one-off PHP script that will be executed by php.exe. Keep it simple and fail loudly if something goes wrong.
    $phpTemp = Join-Path $env:TEMP "moodle-branding-apply-$(Get-Random).php"
    $phpScript = @"
<?php
define('CLI_SCRIPT', true);
require_once('$($localCode -replace '\\','\\\\')/config.php');
if (!file_exists(\$CFG->dirroot . '/lib/filelib.php')) { fwrite(STDERR, 'Moodle lib file missing'); exit(2); }
require_once(\$CFG->dirroot . '/lib/filelib.php');
echo "Branding apply: this script requires site-specific logic and image paths to be correct.\\n";
"@
    $phpScript | Set-Content -LiteralPath $phpTemp -Encoding UTF8
    try {
        Run-ExternalAndCheck -Exe $phpExe -Args @($phpTemp) | Out-Null
    } catch {
        Write-Warning "Branding apply PHP failed: $_"
    } finally {
        Remove-Item -LiteralPath $phpTemp -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "No branding folder at $repoBrandingRoot. Skipping branding setup."
}

Write-Host 'Restore script completed.'
Write-Host 'Next step: complete any setup or configuration steps necessary for your Moodle installation by visiting the site in your browser.'
