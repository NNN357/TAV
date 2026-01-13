#!/bin/bash
# [METADATA]
# MODULE_ID: gemini
# MODULE_NAME: Gemini Smart Proxy
# MODULE_ENTRY: gemini_menu
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/python_utils.sh"

_gemini_vars() {
    GE_APP_ID="gemini"
    GE_DIR=$(get_app_path "$GE_APP_ID")
    GE_VENV="$GE_DIR/venv"
    GE_LOG="$LOGS_DIR/gemini.log"
    GE_PID="$RUN_DIR/gemini.pid"
    GE_ENV_CONF="$CONFIG_DIR/gemini.env"
    GE_CREDS="$GE_DIR/oauth_creds.json"
    GE_REPO="https://github.com/gzzhongqi/geminicli2api"
    mkdir -p "$GE_DIR"
}

_gemini_check_google() {
    ui_print info "Checking Google connectivity..."
    local proxy=$(get_active_proxy)
    local cmd="curl -I -s --max-time 5 https://www.google.com"
    [ -n "$proxy" ] && cmd="$cmd --proxy $proxy"
    
    if $cmd >/dev/null 2>&1; then return 0; fi
    ui_print error "Cannot connect to Google! Gemini service must work through proxy."
    return 1
}

gemini_install() {
    _gemini_vars
    ui_header "Deploy Gemini Proxy"
    
    # Prepare network strategy in advance
    prepare_network_strategy

    if [ ! -d "$GE_DIR/.git" ]; then
        if ! git_clone_smart "" "$GE_REPO" "$GE_DIR"; then
            ui_print error "Source code download failed."
            return 1
        fi
    else
        ui_print info "Syncing latest code..."
        (cd "$GE_DIR" && git pull)
    fi
    
    if ui_stream_task "Creating virtual environment..." "source \"\$TAVX_DIR/core/python_utils.sh\"; create_venv_smart '$GE_VENV'"; then
        ui_print info "Installing project dependencies..."
        local INSTALL_CMD="source \"\$TAVX_DIR/core/python_utils.sh\"; install_requirements_smart '$GE_VENV' '$GE_DIR/requirements.txt' 'standard'"
        
        if ! ui_stream_task "Installing Python dependencies..." "$INSTALL_CMD"; then
            ui_print error "Dependency installation failed."
            return 1
        fi
    else
        ui_print error "Virtual environment creation failed."
        return 1
    fi
    
    if [ ! -f "$GE_ENV_CONF" ]; then
        echo -e "HOST=0.0.0.0\nPORT=8888\nGEMINI_AUTH_PASSWORD=password" > "$GE_ENV_CONF"
    fi
    ui_print success "Installation complete."
}

gemini_start() {
    _gemini_vars
    [ ! -d "$GE_DIR" ] && { gemini_install || return 1; }
    _gemini_check_google || return 1
    
    gemini_stop
    local port=$(grep "^PORT=" "$GE_ENV_CONF" | cut -d= -f2); [ -z "$port" ] && port=8888
    ln -sf "$GE_ENV_CONF" "$GE_DIR/.env"
    
    if [ ! -f "$GE_CREDS" ]; then
        ui_print error "Credentials not found. Please authorize first."
        ui_pause; return 1
    fi
    
    local proxy=$(get_active_proxy)
    local p_env=""
    [ -n "$proxy" ] && p_env="http_proxy='$proxy' https_proxy='$proxy' all_proxy='$proxy'"
    
    local CMD="cd '$GE_DIR' && source '$GE_VENV/bin/activate' && env $p_env setsid nohup python run.py > '$GE_LOG' 2>&1 & echo \$! > '$GE_PID'"
    
    if ui_spinner "Starting process..." "eval \"$CMD\"" ; then
        sleep 2
        if check_process_smart "$GE_PID" "python.*run.py"; then
            ui_print success "Service started."
        else
            ui_print error "Start failed, please check logs."
            tail -n 5 "$GE_LOG"
        fi
    fi
}

gemini_stop() {
    _gemini_vars
    kill_process_safe "$GE_PID" "python.*run.py"
}

gemini_uninstall() {
    _gemini_vars
    if verify_kill_switch; then
        gemini_stop
        ui_spinner "Cleaning files..." "safe_rm '$GE_DIR' '$GE_ENV_CONF' '$GE_PID' '$GE_LOG'"
        ui_print success "Uninstalled."
        return 2
    fi
}

authenticate_google() {
    _gemini_vars
    [ ! -d "$GE_DIR" ] && { gemini_install || return 1; }
    _gemini_check_google || return 1
    
    if [ -f "$GE_CREDS" ]; then
        if ! ui_confirm "Credentials already exist, re-authenticate?"; then return; fi
        safe_rm "$GE_CREDS"
    fi
    
    gemini_stop
    local proxy=$(get_active_proxy); local p_env=""
    [ -n "$proxy" ] && p_env="http_proxy='$proxy' https_proxy='$proxy'"
    
    local AUTH_LOG="$TMP_DIR/gemini_auth.log"
    local CMD="source '$GE_VENV/bin/activate' && env -u GEMINI_CREDENTIALS GEMINI_AUTH_PASSWORD='init' PYTHONUNBUFFERED=1 $p_env python -u run.py > '$AUTH_LOG' 2>&1 & echo \$! > '$GE_PID'"
    eval "$CMD"
    
    ui_print info "Waiting for authentication link..."
    local url=""
    for i in {1..15}; do
        if grep -q "https://accounts.google.com" "$AUTH_LOG"; then
            url=$(grep -o "https://accounts.google.com[^ ]*" "$AUTH_LOG" | head -n 1 | tr -d '\r\n')
            break
        fi
        sleep 1
    done
    
    if [ -n "$url" ]; then
        open_browser "$url"
        ui_print success "Browser opened, please come back to start service after logging in."
    else
        ui_print error "Get link timed out."
    fi
    ui_pause
}

gemini_menu() {
    while true; do
        _gemini_vars
        ui_header "♊ Gemini Smart Proxy"
        local state="stopped"; local text="Not Running"; local info=()
        if check_process_smart "$GE_PID" "python.*run.py"; then
            state="running"; text="Running"
            local port=$(grep "^PORT=" "$GE_ENV_CONF" 2>/dev/null | cut -d= -f2)
            info+=( "Address: http://127.0.0.1:${port:-8888}/v1" )
        fi
        [ -f "$GE_CREDS" ] && info+=( "Authorized: ✅" ) || info+=( "Authorized: ❌" )
        
        ui_status_card "$state" "$text" "${info[@]}"
        local CHOICE=$(ui_menu "Operation Menu" "🚀 Start/Restart" "🔑 Google Auth" "⚙️  Modify Config" "🛑 Stop Service" "📜 View Logs" "⬆️  Update Code" "🗑️  Uninstall Module" "🔙 Return")
        case "$CHOICE" in
            *"Start"*) gemini_start; ui_pause ;;
            *"Auth"*) authenticate_google ;;
            *"Config"*) 
                local p=$(grep "^PORT=" "$GE_ENV_CONF" | cut -d= -f2)
                local new_p=$(ui_input "New Port" "${p:-8888}" "false")
                if [ -n "$new_p" ]; then
                    write_env_safe "$GE_ENV_CONF" "PORT" "$new_p"
                    ui_print success "Saved"
                fi
                ui_pause ;;
            *"Stop"*) gemini_stop; ui_print success "Stopped"; ui_pause ;;
            *"Logs"*) safe_log_monitor "$GE_LOG" ;;
            *"Update"*) gemini_install ;;
            *"Uninstall"*) gemini_uninstall && [ $? -eq 2 ] && return ;;
            *"Return"*) return ;;
        esac
    done
}
