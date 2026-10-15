

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
