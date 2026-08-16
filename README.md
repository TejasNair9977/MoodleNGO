# Moodle Site Backup

Download the local Moodle server bundle here:
https://drive.google.com/file/d/1ykF3-Mvf3UnYMoUfP2LTpaJvg6cwt0nG/view?usp=sharing

This file is the external server.zip package used to restore the Moodle runtime. It is intentionally kept outside the Git repository so the project can still be pushed without hitting GitHub's file-size limits.

Install the Moodle application with version 405 with default settings.

To use this site in its current state, follow these steps:

1. **Database:** Import `moodle_backup.sql` into your local `moodle` database.

IN POWERSHELL, `[System.IO.File]::WriteAllLines("moodle_backup.sql", (Get-Content moodle_backup.sql))` to fix encoding.

IN CMD, `mysql -u root moodle < moodle_backup.sql`

THEN REGENERATE SITE IDENTIFIER:

`mysql -u root moodle`

`DELETE FROM mdl_config WHERE name = 'siteidentifier';`


2. **Moodle Data (Images & H5P):**

* Download the `moodledata_backup.zip` from the repo.
   
* Unzip it and place the `moodledata` folder directly into your `./server` directory.

Adding h5p courses is a little tough, and may require much larger backups because of the requirement of extensions, so I have excluded it from here.

Download the plugin from here: https://moodle.org/plugins/mod_hvp

## 🧩 Installing Moodle Plugins

Follow these structural steps to safely upload and deploy a third-party plugin archive.

### 1. Source the Plugin
* Download from https://moodle.org/plugins/mod_hvp

### 2. Upload via the Administration Dashboard
* Log in to the portal using an account with **Administrator** system privileges.
* Navigate using the primary menu path: `Site administration` > `Plugins` > `Install plugins`.
* Drag and drop the downloaded `.zip` archive into the designated file uploader field.
* Click the **Install plugin from the ZIP file** button to initiate the deployment sequence.

### 3. Execute Environment Checks and Database Upgrade
* **Validation Check:** Moodle will inspect the archive file structure. Review the validation results and click **Continue**.
* **Environment Status Check:** The system verifies your server's PHP extensions and dependency flags. Scroll to the base of the checklist and click **Continue**.
* **Database Migration:** Click **Upgrade Moodle database now** to execute necessary database schema mutations. (If asked)
* **Completion:** Once the execution log returns a terminal status of "Success", click **Continue** to complete the workflow.

---

## 🎬 Deploying H5P Interactive Content

Moodle utilizes a centralized **Content Bank** architecture to store, version, and manage interactive learning assets before they are linked to specific course execution blocks.

### 1. Stage the Asset in the Content Bank
* Open your target course space from the site dashboard.
* Click **More** in the course primary navigation bar and select **Content bank** from the contextual dropdown menu.
* **To upload an existing asset binary:** Click **Upload**, select your local `.h5p` deployment file, and save.
* **To author a new asset in-app:** Click **Add**, select your desired interactive template tool (e.g., *Interactive Video*, *Course Presentation*, or *Find the Hotspot*), populate the editor fields, and click **Save**.

### 2. Provision the H5P Activity Node
* Return to your primary course landing page.
* Toggle the **Edit mode** switch to **ON** in the top-right corner of the global header.
* Locate your target topic section and click **Add an activity or resource**.
* Select **H5P** (identified by the standard blue H5P application icon).
* Populate the required **Name** field and optional description metadata.

### 3. Bind the Package and Configure Grade Book Hooks
* Inside the *Package file* configuration boundary box, click the file picker icon.
* Select **Content bank** from the left-hand repository taxonomy menu.
* Locate and highlight your target `.h5p` asset node, then click **Select this file**.
* Expand the **Grade** settings component drawer:
  * Configure the **Grade Type** (Point or Scale).
  * Set the maximum point allocations to allow active grading endpoints to pass score attributes directly to the core Moodle grade book logic.
* Click **Save and display** to launch and verify the interactive component interface.
