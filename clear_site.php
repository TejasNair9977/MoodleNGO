<?php
// Retry connection until MariaDB is fully up
$conn = null;
echo "Connecting to MariaDB database...\n";
for ($i = 0; $i < 30; $i++) {
    $conn = @mysqli_connect('db', 'moodle', 'moodle_password', 'moodle');
    if ($conn) {
        break;
    }
    sleep(2);
}

if (!$conn) {
    echo "Database connection failed after retries.\n";
    exit(1);
}

// Wait until mdl_config table exists from the backup import
echo "Waiting for Moodle database tables to initialize...\n";
$tableExists = false;
for ($i = 0; $i < 30; $i++) {
    $result = mysqli_query($conn, "SHOW TABLES LIKE 'mdl_config';");
    if ($result && mysqli_num_rows($result) > 0) {
        $tableExists = true;
        break;
    }
    sleep(2);
}

if ($tableExists) {
    mysqli_query($conn, "DELETE FROM mdl_config WHERE name = 'siteidentifier';");
    echo "Site identifier cleared successfully.\n";
} else {
    echo "Timeout waiting for mdl_config table.\n";
}