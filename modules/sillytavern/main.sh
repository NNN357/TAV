#!/bin/bash
# [METADATA]
# MODULE_ID: sillytavern
# MODULE_NAME: SillyTavern
# MODULE_ENTRY: sillytavern_menu
# APP_CATEGORY="Frontend"
# APP_VERSION="Standard"
# APP_DESC="Next-generation LLM immersive frontend interface"
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

_st_vars() {
    ST_APP_ID="sillytavern"
    ST_DIR=$(get_app_path "$ST_APP_ID")
    ST_PID_FILE="$RUN_DIR/sillytavern.pid"
    ST_LOG="$ST_DIR/server.log"
}

[ -f "$(dirname "${BASH_SOURCE[0]}")/plugins.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/plugins.sh"

sillytavern_install() {
    _st_vars
    ui_header "SillyTavern Installation Wizard"
    
    if [ -d "$ST_DIR" ]; then
        ui_print warn "Detected existing version or directory: $ST_DIR"
        if ! ui_confirm "Confirm overwrite installation? (This will clear all data in this directory)"; then return; fi
        safe_rm "$ST_DIR"
    fi
    
    mkdir -p "$(dirname "$ST_DIR")"
    
    # Prepare network strategy in advance (interactive source selection) to prevent UI corruption during progress bar
    prepare_network_strategy
    
    local CLONE_CMD="source \"$TAVX_DIR/core/utils.sh\"; git_clone_smart '-b release' 'SillyTavern/SillyTavern' '$ST_DIR'"
    
    if ! ui_stream_task "Pulling source code..." "$CLONE_CMD"; then
        ui_print error "Source code download failed."
        return 1
    fi
    
    ui_print info "Installing dependencies..."
    if npm_install_smart "$ST_DIR"; then
        chmod +x "$ST_DIR/start.sh" 2>/dev/null
        sillytavern_configure_recommended
        ui_print success "Installation successful!"
    else
        ui_print error "Dependency installation failed."
        return 1
    fi
}

sillytavern_update() {
    _st_vars
    ui_header "SillyTavern Smart Update"
    if [ ! -d "$ST_DIR/.git" ]; then ui_print error "No valid Git repository detected."; ui_pause; return; fi
    
    cd "$ST_DIR" || return
    if ! git symbolic-ref -q HEAD >/dev/null; then
        local current_tag=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
        ui_print warn "Currently in version-locked state ($current_tag)"
        echo -e "${YELLOW}Please [Unlock] first before attempting to update.${NC}"; ui_pause; return
    fi
    
    # Prepare network strategy in advance
    prepare_network_strategy
    
    local TEMP_URL=$(get_dynamic_repo_url "SillyTavern/SillyTavern")
    local UPDATE_CMD="cd \"$ST_DIR\"; git pull --autostash \"$TEMP_URL\""
    
    if ui_stream_task "Syncing latest code..." "$UPDATE_CMD"; then
        ui_print success "Code sync complete."
        npm_install_smart "$ST_DIR"
    else
        ui_print error "Update failed! Possible conflicts or network issues."
    fi
    ui_pause
}

sillytavern_rollback() {
    _st_vars
    while true; do
        ui_header "SillyTavern Version Time Machine"
        cd "$ST_DIR" || return
        
        local CURRENT_DESC=""
        local IS_DETACHED=false
        if git symbolic-ref -q HEAD >/dev/null; then
            local branch=$(git rev-parse --abbrev-ref HEAD)
            CURRENT_DESC="${GREEN}Branch: $branch (Latest)${NC}"
        else
            IS_DETACHED=true
            local tag=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
            CURRENT_DESC="${YELLOW}🔒 Locked: $tag${NC}"
        fi
        
        local TAG_CACHE="$TMP_DIR/.st_tag_cache"
        echo -e "Current Status: $CURRENT_DESC"
        echo "----------------------------------------"
        
        local MENU_ITEMS=()
        [ "$IS_DETACHED" = true ] && MENU_ITEMS+=("🔓 Unlock (Switch to Latest)")
        MENU_ITEMS+=("⏳ Rollback to Historical Version" "🔀 Switch Channel: Release" "🔀 Switch Channel: Staging" "🔙 Return")
        
        local CHOICE=$(ui_menu "Select Operation" "${MENU_ITEMS[@]}")
        
        # Prepare network strategy in advance
        if [[ "$CHOICE" != *"Return"* ]]; then
             prepare_network_strategy
        fi

        local TEMP_URL=$(get_dynamic_repo_url "SillyTavern/SillyTavern")
        
        case "$CHOICE" in
            *"Unlock"*) 
                if ui_confirm "Confirm restore to latest Release version?"; then
                    local CMD="git config remote.origin.fetch \"+refs/heads/*:refs/remotes/origin/*\"; git fetch \"$TEMP_URL\" release --depth=1; git checkout -B release FETCH_HEAD"
                    ui_stream_task "Rejoining..." "$CMD" && npm_install_smart "$ST_DIR"
                fi ;;
            *"Historical"*) 
                ui_stream_task "Fetching version list..." "git fetch \"$TEMP_URL\" --tags"
                git tag --sort=-v:refname | head -n 10 > "$TAG_CACHE"
                mapfile -t TAG_LIST < "$TAG_CACHE"
                local TAG_CHOICE=$(ui_menu "Select Version" "${TAG_LIST[@]}" "🔙 Cancel")
                if [[ "$TAG_CHOICE" != *"Cancel"* ]]; then
                    local CMD="git fetch \"$TEMP_URL\" tag \"$TAG_CHOICE\" --depth=1; git reset --hard FETCH_HEAD; git checkout \"$TAG_CHOICE\""
                    ui_stream_task "Rolling back to $TAG_CHOICE..." "$CMD" && npm_install_smart "$ST_DIR"
                fi ;;
            *"Switch Channel"*) 
                local TARGET="release"; [[ "$CHOICE" == *"Staging"* ]] && TARGET="staging"
                local CMD="git config remote.origin.fetch \"+refs/heads/*:refs/remotes/origin/*\"; git fetch \"$TEMP_URL\" $TARGET --depth=1; git checkout -B $TARGET FETCH_HEAD"
                ui_stream_task "Switching to $TARGET..." "$CMD" && npm_install_smart "$ST_DIR" ;;
            *"Return"*) return ;;
        esac
        ui_pause
    done
}

sillytavern_start() {
    _st_vars
    [ ! -d "$ST_DIR" ] && { ui_print error "SillyTavern not installed"; return 1; }
    
    local mem_conf="$CONFIG_DIR/memory.conf"
    local mem_args=""
    if [ -f "$mem_conf" ]; then
        local m=$(cat "$mem_conf")
        [[ "$m" =~ ^[0-9]+$ ]] && mem_args="--max-old-space-size=$m"
    fi
    
    cd "$ST_DIR" || return 1
    sillytavern_stop
    
    rm -f "$ST_LOG"
    local START_CMD="setsid nohup node $mem_args server.js > '$ST_LOG' 2>&1 & echo \$! > '$ST_PID_FILE'"
    
    if ui_spinner "Starting SillyTavern service..." "eval \"$START_CMD\""; then
        sleep 2
        if check_process_smart "$ST_PID_FILE" "node.*server.js"; then
            ui_print success "Service started."
            return 0
        fi
    fi
    ui_print error "Startup failed, please check logs."; return 1
}

sillytavern_stop() {
    _st_vars
    kill_process_safe "$ST_PID_FILE" "node.*server.js"
}

sillytavern_uninstall() {
    _st_vars
    ui_header "Uninstall SillyTavern"
    [ ! -d "$ST_DIR" ] && { ui_print error "Not installed."; return; }
    
    if ! verify_kill_switch; then return; fi
    
    sillytavern_stop
    if ui_spinner "Erasing SillyTavern data..." "safe_rm '$ST_DIR'" ;
then
        ui_print success "Uninstall complete."
        return 2
    fi
}

sillytavern_backup() {
    _st_vars
    ui_header "Data Backup"
    [ ! -d "$ST_DIR" ] && { ui_print error "Please install SillyTavern first!"; ui_pause; return; }
    local dump_dir=$(ensure_backup_dir)
    if [ $? -ne 0 ]; then ui_pause; return; fi
    
    cd "$ST_DIR" || return
    local TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
    local BACKUP_FILE="$dump_dir/TAVX_Backup_SillyTavern_${TIMESTAMP}.tar.gz"
    
    local TARGETS="data"
    [ -f "secrets.json" ] && TARGETS="$TARGETS secrets.json"
    [ -d "plugins" ] && TARGETS="$TARGETS plugins"
    if [ -d "public/scripts/extensions/third-party" ]; then TARGETS="$TARGETS public/scripts/extensions/third-party"; fi
    
    echo -e "${CYAN}Backing up:${NC}"
    echo -e "$TARGETS" | tr ' ' '\n' | sed 's/^/  - /'
    echo ""
    if ui_spinner "Packaging..." "tar -czf '$BACKUP_FILE' $TARGETS 2>/dev/null"; then
        ui_print success "Backup successful!"
        echo -e "Location: ${GREEN}$BACKUP_FILE${NC}"
    else
        ui_print error "Backup failed."
    fi
    ui_pause
}

sillytavern_restore() {
    _st_vars
    ui_header "Data Restore"
    [ ! -d "$ST_DIR" ] && { ui_print error "Please install SillyTavern first!"; ui_pause; return; }
    local dump_dir=$(ensure_backup_dir)
    if [ $? -ne 0 ]; then ui_pause; return; fi
    
    local files=($dump_dir/TAVX_Backup_*.tar.gz "$dump_dir/ST_Data_*.tar.gz"); local valid_files=()
    for f in "${files[@]}"; do [ -e "$f" ] && valid_files+=("$f"); done
    
    if [ ${#valid_files[@]} -eq 0 ]; then ui_print warn "No backup files found."; ui_pause; return; fi
    
    local MENU_ITEMS=(); local FILE_MAP=()
    for file in "${valid_files[@]}"; do
        local fname=$(basename "$file")
        local fsize=$(du -h "$file" | awk '{print $1}')
        MENU_ITEMS+=("📦 $fname ($fsize)")
        FILE_MAP+=("$file")
    done
    MENU_ITEMS+=("🔙 Return")
    
    local CHOICE=$(ui_menu "Select backup file" "${MENU_ITEMS[@]}")
    if [[ "$CHOICE" == *"Return"* ]]; then return; fi
    
    local selected_file=""
    for i in "${!MENU_ITEMS[@]}"; do if [[ "${MENU_ITEMS[$i]}" == "$CHOICE" ]]; then selected_file="${FILE_MAP[$i]}"; break; fi; done
    
    echo ""
    ui_print warn "Warning: This will overwrite existing chat history!"
    if ! ui_confirm "Are you sure you want to continue?"; then return; fi
    
    local TEMP_DIR="$TAVX_DIR/temp_restore"
    safe_rm "$TEMP_DIR"; mkdir -p "$TEMP_DIR"
    
    if ui_spinner "Extracting and verifying..." "tar -xzf '$selected_file' -C '$TEMP_DIR'"; then
        cd "$ST_DIR" || return
        ui_print info "Importing..."
        if [ -d "$TEMP_DIR/data" ]; then
            if [ -d "data" ]; then mv data data_old_bak; fi
            if cp -r "$TEMP_DIR/data" .; then safe_rm "data_old_bak"; ui_print success "Data restored successfully"; else safe_rm "data"; mv data_old_bak data; ui_print error "Data restore failed, rolled back"; ui_pause; return; fi
        fi
        if [ -f "$TEMP_DIR/secrets.json" ]; then cp "$TEMP_DIR/secrets.json" .; ui_print success "API Keys restored"; fi
        if [ -d "$TEMP_DIR/plugins" ]; then cp -r "$TEMP_DIR/plugins" .; ui_print success "Server plugins restored"; fi
        if [ -d "$TEMP_DIR/public/scripts/extensions/third-party" ]; then mkdir -p "public/scripts/extensions/third-party"; cp -r "$TEMP_DIR/public/scripts/extensions/third-party/." "public/scripts/extensions/third-party/"; ui_print success "Frontend extensions restored"; fi
        
        safe_rm "$TEMP_DIR"
        echo ""
        ui_print success "🎉 Restore complete! Recommend restarting the service."
    else
        ui_print error "Extraction failed! File corrupted."
        safe_rm "$TEMP_DIR"
    fi
    ui_pause
}

sillytavern_configure_recommended() {
    _st_vars
    local BATCH_JSON='{ "extensions.enabled": true, "enableServerPlugins": true, "performance.useDiskCache": false }'
    _st_config_set_batch "$BATCH_JSON"
}

sillytavern_enable_public_access() {
    _st_vars
    ui_header "Public Access Configuration"
    echo -e "${YELLOW}This operation will perform the following changes:${NC}"
    echo -e "  1. Allow 0.0.0.0 external access (tunnel compatible)"
    echo -e "  2. Automatically enable [Multi-user System] for data security"
    echo -e "  3. Enable discreet login mode"
    echo ""
    
    if ! ui_confirm "Confirm to enable now?"; then return; fi
    
    local has_accounts=$(_st_config_get "enableUserAccounts")
    local has_auth=$(_st_config_get "basicAuthMode")
    
    if [[ "$has_accounts" != "true" && "$has_auth" != "true" ]]; then
        ui_print warn "No authentication detected. For public network security, please set an admin password now."
        local u=$(ui_input "Set admin username" "default-user" "false")
        local p=$(ui_input "Set admin password" "" "true")
        if [ -n "$p" ]; then
            cd "$ST_DIR" || return
            node recover.js "$u" "$p" >/dev/null 2>&1
            ui_print success "Admin account created: $u"
        else
            ui_print error "Password is required to enable public access. Operation cancelled."
            ui_pause; return 1
        fi
    fi

    ui_print info "Applying secure network configuration..."
    local BATCH_JSON='{ "listen": true, "whitelistMode": false, "enableUserAccounts": true, "enableDiscreetLogin": true, "basicAuthMode": false }'
    
    if _st_config_set_batch "$BATCH_JSON"; then
        ui_print success "Public access mode enabled!"
        echo -e "${GREEN}✅ Security protection ready:${NC}"
        echo -e "   - Forced Authentication [ON]"
        echo -e "   - Account Isolation System [ON]"
    else
        ui_print error "Configuration application failed."
    fi
    ui_pause
}

sillytavern_configure_advanced() {
    _st_vars
    [ ! -f "$ST_DIR/config.yaml" ] && { ui_print error "Config file doesn't exist, please install SillyTavern first."; ui_pause; return; }
    local CONFIG_MAP=( "SEPARATOR|--- Basic Connection Settings ---" "listen|Allow External Network Connection" "whitelistMode|Whitelist Mode" "basicAuthMode|Force Password Login" "enableUserAccounts|Multi-user Account System" "enableDiscreetLogin|Discreet Login Mode" "SEPARATOR|--- Network & Security Advanced ---" "disableCsrfProtection|Disable CSRF Protection" "enableCorsProxy|Enable CORS Proxy" "protocol.ipv6|Enable IPv6 Protocol Support" "ssl.enabled|Enable SSL/HTTPS" "hostWhitelist.enabled|Host Header Whitelist Check" "SEPARATOR|--- Performance & Update Optimization ---" "performance.lazyLoadCharacters|Lazy Load Characters (Greatly improves startup speed)" "performance.useDiskCache|Enable Disk Cache (Recommend OFF for Termux)" "extensions.enabled|Load Extension Plugins" "extensions.autoUpdate|Auto Update Extensions (Recommend OFF)" "enableServerPlugins|Load Server Plugins" "enableServerPluginsAutoUpdate|Auto Update Server Plugins" "SEPARATOR|--- Danger Zone ---" "RESET_CONFIG|⚠️ Reset to Default Config" )
    while true; do
        ui_header "SillyTavern Config Management"
        echo -e "${CYAN}Click item to toggle status${NC}"; echo "----------------------------------------"
        local MENU_OPTS=(); local KEY_LIST=()
        for item in "${CONFIG_MAP[@]}"; do
            local key="${item%%|*}"; local label="${item#*|}"
            if [ "$key" == "SEPARATOR" ]; then MENU_OPTS+=("📂 $label"); KEY_LIST+=("SEPARATOR"); continue; fi
            if [ "$key" == "RESET_CONFIG" ]; then MENU_OPTS+=("💥 $label"); KEY_LIST+=("RESET_CONFIG"); continue; fi
            local val=$(_st_config_get "$key"); local icon="🔴"; local stat="[OFF]"
            if [ "$val" == "true" ]; then icon="🟢"; stat="[ON]"; fi
            if [[ "$key" == "whitelistMode" || "$key" == "performance.useDiskCache" ]]; then if [ "$val" == "true" ]; then icon="🟡"; fi; fi
            MENU_OPTS+=("$icon $label $stat"); KEY_LIST+=("$key")
        done
        MENU_OPTS+=("🔙 Return")
        local CHOICE_IDX
        if [ "$HAS_GUM" = true ]; then
            local SELECTED_TEXT=$(gum choose "${MENU_OPTS[@]}" --header "" --cursor.foreground 212)
            for i in "${!MENU_OPTS[@]}"; do if [[ "${MENU_OPTS[$i]}" == "$SELECTED_TEXT" ]]; then CHOICE_IDX=$i; break; fi; done
        else
            local i=1; for opt in "${MENU_OPTS[@]}"; do echo "$i. $opt"; ((i++)); done
            read -p "Enter number: " input_idx; if [[ "$input_idx" =~ ^[0-9]+$ ]]; then CHOICE_IDX=$((input_idx - 1)); fi
        fi
        if [[ "${MENU_OPTS[$CHOICE_IDX]}" == *"Return"* ]]; then return; fi
        if [ -n "$CHOICE_IDX" ] && [ "$CHOICE_IDX" -ge 0 ] && [ "$CHOICE_IDX" -lt "${#KEY_LIST[@]}" ]; then
            local target_key="${KEY_LIST[$CHOICE_IDX]}"
            if [ "$target_key" == "SEPARATOR" ]; then continue; fi
            if [ "$target_key" == "RESET_CONFIG" ]; then
                if ui_confirm "Reset config.yaml to default values?"; then 
                    rm -f "$ST_DIR/config.yaml"
                    ui_print success "Config reset, auto-restarting service to regenerate..."
                    sillytavern_start
                    return
                fi
                continue
            fi
            local current_val=$(_st_config_get "$target_key"); local new_val="true"
            if [ "$current_val" == "true" ]; then new_val="false"; fi
            if _st_config_set "$target_key" "$new_val"; then sleep 0.1; fi
        fi
    done
}

sillytavern_configure_memory() {
    ui_header "Runtime Memory Configuration"
    local mem_info=$(free -m | grep "Mem:"); local total_mem=$(echo "$mem_info" | awk '{print $2}'); local avail_mem=$(echo "$mem_info" | awk '{print $7}')
    [[ -z "$total_mem" ]] && total_mem=0; [[ -z "$avail_mem" ]] && avail_mem=0
    local safe_max=$((total_mem - 2048)); if [ "$safe_max" -lt 1024 ]; then safe_max=1024; fi
    local curr_set="Default (Node.js Auto)"; if [ -f "$TAVX_DIR/config/memory.conf" ]; then curr_set="$(cat "$TAVX_DIR/config/memory.conf") MB"; fi
    echo -e "Physical Memory: ${GREEN}${total_mem} MB${NC} | Available: ${YELLOW}${avail_mem} MB${NC} | Current: ${PURPLE}${curr_set}${NC}"
    echo "----------------------------------------"
    echo -e "Enter maximum memory to allocate for SillyTavern (in MB), enter 0 to restore default."
    local input_mem=$(ui_input "Enter value (e.g., 4096)" "" "false")
    if [[ ! "$input_mem" =~ ^[0-9]+$ ]]; then ui_print error "Invalid number"; ui_pause; return; fi
    if [ "$input_mem" -eq 0 ]; then rm -f "$TAVX_DIR/config/memory.conf"; ui_print success "Restored to default strategy."; else echo "$input_mem" > "$TAVX_DIR/config/memory.conf"; ui_print success "Set to: ${input_mem} MB"; fi
    ui_pause
}

sillytavern_configure_browser() {
    local BROWSER_CONF="$TAVX_DIR/config/browser.conf"
    while true; do
        ui_header "Browser Launch Method"
        local current_mode="ST"; if [ -f "$BROWSER_CONF" ]; then current_mode=$(cat "$BROWSER_CONF"); fi
        local yaml_stat=$(_st_config_get "browserLaunch.enabled"); [ -z "$yaml_stat" ] && yaml_stat="Unknown"
        echo -e "Current Strategy: $current_mode (Config: $yaml_stat)"; echo "----------------------------------------"
        local OPTS=("🚀 Script Takeover" "🍷 SillyTavern Native" "🚫 Disable Auto Redirect" "🔙 Return")
        local CHOICE=$(ui_menu "Select Method" "${OPTS[@]}")
        case "$CHOICE" in
            *"Script"*) _st_config_set "browserLaunch.enabled" "false"; echo "SCRIPT" > "$BROWSER_CONF"; ui_print success "Switched: Script Takeover"; ui_pause ;; 
            *"Native"*) _st_config_set "browserLaunch.enabled" "true"; echo "ST" > "$BROWSER_CONF"; ui_print success "Switched: Native Mode"; ui_pause ;; 
            *"Disable"*) _st_config_set "browserLaunch.enabled" "false"; echo "NONE" > "$BROWSER_CONF"; ui_print success "Auto redirect disabled"; ui_pause ;; 
            *"Return"*) return ;; 
        esac
    done
}

sillytavern_change_port() {
    _st_vars
    local cur=$(_st_get_port)
    local new_p=$(ui_input_validated "Set new port (1024-65535)" "$cur" "numeric")
    [ -z "$new_p" ] && return
    
    if [ "$new_p" -lt 1024 ]; then ui_print error "Port too low"; ui_pause; return; fi
    if _st_config_set "port" "$new_p"; then
        ui_print success "Port changed to $new_p, please restart SillyTavern."
        ui_pause
    fi
}

sillytavern_reset_password() {
    ui_header "Reset Password"
    [ ! -d "$ST_DIR" ] && { ui_print error "SillyTavern not installed"; ui_pause; return; }
    cd "$ST_DIR" || return
    echo -e "${YELLOW}Current user list:${NC}"
    ls -F data/ | grep "/" | grep -v "^_" | sed 's|/||g' | sed 's/^/  - /'
    echo ""
    local u=$(ui_input "Enter username to reset" "default-user" "false")
    local p=$(ui_input "Enter new password" "" "true")
    
    if [[ -n "$u" && -n "$p" ]]; then
        echo ""
        if node recover.js "$u" "$p"; then
            ui_print success "Password reset."
        else
            ui_print error "Reset failed, please verify username is correct."
        fi
    else
        ui_print warn "Operation cancelled."
    fi
    ui_pause
}

sillytavern_configure_proxy() {
    while true; do
        ui_header "API Proxy Configuration"
        local is_enabled=$(_st_config_get requestProxy.enabled)
        local current_url=$(_st_config_get requestProxy.url)
        [ -z "$current_url" ] && current_url="Not Set"
        if [ "$is_enabled" == "true" ]; then echo -e "Status: ${GREEN}Enabled${NC} | Address: ${CYAN}$current_url${NC}"; else echo -e "Status: ${RED}Disabled${NC}"; fi
        echo "----------------------------------------"
        local OPTS=("🔄 Sync System Proxy" "✏️ Manual Input" "🚫 Disable Proxy" "🔙 Return")
        local CHOICE=$(ui_menu "Select Operation" "${OPTS[@]}")
        case "$CHOICE" in
            *"Sync"*) 
                local dyn=$(get_active_proxy "interactive")
                if [ -n "$dyn" ]; then 
                    _st_config_set requestProxy.enabled true
                    _st_config_set requestProxy.url "$dyn"
                    ui_print success "Synced proxy: $dyn"
                else 
                    ui_print warn "No available proxy found, please configure manually."
                fi; ui_pause ;; 
            *"Manual"*) local i=$(ui_input "Proxy address" "" "false"); if [[ "$i" =~ ^http.* ]]; then _st_config_set requestProxy.enabled true; _st_config_set requestProxy.url "$i"; ui_print success "Saved"; else ui_print error "Invalid format"; fi; ui_pause ;; 
            *"Disable"*) _st_config_set requestProxy.enabled false; ui_print success "Disabled"; ui_pause ;; 
            *"Return"*) return ;; 
        esac
    done
}

sillytavern_menu() {
    _st_vars
    if [ ! -d "$ST_DIR" ]; then
        ui_header "SillyTavern"
        ui_print warn "Application not installed."
        if ui_confirm "Install now?"; then sillytavern_install; else return; fi
    fi
    
    while true; do
        _st_vars
        local port=$(_st_get_port)
        local state="stopped"; local text="Stopped"; local info=()
        
        if check_process_smart "$ST_PID_FILE" "node.*server.js"; then
            state="running"
            text="Running"
        fi
        info+=( "Port: $port" )
        
        ui_header "SillyTavern Management Panel"
        ui_status_card "$state" "$text" "${info[@]}"
        
        local CHOICE=$(ui_menu "Action Menu" "🚀 Start/Restart" "🛑 Stop Service" "⚙️  App Config" "🧩 Plugin Manager" "⬇️  Update & Version" "💾 Backup & Restore" "📜 View Logs" "🗑️  Uninstall Module" "🔙 Return")
        case "$CHOICE" in
            *"Start"*) sillytavern_start; ui_pause ;;
            *"Stop"*) sillytavern_stop; ui_print success "Stopped"; ui_pause ;;
            *"Config"*) _st_config_submenu ;;
            *"Plugin"*) app_plugin_menu ;;
            *"Update"*) _st_update_submenu ;;
            *"Backup"*) _st_backup_submenu ;;
            *"Logs"*) safe_log_monitor "$ST_LOG" ;;
            *"Uninstall"*) sillytavern_uninstall && [ $? -eq 2 ] && return ;;
            *"Return"*) return ;;
        esac
    done
}
_st_config_submenu() {
    while true; do
        ui_header "SillyTavern Config Management"
        local opt=$(ui_menu "Select Item" "🌍 One-Click Public Access" "🔧 Config Parameters" "🧠 Runtime Memory Config" "🌐 Browser Launch Method" "🔗 API Proxy Settings" "🔐 Reset Login Password" "🔌 Change Server Port" "🔙 Return")
        case "$opt" in
            *"Public"*) sillytavern_enable_public_access ;; 
            *"Parameters"*) sillytavern_configure_advanced ;; 
            *"Memory"*) sillytavern_configure_memory ;; 
            *"Browser"*) sillytavern_configure_browser ;; 
            *"API"*) sillytavern_configure_proxy ;; 
            *"Password"*) sillytavern_reset_password ;; 
            *"Port"*) sillytavern_change_port ;; 
            *"Return"*) return ;; 
        esac
    done
}

_st_update_submenu() {
    local opt=$(ui_menu "Update Management" "🆕 Check & Update" "⏳ Version Time Machine" "🔙 Cancel")
    case "$opt" in *"Check"*) sillytavern_update ;; *"Time Machine"*) sillytavern_rollback ;; esac
}

_st_backup_submenu() {
    local opt=$(ui_menu "Backup Management" "📤 Backup Data" "📥 Restore Data" "🔙 Cancel")
    case "$opt" in *"Backup"*) sillytavern_backup ;; *"Restore"*) sillytavern_restore ;; esac
}

_st_get_port() {
    _st_vars
    local p=$(_st_config_get port)
    [[ "$p" =~ ^[0-9]+$ ]] && echo "$p" || echo "8000"
}

_st_config_ensure_yq() {
    if ! command -v yq &>/dev/null; then
        source "$TAVX_DIR/core/deps.sh"
        install_yq >/dev/null 2>&1
    fi
}

_st_config_get() {
    _st_vars
    _st_config_ensure_yq
    local key=".$1"
    local file="$ST_DIR/config.yaml"
    [ ! -f "$file" ] && return 1
    
    local val=$(yq "$key" "$file" 2>/dev/null)
    
    if [ "$val" == "null" ] || [ -z "$val" ]; then
        return 1
    else
        echo "$val"
        return 0
    fi
}

_st_config_set() {
    _st_vars
    _st_config_ensure_yq
    local key=".$1"
    local val="$2"
    local file="$ST_DIR/config.yaml"
    [ ! -f "$file" ] && return 1
    
    if [[ "$val" == "true" || "$val" == "false" ]]; then
        yq -i "$key = $val" "$file"
    elif [[ "$val" =~ ^[0-9]+$ ]]; then
        yq -i "$key = $val" "$file"
    else
        yq -i "$key = \"$val\"" "$file"
    fi
}

_st_config_set_batch() {
    _st_vars
    _st_config_ensure_yq
    local json="$1"
    local file="$ST_DIR/config.yaml"
    [ ! -f "$file" ] && return 1
    
    echo "$json" | yq -i '. * load("/dev/stdin")' "$file"
}
