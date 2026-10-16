# Windows Advanced Folder Locker with Auto-Lock
*A lightweight, native Windows utility that secures a private folder using Control Panel CLSID masking, NTFS permission restrictions, SHA-256 password hashing, and an event-driven PowerShell auto-lock monitor.*

---

## Features
- **CLSID Disguise & Hide:** Transforms the protected folder into a Windows Control Panel shell object (`{21EC2020-3AEA-1069-A2DD-08002B30309D}`) with hidden and system attributes applied.
- **NTFS Access Deny:** Uses `icacls` to deny read/write/access rights to the current user profile when locked.
- **SHA-256 Password Hashing:** Hashes passwords natively via Windows `certutil`—no plain-text passwords stored on disk.
- **Anti-Brute Force Protection:** Enforces incremental throttle delays on incorrect entries and locks out access after 3 failed attempts.
- **Background Inactivity Monitor:** A low-overhead PowerShell watcher tracks mouse/keyboard idle state and folder file system events, automatically re-locking the folder if you step away.
- **Native Windows Only:** Runs on standard Windows 10/11 using Batch and PowerShell. No third-party software required.

---

## How to Set It Up

1. Download or save `locker.bat` into an empty folder where you want your secure directory to reside.
2. Double-click `locker.bat`.
3. Because this is the first run, the initial setup will start:
   - Enter your desired **Master Password**.
   - Enter an **Idle Timeout** in minutes (e.g., `5` to auto-lock after 5 minutes of inactivity, or `0` to disable auto-lock).
4. The script creates an unlocked folder named `Private` and securely stores your settings in `.auth.dat`.

---

## How to Use
### Locking the Folder Manually
1. Place your sensitive files inside the `Private` folder.
2. Run `locker.bat`.
3. Press `Y` when prompted to lock the folder.
4. The folder will immediately be disguised, hidden, and locked.

### Unlocking the Folder
1. Run `locker.bat`.
2. Enter your master password when prompted.
3. Upon successful verification, the folder is restored to `Private` and ready for use.
4. If you set a timeout, the background inactivity monitor will automatically engage.

---

### Important Security Notes
> [!WARNING]
> This tool uses Windows shell disguises and access control lists (`icacls`). It is designed to keep files private from casual snooping, shared family members, or standard user accounts. **It is not full-disk encryption (like BitLocker or VeraCrypt).** Advanced users with administrative tools can still read or take ownership of the underlying storage blocks.

---

### Files Generated

- `Private/` — Your working folder when unlocked.
- `ControlPanel.{21EC2020-3AEA-1069-A2DD-08002B30309D}/` — The folder state while locked.
- `.auth.dat` — Hidden file containing your password hash and timeout configuration.
