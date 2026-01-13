# Cloudflare Tunnel Management Module

This module integrates core Cloudflare Tunnel functionality, providing TAV-X with secure and stable intranet penetration capabilities, supporting Termux and mainstream Linux distributions.

## 🌟 Core Features

- **One-Click Deployment**: Automatically adapts architecture to install the latest version of `cloudflared`.
- **Dual Mode Support**:
  - **⚡ Quick Tunnel**: No login required, generates random `.trycloudflare.com` domain.
  - **🚀 Named Tunnel**: Supports binding custom domains with persistent configuration.
- **Smart Mapping Management**: Supports add/delete/modify/query of multi-domain mappings (Ingress Rules).
- **Automated DNS**: Integrates Cloudflare API for automatic domain record addition and cleanup.
- **Orphan Cleanup**: Automatically scans and cleans invalid DNS records pointing to defunct tunnels.

## 🌐 Get a Free Domain

If you don't have your own domain yet, you can get a free domain from these platforms:
- **Registration URL**: [DigitalPlat Domain](https://dash.domain.digitalplat.org/)

**Brief Process:**
1.  **Register Account**: Register and log in on the platform.
2.  **Apply for Domain**: Choose an available free suffix to apply.
3.  **Connect to Cloudflare**:
    -   Click **Add a Site** in the Cloudflare control panel.
    -   Enter the domain you applied for.
    -   **Modify NS Records**: Change the NameServers at the free domain provider to the addresses provided by Cloudflare.
4.  **Wait for Propagation**: Once DNS takes effect, you can start the quick start process below.

> 📘 **Detailed Tutorial**: For a step-by-step guide on domain registration and hosting on Cloudflare, please refer to [Nodeloc Community Tutorial](https://www.nodeloc.com/t/topic/41595).

## 🛠️ Quick Start

### 1. Login Authorization
Before executing script authorization, **please complete pre-login first**, otherwise the mobile browser may lose the authorization page after login.

**Steps:**

1.  **Browser Pre-Login**:
    -   Manually open browser, visit [Cloudflare Dashboard](https://dash.cloudflare.com/).
    -   **Complete account login** until you see the domain list or control panel.
2.  **Return to TAV-X Script**:
    -   Select **🔐 Tunnel Login Authorization** in the Cloudflare menu.
3.  **Click Authorization Link**:
    -   The script will generate an authorization URL and try to redirect.
    -   Since you've already logged in via browser, the page will directly show the "Select Domain" interface.
4.  **Complete Authorization**:
    -   Click to select the domain to bind, click **Authorize**.
5.  **Confirm Return**:
    -   After seeing `Success` prompt on the webpage, return to the script and wait for system prompt `Login Successful`.

> 💡 **Key Point**: If you click the script link first then login, Cloudflare often gets stuck on the homepage after login and won't automatically return to the authorization page.

### 2. Temporary Intranet Penetration
If you just want to temporarily test a local service:
- Select **⚡ Quick Tunnel**
- Enter local service port (default 8000)
- Get the generated public URL.
- This feature is extremely unstable and blocked in some regions, not recommended for long-term use.

### 3. Create Fixed Domain Tunnel
If you want to have a fixed access address long-term:
1. Select **🚀 Start/Manage Named Tunnels** -> **➕ Create New Tunnel**.
2. Name the tunnel and follow the guide to bind your custom domain.
3. The system will automatically handle DNS routing and start the background service.

## 🔑 Advanced Feature: API Token

For a better automation experience, it's recommended to configure an API Token:
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens).
2. Create a Token with **Zone.DNS:Edit** permission.
3. Select **🔑 API Token Settings** in the module menu to save.

After configuration, you can use the **🧹 Scan and Clean Orphan DNS** feature to quickly clean up "residual" domain records left by abnormal operations.

## 📂 File Structure

- `main.sh`: Module core management logic.
- `api_utils.sh`: Cloudflare API interaction wrapper.
- `*.yml`: Independent configuration files for each named tunnel.
- `logs/`: Records running status of each tunnel.

## ⚠️ Notes

- When using in Termux, please ensure external storage permission is granted for better compatibility.
- After modifying domain mappings, the script will automatically restart the corresponding tunnel process to apply changes.
- Uninstalling/resetting the module will erase local credentials, but it's recommended to manually stop and delete cloud tunnel resources before uninstalling.
