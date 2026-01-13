#!/bin/bash
# [METADATA]
# MODULE_ID: clewd
# MODULE_NAME: ClewdR Manager
# MODULE_ENTRY: clewd_menu
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

_clewd_vars() {
    CL_APP_ID="clewd"
    CL_DIR=$(get_app_path "$CL_APP_ID")
    CL_LOG="$LOGS_DIR/clewd.log"
    CL_PID="$RUN_DIR/clewd.pid"
    CL_CONF="$CL_DIR/config.js"
    CL_SECRETS="$CONFIG_DIR/clewd_secrets.conf"
    mkdir -p "$CL_DIR"
}

clewd_install() {
    _clewd_vars
    ui_header "Install Clewd (Rust Version)" 
    
    local arch=$(uname -m)
    local asset_pattern="linux-x86_64"
    [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && asset_pattern="android-aarch64"
    
    ui_print info "Fetching version info ($asset_pattern)..."
    auto_load_proxy_env
    
    local api_url="https://api.github.com/repos/Xerxes-2/clewdr/releases/latest"
    local json=$(curl -s -m 10 "$api_url")
    
    if [ -z "$json" ] || [[ "$json" == *"rate limit"* ]]; then
        ui_print error "GitHub API request failed (may have hit rate limit)."
        ui_pause; return 1
    fi

    local download_url=$(echo "$json" | yq -p json '.assets[] | select(.name | contains("'"$asset_pattern"'")) | .browser_download_url' 2>/dev/null | head -n 1)
    
    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        ui_print error "Cannot parse download URL from API. Architecture: $asset_pattern"
        ui_pause; return 1
    fi
    
    local tmp_file="$TMP_DIR/clewdr_dist.zip"
    local DL_CMD="source \"$TAVX_DIR/core/utils.sh\"; download_file_smart '$download_url' '$tmp_file' 'false'"
    
    if ui_stream_task "Downloading release package..." "$DL_CMD"; then
        ui_print info "Extracting..."
        unzip -q -o "$tmp_file" -d "$CL_DIR"
        chmod +x "$CL_DIR"/* 2>/dev/null
        
        if [ ! -f "$CL_DIR/clewdr" ]; then
            local bin_path=$(find "$CL_DIR" -name "clewdr" -type f | head -n 1)
            [ -n "$bin_path" ] && mv "$bin_path" "$CL_DIR/clewdr"
        fi
        
        safe_rm "$tmp_file"
        ui_print success "Installation complete."
    else
        ui_print error "Installation failed."
        ui_pause; return 1
    fi
}

clewd_start() {
    _clewd_vars
    if [ ! -f "$CL_DIR/clewdr" ] && [ ! -f "$CL_DIR/clewd.js" ]; then
        if ui_confirm "Program not detected, install now?"; then clewd_install || return 1; else return 1; fi
    fi
    
    ui_header "Start Clewd"
    cd "$CL_DIR" || return 1
    
    local RUN_CMD=""
    if [ -f "clewdr" ]; then RUN_CMD="./clewdr"
    elif [ -f "clewd.js" ]; then RUN_CMD="node clewd.js"
    fi

    clewd_stop
    echo "--- Clewd Start $(date) --- " > "$CL_LOG"
    local START_CMD="setsid nohup $RUN_CMD >> '$CL_LOG' 2>&1 & echo \$! > '$CL_PID'"
    
    if ui_spinner "Starting background service..." "eval \"$START_CMD\" "; then
        sleep 2
        if check_process_smart "$CL_PID" "clewdr|node.*clewd\.js"; then
            local API_PASS=$(grep -iE "password:|Pass:" "$CL_LOG" | head -n 1 | awk -F': ' '{print $2}' | tr -d ' ')
            [ -z "$API_PASS" ] && API_PASS=$(grep -E "API Password:|Pass:" "$CL_LOG" | head -n 1 | awk '{print $NF}')
            if [ -n "$API_PASS" ]; then echo "API_PASS=$API_PASS" > "$CL_SECRETS"; fi
            ui_print success "Service started!"
        else
            ui_print error "Start failed, process not persisted."
            ui_pause; return 1
        fi
    fi
}

clewd_stop() {
    _clewd_vars
    kill_process_safe "$CL_PID" "clewdr|node.*clewd\.js"
    pkill -f "clewdr" 2>/dev/null
    pkill -f "node clewd.js" 2>/dev/null
}

clewd_uninstall() {
    _clewd_vars
    ui_header "Uninstall Clewd"
    if ! verify_kill_switch; then return; fi
    
    clewd_stop
    if ui_spinner "Cleaning up..." "safe_rm '$CL_DIR' '$CL_PID'"; then
        ui_print success "Module data uninstalled."
        return 2 
    fi
}

clewd_menu() {
    while true; do
        _clewd_vars
        ui_header "Clewd AI Reverse Proxy Manager"
        
        local state="stopped"; local text="Stopped"; local info=()
        if check_process_smart "$CL_PID" "clewdr|node.*clewd\.js"; then
            state="running"; text="Running"
            local pass="Unknown"
            if [ -f "$CL_SECRETS" ]; then
                pass=$(grep "^API_PASS=" "$CL_SECRETS" | cut -d'=' -f2)
                [ -z "$pass" ] && pass="Unknown"
            fi
            
            local port="8444"
            [ -f "$CL_LOG" ] && grep -q "8484" "$CL_LOG" && port="8484"
            
            info+=( "Endpoint: http://127.0.0.1:$port/v1" "Key: $pass" )
        else
            info+=( "Tip: Please start service first" )
        fi
        
        ui_status_card "$state" "$text" "${info[@]}"
        local CHOICE=$(ui_menu "Please select operation" "🚀 Start/Restart" "🔑 View Password" "📜 View Logs" "🛑 Stop Service" "📥 Update/Reinstall" "🗑️  Uninstall Module" "🔙 Return")
        case "$CHOICE" in
            *"Start"*) clewd_start ;; 
            *"Password"*) 
                if [ -f "$CL_LOG" ]; then
                    ui_header "Clewd Runtime Password"
                    grep -iE "password|pass" "$CL_LOG" | head -n 10
                else
                    ui_print warn "Log file doesn't exist."
                fi
                ui_pause ;; 
            *"Logs"*) safe_log_monitor "$CL_LOG" ;; 
            *"Stop"*) clewd_stop; ui_print success "Stopped"; ui_pause ;; 
            *"Update"*) clewd_install ;; 
            *"Uninstall"*) clewd_uninstall && [ $? -eq 2 ] && return ;; 
            *"Return"*) return ;; 
        esac
    done
}
