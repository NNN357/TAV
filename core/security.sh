#!/bin/bash
# TAV-X Core: System Settings

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

NETWORK_CONFIG="$TAVX_DIR/config/network.conf"

full_wipe() {
    ui_header "One-Click Complete Uninstall"
    echo -e "${RED}Danger Level: ⭐⭐⭐⭐⭐${NC}"
    echo -e "This operation will perform all of the following actions:"
    echo -e "  1. Uninstall SillyTavern and all installed modules"
    echo -e "  2. Delete all configuration data and local files"
    echo -e "  3. Clean environment variables"
    echo -e "  4. Self-delete TAV-X script"
    echo ""
    
    if ! verify_kill_switch; then return; fi
    if command -v stop_all_services_routine &>/dev/null; then
        stop_all_services_routine
    fi
    
    ui_spinner "Executing deep cleanup..." "
        if [ -d \"$APPS_DIR\" ]; then
            for app in \"$APPS_DIR\"/*; do
                [ -d \"\$app\" ] && rm -rf \"\$app\"
            done
        fi
        
        [ -d \"\$HOME/SillyTavern\" ] && rm -rf \"\$HOME/SillyTavern\"
        
        sed -i '/alias st=/d' \"$HOME/.bashrc\" 2>/dev/null
        sed -i '/alias ai=/d' \"$HOME/.bashrc\" 2>/dev/null
    "
    
    ui_print success "Business data cleared."
    echo -e "${YELLOW}Self-destruct program initiated... Goodbye! 👋${NC}"
    sleep 2
    cd "$HOME" || exit
    /bin/rm -rf "$TAVX_DIR"
    exit 0
}

change_npm_source() {
    ui_header "NPM Source Configuration (Node.js)"
    local current=$(npm config get registry 2>/dev/null)
    echo -e "Current source: ${CYAN}$current${NC}"; echo ""
    local OPTS=("Taobao Mirror (npmmirror)|https://registry.npmmirror.com/" "Tencent Mirror|https://mirrors.cloud.tencent.com/npm/" "Official Source|https://registry.npmjs.org/")
    local MENU_OPTS=(); local URLS=()
    for item in "${OPTS[@]}"; do MENU_OPTS+=("${item%%|*}"); URLS+=("${item#*|}"); done; MENU_OPTS+=("🔙 Return")
    local CHOICE=$(ui_menu "Select mirror source" "${MENU_OPTS[@]}")
    if [[ "$CHOICE" == *"Return"* ]]; then return; fi
    local TARGET_URL=""; for i in "${!MENU_OPTS[@]}"; do if [[ "${MENU_OPTS[$i]}" == "$CHOICE" ]]; then TARGET_URL="${URLS[$i]}"; break; fi; done
    if [ -n "$TARGET_URL" ]; then if npm config set registry "$TARGET_URL"; then ui_print success "NPM source set to: $CHOICE"; else ui_print error "Setting failed"; fi; fi; ui_pause
}

change_system_source() {
    ui_header "System Software Source Configuration"
    if [ "$OS_TYPE" == "TERMUX" ]; then
        if command -v termux-change-repo &> /dev/null; then ui_print info "Launching Termux official tool..."; sleep 1; termux-change-repo; else ui_print error "termux-change-repo not found"; fi
    else
        echo -e "${YELLOW}Linux One-Click Mirror Change (LinuxMirrors)${NC}"; echo ""
        if ui_confirm "Run one-click mirror change script?"; then command -v curl &> /dev/null && bash <(curl -sSL https://linuxmirrors.cn/main.sh) || ui_print error "Missing curl"; fi
    fi; ui_pause
}

clean_git_remotes() {
    ui_header "Git Repository Source Cleanup"
    if ! ui_confirm "Reset all component update sources to GitHub official addresses?"; then return; fi
    ui_print info "Repairing..."
    
    local st_path=$(get_app_path "sillytavern")
    reset_to_official_remote "$TAVX_DIR" "NNN357/TAV.git" && echo -e "  - TAV-X: OK"
    [ -d "$st_path" ] && reset_to_official_remote "$st_path" "SillyTavern/SillyTavern.git" && echo -e "  - SillyTavern: OK"
    
    ui_print success "Repair complete."; ui_pause
}

configure_download_network() {
    while true; do
        ui_header "Network & Software Source Configuration"
        local curr_mode="Auto (Smart Self-Healing)"
        if [ -f "$NETWORK_CONFIG" ]; then
            local c=$(cat "$NETWORK_CONFIG")
            curr_mode="${c#*|}"
        fi
        echo -e "Current strategy: ${CYAN}$curr_mode${NC}"; echo "----------------------------------------"
        local OPTS=("🔧 Custom Download Proxy" "🔄 Reset Network Settings" "♻️  Repair Git Repository Sources" "🐍 Change PIP Source" "📦 Change NPM Source" "🐧 Change System Source" "🔙 Return")
        local CHOICE=$(ui_menu "Select operation" "${OPTS[@]}")
        case "$CHOICE" in
            *"Custom"*)
                local url=$(ui_input "Enter proxy (e.g. http://127.0.0.1:7890)" "" "false")
                if [[ "$url" =~ ^(http|https|socks5|socks5h)://.* ]]; then
                    echo "PROXY|$url" > "$NETWORK_CONFIG"
                    ui_print success "Saved"
                else
                    ui_print error "Format error"
                fi
                ui_pause 
                ;;
            *"Reset"*) 
                rm -f "$NETWORK_CONFIG"
                unset SELECTED_MIRROR
                reset_proxy_cache
                ui_print success "Network configuration reset (next task will re-scan and speed test)"
                ui_pause 
                ;;
            *"Git"*) clean_git_remotes ;;
            *"PIP"*) 
                source "$TAVX_DIR/core/python_utils.sh"
                select_pypi_mirror ;;
            *"NPM"*) change_npm_source ;;
            *"System"*) change_system_source ;;
            *"Return"*) return ;;
        esac
    done
}

configure_cf_token() {
    ui_header "Cloudflare Tunnel Token"
    local token_file="$TAVX_DIR/config/cf_token"
    local current_stat="${YELLOW}Not Configured${NC}"; if [ -s "$token_file" ]; then local t=$(cat "$token_file"); current_stat="${GREEN}Configured${NC} (${t:0:6}...)"; fi
    echo -e "Status: $current_stat"; echo "----------------------------------------"
    local OPTS=("✏️ Enter/Update Token" "🗑️ Clear Token" "🔙 Return")
    local CHOICE=$(ui_menu "Select operation" "${OPTS[@]}")
    case "$CHOICE" in
        *"Enter"*) local i=$(ui_input "Please paste Token" "" "false"); [ -n "$i" ] && echo "$i" > "$token_file" && ui_print success "Saved"; ui_pause ;;
        *"Clear"*) rm -f "$token_file"; ui_print success "Cleared"; ui_pause ;; *"Return"*) return ;;
    esac
}

clean_system_garbage() {
    ui_header "System Garbage Cleanup"
    echo -e "Preparing to clean the following:"
    echo -e "  1. System temp files ($TMP_DIR/tavx_*)"
    echo -e "  2. Old logs from module runs (logs/*.log)"
    echo ""
    
    if ! ui_confirm "Confirm immediate cleanup?"; then return; fi
    
    ui_spinner "Cleaning..." "
        source \"$TAVX_DIR/core/utils.sh\"
        safe_rm \"$LOGS_DIR\"/*.log
        rm -f \"$TMP_DIR\"/tavx_* 2>/dev/null
        rm -f \"$TMP_DIR\"/*.log 2>/dev/null
    "
    
    ui_print success "Cleanup complete!"
    ui_pause
}

system_settings_menu() {
    while true; do
        ui_header "System Settings"
        local OPTS=(
            "📥 Download Source & Proxy Configuration"
            "🐍 Python Environment Management"
            "📱 ADB Smart Assistant"
            "☁️  Cloudflare Token"
            "🧹 System Garbage Cleanup"
            "💥 One-Click Complete Destruction (Dangerous)"
            "🔙 Return to Main Menu"
        )
        local CHOICE=$(ui_menu "Please select function" "${OPTS[@]}")
        case "$CHOICE" in
            *"Download Source"*) configure_download_network ;;
            *"Python"*) 
                source "$TAVX_DIR/core/python_utils.sh"
                python_environment_manager_ui ;;
            *"ADB"*)
                source "$TAVX_DIR/core/adb_utils.sh"
                adb_manager_ui ;;
            *"Cloudflare"*) configure_cf_token ;;
            *"Cleanup"*) clean_system_garbage ;;
            *"Destruction"*) full_wipe ;;
            *"Return"*) return ;;
        esac
    done
}
