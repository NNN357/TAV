# TAV-X: Termux Automated Installation Script
### ✨ New Features 
*   **🛡️ ADB System-Level Keep-Alive Module**:
    *   Wireless debugging solution based on `android-tools`, no Root required.
    *   **One-click removal of Android 12/13/14's 32 subprocess limit** (solves the root cause of sudden tavern disconnections).
    *   Automatically requests **WakeLock (CPU wake lock)** to prevent TAV from stopping when the phone screen is locked.
    *   One-click addition of Termux to battery whitelist and granting background running permissions.
    *   Supports special optimization strategies for MIUI/ColorOS/OriginOS and other vendor ROMs.
*   **🧩 Dynamic Module Loader**:
    *   Main script is more lightweight. Modules are fetched from the cloud when clicked, ensuring storage space isn't wasted and features are always up-to-date.

### 🛠️ Fixes & Optimizations 
*   **🐛 Fixed Mirror Loop**: Fixed a critical bug where mirror prefixes were repeatedly concatenated during plugin installation, causing download failures.
*   **🎨 UI Visual Upgrade**: New gradient banner, more modern color scheme, improved interaction experience.
*   **⚡ Download Logic Refactored**: Script updates and module downloads now perfectly follow user-configured mirror sources or proxies.
*   **🗑️ Log Cleanup**: Fixed logic bug where menu still displayed old Cloudflare links after stopping services.

---

# **📱 Turn Your Idle Android Phone into a "Private Cloud Tavern": TAV-X One-Click Deployment Solution**

Are you still struggling to play SillyTavern anytime, anywhere? Have an idle old Android phone "gathering dust"? Want to chat freely on your main iPhone but limited by system restrictions?

**TAV-X (Termux Automated Venture-X)** is here! This is the ultimate solution you've been looking for.

No complex Linux knowledge needed, no tedious network configuration required, just one command to instantly turn your Android phone into a 24/7 online AI dedicated server!

---

## 🌟 Why Choose TAV-X?

*   **♻️ Turn Waste into Treasure, Give Old Phones New Life**
    Don't let old phones depreciate in your drawer! As long as it can run Termux, it's your best portable server. Deploy on old Android, enjoy on new phone. You can even access via tablet, computer, or TV browser, squeezing every drop of performance from old devices!

*   **🍎 Deploy on Android, Play on Apple**
    iOS users rejoice! You don't need to struggle with complex environments on iPhone. Deploy TAV-X on an Android backup phone, and through the generated exclusive link, your iPhone/iPad or even PC/Mac can seamlessly connect via browser to experience smooth native tavern.

*   **🚀 Completely "Painless", No VPN Needed**
    Tired of toggling VPN just to connect? TAV-X has built-in Cloudflare tunnel technology, no VPN needed, no public IP required. Whether you're at home, at work, or on mobile data, you can open the link anytime to reach your tavern.

*   **🔒 Private Data, Secure and Worry-Free**
    All chat records, character cards, and world books are still stored locally on your Android device, keeping data in your own hands. No need to worry about cloud service providers peeking at your privacy.

*   **👥 Become a "Tavern Master", Multi-User Collaboration**
    The script enables multi-user mode by default! You can control everything as an administrator (Admin) while creating a regular account to share with friends or use as your own "clean alt account". Through one link, multiple people can chat online simultaneously.

---

## 🚀 Project Introduction

TAV-X is a foolproof one-click installation script tailored for the Android Termux environment, designed to simplify the deployment and management process of SillyTavern. It integrates environment configuration, dependency installation, tunnel penetration, and background keep-alive functionality.

### ✨ Core Project Highlights

| Feature | Description |
| :--- | :--- |
| **One-Click Deployment** | One command completes environment dependency installation, project cloning, and configuration initialization. |
| **Smart Shortcut Command** | Automatically configures the `st` command. After configuration, just type `st` next time to directly invoke the menu. |
| **TUI Interactive Management** | Provides intuitive Text User Interface (TUI) menu, integrating service status and real-time remote link display. |
| **Stable Background Running** | Uses `setsid nohup` to start, and enables `termux-wake-lock`, ensuring service remains stable when Termux is in background and screen is off. |
| **Cross-Device Sharing** | Uses Cloudflare tunnel technology (no extra configuration needed) to generate secure links for remote access from any device. |
| **Non-Destructive Updates** | Automatically stashes local modifications, ensuring local files and data are unaffected after core project updates. |

---

## ⚡ Quick Start

### Preparation
Please ensure you have installed and opened the Android Termux terminal application.

### 📥 Installation & Launch Commands

Please choose one of the following commands based on your network environment, copy it to Termux and execute.

#### 🌏 Universal/International Line (Global)
If you're outside mainland China, or your network environment allows GitHub access:
```bash
curl -s -L https://raw.githubusercontent.com/NNN357/TAV/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

#### 🚀 China Mainland Accelerated Lines
If you encounter network connection issues, please choose any of the following accelerated commands:

**Line 1 (EdgeOne):**
```bash
curl -s -L https://edgeone.gh-proxy.com/https://raw.githubusercontent.com/NNN357/TAV/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

**Line 2 (HK):**
```bash
curl -s -L https://hk.gh-proxy.com/https://raw.githubusercontent.com/NNN357/TAV/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

**Line 3 (Generic):**
```bash
curl -s -L https://gh-proxy.com/https://raw.githubusercontent.com/NNN357/TAV/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

**Line 4 (Likk):**
```bash
curl -s -L https://gh.likk.cc/https://raw.githubusercontent.com/NNN357/TAV/main/st.sh -o st.sh && chmod +x st.sh && ./st.sh; source ~/.bashrc
```

### ⚠️ Important: First Run Operation Guidelines
To ensure the shortcut command `st` works correctly, please strictly follow these steps:
1.  After executing the installation command above, the script will automatically enter the installation process and finally display the menu interface.
2.  **Do not perform any operations!** When first entering the menu interface, directly type number `0` and press Enter to exit the script.
3.  After exiting, the script will automatically refresh the environment (or you can manually type `source ~/.bashrc`).
4.  Type `st` in the terminal and press Enter.
5.  The script starts again, environment configuration is now fully effective, and you can use all features normally.

---

## 🛡️ Security & Multi-User Setup

To protect your data security and enable cross-device collaboration, please note the following key information:

*   **Multi-User Mode Enabled**: This script has automatically enabled multi-user (User Accounts) and discreet login features in the configuration file.
*   **First Login Security Reminder**:
    *   Default admin username: `default-user`
    *   No password on first login: For security reasons, `default-user` has no default password after first run.
    *   **Set Password Immediately**: You must go to the admin settings page to set a strong password after logging in. Please keep your password safe.
*   **Sharing & Collaboration**: After the script starts remote sharing, it will generate a Cloudflare tunnel link. You can share this link and user accounts you create with others for multi-user simultaneous access.
*   **Intranet Penetration**: If you need remote startup, do not use global VPN, as it will greatly reduce the success rate of Cloudflare tunnel links.

---

## 💡 FAQ & Advanced Guide

### 1. 🌐 Advanced Tip: How to Use VPN and Remote Sharing Simultaneously?

**Q: My tavern needs VPN to connect to OpenAI/Claude, but the TAV-X remote link (Cloudflare) disconnects when VPN is enabled. What should I do?**

**A: Please use "Per-App Proxy" mode! Don't let Termux traffic go directly through VPN.**

Core Principle: We need Termux's system traffic (Cloudflare tunnel) to go direct, while only letting the tavern program (through internal configuration) go through the local proxy port.

**Steps:**

*   **Step 1: Keep VPN App enabled, but "exclude" Termux in settings**
    Please open your proxy software, find the **Per-App Proxy** or **Access Control** feature, and set `Termux` to **"Bypass"** or **"No Proxy"**.
    *   **Clash Users**: Go to `Settings` -> `Access Control` -> Select mode `Only allow selected apps` (don't check Termux) or select `Don't proxy selected apps` (check Termux).
    *   **v2rayNG Users**: Go to `Settings` -> `Per-App Proxy` -> Enable switch -> Select mode `Bypass LAN and apps in per-app proxy blacklist` -> Check `Termux` in the list.

*   **Step 2: Get Local HTTP Proxy Port**
    Find the **"HTTP Proxy Port"** in your VPN App settings (usually `7890`, `10809`, or `20171`), note this number.

*   **Step 3: Configure API Proxy in TAV-X Script**
    1.  Open Termux, type `st` to run the script.
    2.  Select **`7. 🌐 Set API Proxy Configuration`** -> **`1. 🟢 Enable/Set Proxy`**.
    3.  Enter your local proxy address (e.g., `http://127.0.0.1:7890`, replace with the port number you noted).

**🎉 Result:** After setup, your Cloudflare remote link will maintain stable direct connection, while AI conversations in the tavern will respond quickly through the proxy port!

### 2.👁️‍🗨️ Keep-Alive Module FAQ

**Q: Error `protocol fault (couldn't read status message)`, what to do?**

A: The ADB service is stuck. Type `r` in the connection menu, the script will automatically restart the ADB service and fix it.

**Q: Do I need to do this again after restarting the phone?**

A: **Yes.** The wireless debugging switch turns off after restart, and some system settings (like phantom process limits) reset to default after restart. It's recommended to run this module again after restarting your phone.

**Q: Use 127.0.0.1 or 192.168.x.x?**

A: Strongly recommend using **127.0.0.1**. This is the local loopback address, doesn't go through the router, fastest speed and won't be affected by network fluctuations.

---

### 2. 💾 Data Backup & Recovery Guide

**Q: How do I backup and restore data? What happens if I accidentally modify the backup filename?**

**A: TAV-X provides a secure data management mechanism. Please follow these rules to ensure data isn't lost.**

**About Backup**
*   **Backup Content**: The script only backs up the core `data` directory (containing chat records, character cards, world books, user settings).
*   **Storage Location**: Backup files are **not** in Termux, but stored in your phone's **Internal Storage/Download/ST_Backup** folder.
*   **Security**: Even if you uninstall Termux, as long as you don't delete this folder in the phone's download directory, your data is safe.

**About Recovery**
*   **Steps**: Run script by typing `st` -> Select **`8. 💾 Data Backup & Recovery`** -> Select **`2. 📤 Restore Data`** -> Select the corresponding backup file.
*   **⚠️ Warning: Do NOT modify filenames!**
    The script relies on specific filename formats to identify backup files.
    Backup files must maintain the `ST_Backup_timestamp.tar.gz` format (e.g., `ST_Backup_20231125_120000.tar.gz`).
    *   **❌ Wrong approach**: Manually rename to `my_backup.tar.gz`.
    *   **Consequence**: The script will **not recognize** the file, causing you to not see it in the recovery list and unable to restore!

**What if only Termux was reinstalled?**
As long as your backup file is still in the `Download/ST_Backup` directory and the filename hasn't been modified, you just need to reinstall the TAV-X script, go directly to the backup menu after first launch and perform "Restore" operation, and all your data will instantly return!

---


## 📖 TAV-X ADB Keep-Alive Module User Guide

> **Why do you need this?**
> If your tavern often suddenly disconnects mid-conversation, or becomes unreachable a few minutes after the phone screen locks, it's usually because of Android's aggressive background killing mechanism (especially Android 12+'s Phantom Process Killer). This module completely solves this problem through ADB permissions.

### ✅ Preparation
1.  **System Requirements**: Android 11 and above (supports wireless debugging).
2.  **No Root Required**: All operations are done through standard ADB protocol.
3.  **Connect to WiFi**: Wireless debugging requires the phone to be connected to WiFi (any WiFi works, even a router without internet).

### ⚡️ Operation Steps

#### Step 1: Enter the Module
Run `st`, select **`11. 🛡️ ADB Keep-Alive`** in the main menu. The script will automatically download and load the keep-alive module.

#### Step 2: Pairing (Only needed first time)
*If you haven't used wireless debugging before, or get `Connection refused` error, please do this step.*

1.  Enable **Split Screen Mode** or **Floating Window Mode** on your phone (Termux on one side, system settings on the other).
2.  Go to phone **Settings -> Developer Options -> Wireless Debugging**.
3.  Click **"Pair device with pairing code"**.
4.  In TAV-X menu, type `1` to enter connection assistant, then type `p` to enter pairing mode.
5.  Enter the **IP:Port** and **6-digit pairing code** from the popup as prompted.
    *   *Recommend using `127.0.0.1:port` format for more stability.*

#### Step 3: Connect ADB
1.  After successful pairing, return to the [Wireless Debugging] main interface.
2.  Check the **"IP address and port"** displayed on the main interface (Note: this is different from the pairing port!).
3.  Enter that port number in the TAV-X menu.
4.  Display `✔ ADB Connected Successfully` means complete.

#### Step 4: One-Click Keep-Alive
1.  After successful connection, select **`2. Execute System-Level Keep-Alive`** in the module menu.
2.  The script will ask about strategies in sequence, recommend **entering `y` to confirm all**:
    *   **Disable Phantom Process Killer**: Core feature, must select.
    *   **Battery Whitelist**: Prevents Doze mode freezing, must select.
    *   **Background Permission**: Prevents system cleanup, must select.
    *   **WakeLock**: After requesting, Termux notification will appear in notification bar, ensuring CPU doesn't sleep when screen is locked.
3.  After seeing `✅ Keep-Alive Strategy Applied Successfully!`, your Termux has obtained a "death immunity pass".

---

### 📥 How to Update?
Run `st` in Termux, select **`5. Update Management`** -> **`2. 📜 Update TAV-X`** to automatically upgrade to v1.12.0.


Thank you for your support of TAV-X! If you encounter any issues during use, feel free to submit an Issue on the project GitHub repository.
