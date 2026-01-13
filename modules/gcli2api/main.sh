#!/bin/bash
# [METADATA]
# MODULE_ID: gcli2api
# MODULE_NAME: GCLI to API
# MODULE_ENTRY: gcli2api_menu
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/python_utils.sh"

_gcli2api_vars() {
    GCLI_APP_ID="gcli2api"
    GCLI_DIR=$(get_app_path "$GCLI_APP_ID")
    GCLI_VENV="$GCLI_DIR/venv"
    GCLI_LOG="$LOGS_DIR/gcli2api.log"
    GCLI_PID="$RUN_DIR/gcli2api.pid"
    GCLI_CONF="$CONFIG_DIR/gcli2api.conf"
    GCLI_REPO="https://github.com/su-kaka/gcli2api"
}

_gcli2api_load_config() {
    _gcli2api_vars
    GCLI_PORT="7861"
    GCLI_PWD="pwd"
    GCLI_HOST="0.0.0.0"
    [ -f "$GCLI_CONF" ] && source "$GCLI_CONF"
}

gcli2api_install() {
    _gcli2api_vars
    ui_header "Install GCLI2API"
    
    mkdir -p "$GCLI_DIR"
    
    prepare_network_strategy
    
    if [ ! -d "$GCLI_DIR/.git" ]; then
        if ! ui_stream_task "Cloning from GitHub..." "source \"\$TAVX_DIR/core/utils.sh\"; git_clone_smart '-b master' '$GCLI_REPO' '$GCLI_DIR'"; then
            ui_print error "Clone failed."
            return 1
        fi
    else
        ui_print info "Syncing latest code..."
        (cd "$GCLI_DIR" && git pull)
    fi
    
    if ! ui_spinner "Creating virtual environment..." "source \"\$TAVX_DIR/core/python_utils.sh\"; create_venv_smart '$GCLI_VENV'"; then
        ui_print error "Virtual environment creation failed."
        return 1
    fi
    
    local INSTALL_CMD="source \"\$TAVX_DIR/core/python_utils.sh\"; install_requirements_smart '$GCLI_VENV' '$GCLI_DIR/requirements.txt' 'standard'"
    if ! ui_stream_task "Installing Pip dependencies (may take a while)..." "$INSTALL_CMD"; then
        ui_print error "Dependency installation failed."
        return 1
    fi
    
    ui_print success "GCLI2API deployment complete."
}

gcli2api_start() {
    _gcli2api_load_config
    [ ! -d "$GCLI_DIR" ] && { gcli2api_install || return 1; }
    
    if [ ! -f "$GCLI_DIR/web.py" ]; then
        ui_print error "Core program file missing (web.py), please try [Update/Reinstall]."
        ui_pause; return 1
    fi

    gcli2api_stop
    pkill -9 -f "python.*web.py" 2>/dev/null
    local CMD="(cd '$GCLI_DIR' && source '$GCLI_VENV/bin/activate' && export PORT='$GCLI_PORT' PASSWORD='$GCLI_PWD' HOST='$GCLI_HOST' && setsid nohup python web.py >> '$GCLI_LOG' 2>&1 </dev/null & echo \$! > '$GCLI_PID')"
    
    ui_print info "Starting service..."
    eval "$CMD"
    sleep 2
    
    local real_pid=$(pgrep -f "python.*web.py" | grep -v "grep" | head -n 1)
    
    if [ -n "$real_pid" ]; then
        echo "$real_pid" > "$GCLI_PID"
        ui_print success "Started successfully!"
    else
        ui_print error "Start failed, please check logs."
        tail -n 5 "$GCLI_LOG"
    fi
}

gcli2api_stop() {
    _gcli2api_vars
    kill_process_safe "$GCLI_PID" "python.*web.py"
}

gcli2api_uninstall() {
    _gcli2api_vars
    if verify_kill_switch; then
        gcli2api_stop
        safe_rm "$GCLI_DIR" "$GCLI_LOG" "$GCLI_CONF" "$GCLI_PID"
        ui_print success "Uninstalled."
        return 2
    fi
}

gcli2api_menu() {
    while true; do
        _gcli2api_load_config
        ui_header "🌐 GCLI to API"
        local state="stopped"; local text="Not Running"; local info=()
        if check_process_smart "$GCLI_PID" "python.*web.py"; then
            state="running"; text="Running"
            info+=( "Address: http://127.0.0.1:$GCLI_PORT" "Password: $GCLI_PWD" )
        fi
        ui_status_card "$state" "$text" "${info[@]}"
        
        local CHOICE=$(ui_menu "Operation Menu" "🚀 Start/Restart" "🛑 Stop Service" "⚙️  Modify Config" "📜 View Logs" "⬆️  Update/Reinstall" "🗑️  Uninstall Module" "🔙 Return")
        case "$CHOICE" in
            *"Start"*) gcli2api_start; ui_pause ;; 
            *"Stop"*) gcli2api_stop; ui_print success "Stopped"; ui_pause ;; 
            *"Config"*) 
                GCLI_PORT=$(ui_input_validated "New Port" "$GCLI_PORT" "numeric")
                GCLI_PWD=$(ui_input "New Password" "$GCLI_PWD" "false")
                
                write_env_safe "$GCLI_CONF" "GCLI_PORT" "$GCLI_PORT"
                write_env_safe "$GCLI_CONF" "GCLI_PWD" "$GCLI_PWD"
                write_env_safe "$GCLI_CONF" "GCLI_HOST" "$GCLI_HOST"
                
                ui_print success "Config saved"; ui_pause ;; 
            *"Logs"*) safe_log_monitor "$GCLI_LOG" ;; 
            *"Update"*) gcli2api_install ;; 
            *"Uninstall"*) gcli2api_uninstall && [ $? -eq 2 ] && return ;; 
            *"Return"*) return ;; 
        esac
    done
}
