#!/bin/bash
# [METADATA]
# MODULE_ID: cloudflare
# MODULE_NAME: Cloudflare Tunnel
# MODULE_ENTRY: cf_menu
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
[ -f "$TAVX_DIR/modules/cloudflare/api_utils.sh" ] && source "$TAVX_DIR/modules/cloudflare/api_utils.sh"
_cf_vars() {
    CF_APP_ID="cloudflare"
    CF_DIR=$(get_app_path "$CF_APP_ID")
    if [ "$OS_TYPE" == "TERMUX" ]; then
        CF_BIN="cloudflared"
    else
        CF_BIN="$CF_DIR/cloudflared"
    fi
    
    CF_USER_DATA="$HOME/.cloudflared"
    CF_LOG_DIR="$LOGS_DIR/cf_tunnels"
    CF_RUN_DIR="$RUN_DIR"
    CF_API_TOKEN_FILE="$CONFIG_DIR/cf_api_token"
    
    mkdir -p "$CF_DIR" "$CF_USER_DATA" "$CF_LOG_DIR" "$CF_RUN_DIR"
}

cloudflare_install() {
    _cf_vars
    
    if [ "$OS_TYPE" == "TERMUX" ]; then
        if command -v cloudflared &>/dev/null; then 
            ui_print info "Cloudflared already installed."
            mkdir -p "$CF_DIR"
            touch "$CF_DIR/.installed"
            return 0
        fi
        ui_header "Install Cloudflared (Termux)"
        if sys_install_pkg "cloudflared"; then
            ui_print success "Installation complete."
            mkdir -p "$CF_DIR"
            touch "$CF_DIR/.installed"
            return 0
        else
            ui_print error "Installation failed."
            return 1
        fi
    else
        if [ -f "$CF_BIN" ]; then return 0; fi
        ui_header "Install Cloudflared (Linux)"
        local arch=$(uname -m)
        local dl="amd64"
        [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && dl="arm64"
        [[ "$arch" == "arm" || "$arch" == "armv7l" ]] && dl="arm"
        
        local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$dl"
        local cmd="source \"\$TAVX_DIR/core/utils.sh\"; download_file_smart '\''$url'\' '$CF_BIN'"
        if ui_stream_task "Downloading core component..." "$cmd"; then
            chmod +x "$CF_BIN"
            ui_print success "Installation complete."
            return 0
        else
            ui_print error "Download failed."
            return 1
        fi
    fi
}

cf_import_cert() {
    _cf_vars
    ui_header "Manual Import Credentials"
    echo -e "Please select the downloaded ${CYAN}cert.pem${NC} file."
    echo "----------------------------------------"
    
    local selected_file=""
    if [ "$HAS_GUM" = true ]; then
        selected_file=$(gum file --cursor.foreground="$C_PINK" "$HOME")
    else
        selected_file=$(ui_input "Enter file absolute path" "" "false")
    fi
    
    [ -z "$selected_file" ] && return 1
    [ ! -f "$selected_file" ] && { ui_print error "File doesn't exist: $selected_file"; ui_pause; return 1; }
    
    if ! grep -q "PRIVATE KEY" "$selected_file"; then
        ui_print error "Invalid certificate file (private key identifier not detected)."
        ui_pause; return 1
    fi
    
    ui_spinner "Importing credentials..." "cp '$selected_file' '$CF_USER_DATA/cert.pem'"
    ui_print success "Import successful!"
    return 0
}

cf_login() {
    _cf_vars
    if [ "$OS_TYPE" == "TERMUX" ]; then
        command -v cloudflared &>/dev/null || cloudflare_install || return 1
    else
        [ -f "$CF_BIN" ] || cloudflare_install || return 1
    fi
    
    ui_header "Cloudflare Login Authorization"
    echo -e "${YELLOW}Important Tips:${NC}"
    echo -e "1. Please confirm browser is logged into: ${CYAN}dash.cloudflare.com${NC}"
    echo -e "2. If auto-callback fails, browser will download ${CYAN}cert.pem${NC} file."
    echo -e "3. Script will auto-scan download directory, no need to move manually."
    echo ""
    
    local ACTION=$(ui_menu "Please select authorization method" "🚀 Launch Browser Authorization (Recommended)" "📂 Manual Import cert.pem" "🔙 Return")
    case "$ACTION" in
        *"Manual"*) cf_import_cert; return $? ;;
        *"Return"*) return 0 ;;
    esac
    
    if [ -f "$CF_USER_DATA/cert.pem" ]; then
        ui_print warn "Existing login credentials detected."
        if ! ui_confirm "Re-authorizing will overwrite existing certificate, are you sure?"; then return 0; fi
        rm -f "$CF_USER_DATA/cert.pem"
    fi
    
    ui_print info "Starting authorization process..."
    local login_log="$TMP_DIR/cf_login.log"
    rm -f "$login_log"
    
    "$CF_BIN" tunnel login > "$login_log" 2>&1 &
    local login_pid=$!
    
    ui_print info "Waiting for authorization link..."
    local url_found=false
    while true; do
        if [ -f "$CF_USER_DATA/cert.pem" ]; then
            ui_print success "Certificate auto-generated detected!"
            break
        fi
        
        if ! kill -0 "$login_pid" 2>/dev/null; then
            ui_print warn "Authorization process ended (may be callback failure converted to file download)."
            break
        fi
        
        if [ "$url_found" = false ] && grep -q "https://" "$login_log"; then
            local login_url=$(grep -oE "https://[a-zA-Z0-9./?=_-]+" "$login_log" | head -n 1)
            if [ -n "$login_url" ]; then
                ui_print success "Found authorization link, opening browser..."
                open_browser "$login_url"
                url_found=true
                ui_print info "Please complete authorization in browser, script will auto-scan after success..."
            fi
        fi
        sleep 2
    done
    
    kill "$login_pid" 2>/dev/null
    wait "$login_pid" 2>/dev/null
    
    if [ ! -f "$CF_USER_DATA/cert.pem" ]; then
        ui_print info "Auto-scanning download directory..."
        local scan_paths=(
            "$HOME/storage/downloads/cert*.pem"
            "$HOME/downloads/cert*.pem"
            "/sdcard/Download/cert*.pem"
        )
        
        local latest_file=""
        for pattern in "${scan_paths[@]}"; do
            local found=$(ls -t $pattern 2>/dev/null | head -n 1)
            if [ -n "$found" ]; then
                if [ -z "$latest_file" ] || [ "$found" -nt "$latest_file" ]; then
                    latest_file="$found"
                fi
            fi
        done
        
        if [ -n "$latest_file" ]; then
            ui_print info "Found latest credentials: $(basename "$latest_file")"
            mv "$latest_file" "$CF_USER_DATA/cert.pem"
            ui_print success "Credentials auto-migrated!"
        fi
    fi

    if [ -f "$CF_USER_DATA/cert.pem" ]; then
        ui_print success "Login successful!"
        return 0
    else
        ui_print error "Auto-fetch failed."
        if ui_confirm "Manually select downloaded cert.pem file?"; then
            cf_import_cert
            return $?
        fi
        return 1
    fi
}

cf_quick_tunnel() {
    _cf_vars
    if [ "$OS_TYPE" == "TERMUX" ]; then
        command -v cloudflared &>/dev/null || cloudflare_install || return 1
    else
        [ -f "$CF_BIN" ] || cloudflare_install || return 1
    fi
    
    ui_header "Quick Tunnel (No Login Required)"
    echo -e "${YELLOW}Note: Quick tunnel generates a random domain, valid for 24 hours.${NC}"
    echo ""
    
    local port=$(ui_input "Enter local port to expose" "8000" "false")
    [[ ! "$port" =~ ^[0-9]+$ ]] && { ui_print error "Invalid port number."; ui_pause; return 1; }
    
    local log_file="$CF_LOG_DIR/quick_tunnel.log"
    local pid_file="$CF_RUN_DIR/cf_quick.pid"
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        ui_print warn "Quick tunnel already running."
        if ui_confirm "Stop existing tunnel and start new one?"; then
            kill "$(cat "$pid_file")" 2>/dev/null
            rm -f "$pid_file"
        else
            return 0
        fi
    fi
    
    rm -f "$log_file"
    ui_print info "Starting quick tunnel..."
    
    nohup "$CF_BIN" tunnel --url "http://localhost:$port" > "$log_file" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$pid_file"
    
    ui_print info "Waiting for tunnel URL..."
    local url=""
    for i in {1..30}; do
        if [ -f "$log_file" ]; then
            url=$(grep -oE "https://[a-zA-Z0-9-]+\.trycloudflare\.com" "$log_file" | head -n 1)
            if [ -n "$url" ]; then break; fi
        fi
        sleep 1
    done
    
    if [ -n "$url" ]; then
        ui_print success "Tunnel started successfully!"
        echo ""
        echo -e "Access URL: ${GREEN}$url${NC}"
        echo -e "Local Port: ${CYAN}$port${NC}"
        echo -e "Log File: $log_file"
        echo ""
        if ui_confirm "Open in browser?"; then
            open_browser "$url"
        fi
    else
        ui_print error "Failed to get tunnel URL, please check log."
        kill "$tunnel_pid" 2>/dev/null
        rm -f "$pid_file"
    fi
    ui_pause
}

cf_add_ingress() {
    _cf_vars
    [ ! -f "$CF_USER_DATA/cert.pem" ] && { ui_print error "Please login first."; ui_pause; return 1; }
    
    ui_header "Add Ingress Rule"
    
    local tunnels=($(ls "$CF_USER_DATA"/*.json 2>/dev/null | xargs -I {} basename {} .json))
    if [ ${#tunnels[@]} -eq 0 ]; then
        ui_print error "No tunnels found. Please create a named tunnel first."
        ui_pause; return 1
    fi
    
    local tunnel_name=$(ui_menu "Select tunnel" "${tunnels[@]}" "🔙 Cancel")
    [[ "$tunnel_name" == *"Cancel"* ]] && return 0
    
    local hostname=$(ui_input "Enter domain (e.g., app.example.com)" "" "false")
    [ -z "$hostname" ] && return 1
    
    local service=$(ui_input "Enter backend service (e.g., http://localhost:8000)" "http://localhost:8000" "false")
    [ -z "$service" ] && return 1
    
    local config_file="$CF_USER_DATA/${tunnel_name}.yml"
    
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << EOF
tunnel: $tunnel_name
credentials-file: $CF_USER_DATA/${tunnel_name}.json
ingress:
  - hostname: $hostname
    service: $service
  - service: http_status:404
EOF
    else
        local temp_file="$TMP_DIR/cf_config_temp.yml"
        head -n -2 "$config_file" > "$temp_file"
        echo "  - hostname: $hostname" >> "$temp_file"
        echo "    service: $service" >> "$temp_file"
        echo "  - service: http_status:404" >> "$temp_file"
        mv "$temp_file" "$config_file"
    fi
    
    ui_print success "Ingress rule added!"
    echo -e "Domain: ${CYAN}$hostname${NC} -> ${GREEN}$service${NC}"
    
    if ui_confirm "Configure DNS record now?"; then
        ui_spinner "Creating DNS record..." "$CF_BIN tunnel route dns $tunnel_name $hostname"
    fi
    ui_pause
}

cf_del_ingress() {
    _cf_vars
    ui_header "Delete Ingress Rule"
    
    local configs=($(ls "$CF_USER_DATA"/*.yml 2>/dev/null))
    if [ ${#configs[@]} -eq 0 ]; then
        ui_print error "No tunnel configurations found."
        ui_pause; return 1
    fi
    
    local config_names=()
    for c in "${configs[@]}"; do
        config_names+=("$(basename "$c" .yml)")
    done
    
    local tunnel_name=$(ui_menu "Select tunnel" "${config_names[@]}" "🔙 Cancel")
    [[ "$tunnel_name" == *"Cancel"* ]] && return 0
    
    local config_file="$CF_USER_DATA/${tunnel_name}.yml"
    
    local hostnames=($(grep "hostname:" "$config_file" | awk '{print $2}'))
    if [ ${#hostnames[@]} -eq 0 ]; then
        ui_print warn "No ingress rules found in this tunnel."
        ui_pause; return 0
    fi
    
    local hostname=$(ui_menu "Select rule to delete" "${hostnames[@]}" "🔙 Cancel")
    [[ "$hostname" == *"Cancel"* ]] && return 0
    
    local temp_file="$TMP_DIR/cf_config_temp.yml"
    grep -v "hostname: $hostname" "$config_file" | grep -v -A1 "hostname: $hostname" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    ui_print success "Ingress rule deleted: $hostname"
    ui_pause
}

cf_edit_ingress() {
    _cf_vars
    ui_header "Edit Ingress Rules"
    
    local configs=($(ls "$CF_USER_DATA"/*.yml 2>/dev/null))
    if [ ${#configs[@]} -eq 0 ]; then
        ui_print error "No tunnel configurations found."
        ui_pause; return 1
    fi
    
    local config_names=()
    for c in "${configs[@]}"; do
        config_names+=("$(basename "$c" .yml)")
    done
    
    local tunnel_name=$(ui_menu "Select tunnel to edit" "${config_names[@]}" "🔙 Cancel")
    [[ "$tunnel_name" == *"Cancel"* ]] && return 0
    
    local config_file="$CF_USER_DATA/${tunnel_name}.yml"
    
    if command -v nano &>/dev/null; then
        nano "$config_file"
    elif command -v vim &>/dev/null; then
        vim "$config_file"
    else
        ui_print warn "No text editor found. Displaying file content:"
        echo "----------------------------------------"
        cat "$config_file"
        echo "----------------------------------------"
        ui_print info "Please edit manually: $config_file"
    fi
    ui_pause
}

cf_create_named_tunnel() {
    _cf_vars
    [ ! -f "$CF_USER_DATA/cert.pem" ] && { ui_print error "Please login first."; ui_pause; return 1; }
    
    ui_header "Create Named Tunnel"
    echo -e "${YELLOW}Named tunnels support custom domains and persistent configuration.${NC}"
    echo ""
    
    local tunnel_name=$(ui_input "Enter tunnel name (alphanumeric)" "" "false")
    [[ ! "$tunnel_name" =~ ^[a-zA-Z0-9_-]+$ ]] && { ui_print error "Invalid tunnel name."; ui_pause; return 1; }
    
    if [ -f "$CF_USER_DATA/${tunnel_name}.json" ]; then
        ui_print warn "Tunnel '$tunnel_name' already exists."
        ui_pause; return 1
    fi
    
    if ui_spinner "Creating tunnel..." "$CF_BIN tunnel create $tunnel_name"; then
        ui_print success "Tunnel created: $tunnel_name"
        
        if ui_confirm "Add ingress rule now?"; then
            cf_add_ingress
        fi
    else
        ui_print error "Failed to create tunnel."
    fi
    ui_pause
}

_start_named_tunnel() {
    _cf_vars
    local tunnel_name=$1
    local config_file="$CF_USER_DATA/${tunnel_name}.yml"
    local log_file="$CF_LOG_DIR/${tunnel_name}.log"
    local pid_file="$CF_RUN_DIR/cf_${tunnel_name}.pid"
    
    if [ ! -f "$config_file" ]; then
        ui_print error "Configuration file not found: $config_file"
        return 1
    fi
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        ui_print warn "Tunnel '$tunnel_name' already running."
        return 0
    fi
    
    rm -f "$log_file"
    nohup "$CF_BIN" tunnel --config "$config_file" run > "$log_file" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$pid_file"
    
    sleep 2
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        ui_print success "Tunnel '$tunnel_name' started."
        return 0
    else
        ui_print error "Tunnel failed to start, check log: $log_file"
        rm -f "$pid_file"
        return 1
    fi
}

cf_manage_tunnels() {
    _cf_vars
    while true; do
        ui_header "Tunnel Management"
        
        local tunnels=($(ls "$CF_USER_DATA"/*.json 2>/dev/null | xargs -I {} basename {} .json))
        
        if [ ${#tunnels[@]} -eq 0 ]; then
            ui_print warn "No tunnels found."
            if ui_confirm "Create a new tunnel?"; then
                cf_create_named_tunnel
            else
                return
            fi
            continue
        fi
        
        echo -e "${CYAN}Existing Tunnels:${NC}"
        echo "----------------------------------------"
        
        local MENU_ITEMS=()
        for t in "${tunnels[@]}"; do
            local pid_file="$CF_RUN_DIR/cf_${t}.pid"
            local status="⚫ Stopped"
            if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
                status="🟢 Running"
            fi
            MENU_ITEMS+=("$status | $t")
        done
        MENU_ITEMS+=("➕ Create New Tunnel" "🔙 Return")
        
        local CHOICE=$(ui_menu "Select tunnel" "${MENU_ITEMS[@]}")
        
        case "$CHOICE" in
            *"Create"*) cf_create_named_tunnel ;;
            *"Return"*) return ;;
            *)
                local selected_tunnel=$(echo "$CHOICE" | awk -F'|' '{print $2}' | xargs)
                if [ -n "$selected_tunnel" ]; then
                    _tunnel_action_menu "$selected_tunnel"
                fi
                ;;
        esac
    done
}

_tunnel_action_menu() {
    local tunnel_name=$1
    _cf_vars
    
    while true; do
        ui_header "Tunnel: $tunnel_name"
        
        local pid_file="$CF_RUN_DIR/cf_${tunnel_name}.pid"
        local config_file="$CF_USER_DATA/${tunnel_name}.yml"
        local log_file="$CF_LOG_DIR/${tunnel_name}.log"
        
        local status="Stopped"
        if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            status="Running (PID: $(cat "$pid_file"))"
        fi
        
        echo -e "Status: ${CYAN}$status${NC}"
        echo -e "Config: $config_file"
        echo "----------------------------------------"
        
        if [ -f "$config_file" ]; then
            echo -e "${YELLOW}Ingress Rules:${NC}"
            grep "hostname:" "$config_file" | while read -r line; do
                echo "  - $line"
            done
            echo ""
        fi
        
        local OPTS=("🚀 Start Tunnel" "🛑 Stop Tunnel" "➕ Add Ingress" "➖ Delete Ingress" "✏️ Edit Config" "📜 View Log" "🗑️ Delete Tunnel" "🔙 Return")
        local ACTION=$(ui_menu "Select action" "${OPTS[@]}")
        
        case "$ACTION" in
            *"Start"*)
                _start_named_tunnel "$tunnel_name"
                ui_pause
                ;;
            *"Stop"*)
                if [ -f "$pid_file" ]; then
                    kill "$(cat "$pid_file")" 2>/dev/null
                    rm -f "$pid_file"
                    ui_print success "Tunnel stopped."
                else
                    ui_print warn "Tunnel not running."
                fi
                ui_pause
                ;;
            *"Add Ingress"*)
                cf_add_ingress
                ;;
            *"Delete Ingress"*)
                cf_del_ingress
                ;;
            *"Edit"*)
                cf_edit_ingress
                ;;
            *"View Log"*)
                if [ -f "$log_file" ]; then
                    safe_log_monitor "$log_file"
                else
                    ui_print warn "Log file not found."
                    ui_pause
                fi
                ;;
            *"Delete Tunnel"*)
                ui_print warn "This will permanently delete the tunnel!"
                if ui_confirm "Are you sure?"; then
                    if [ -f "$pid_file" ]; then
                        kill "$(cat "$pid_file")" 2>/dev/null
                        rm -f "$pid_file"
                    fi
                    "$CF_BIN" tunnel delete "$tunnel_name" 2>/dev/null
                    rm -f "$config_file" "$CF_USER_DATA/${tunnel_name}.json"
                    ui_print success "Tunnel deleted."
                    ui_pause
                    return
                fi
                ;;
            *"Return"*)
                return
                ;;
        esac
    done
}

cf_stop_all() {
    _cf_vars
    ui_header "Stop All Tunnels"
    
    local stopped=0
    for pid_file in "$CF_RUN_DIR"/cf_*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                ((stopped++))
            fi
            rm -f "$pid_file"
        fi
    done
    
    pkill -f "cloudflared tunnel" 2>/dev/null
    
    if [ $stopped -gt 0 ]; then
        ui_print success "Stopped $stopped tunnel(s)."
    else
        ui_print info "No running tunnels found."
    fi
    ui_pause
}

cf_menu() {
    _cf_vars
    
    while true; do
        ui_header "Cloudflare Tunnel"
        
        local quick_status="⚫ Stopped"
        if [ -f "$CF_RUN_DIR/cf_quick.pid" ] && kill -0 "$(cat "$CF_RUN_DIR/cf_quick.pid")" 2>/dev/null; then
            quick_status="🟢 Running"
        fi
        
        local login_status="❌ Not Logged In"
        if [ -f "$CF_USER_DATA/cert.pem" ]; then
            login_status="✅ Logged In"
        fi
        
        echo -e "Login Status: ${CYAN}$login_status${NC}"
        echo -e "Quick Tunnel: ${CYAN}$quick_status${NC}"
        echo "----------------------------------------"
        
        local OPTS=(
            "🚀 Quick Tunnel (No Login)"
            "🔐 Login Authorization"
            "📦 Manage Named Tunnels"
            "🛑 Stop All Tunnels"
            "🔙 Return"
        )
        
        local CHOICE=$(ui_menu "Select operation" "${OPTS[@]}")
        
        case "$CHOICE" in
            *"Quick"*) cf_quick_tunnel ;;
            *"Login"*) cf_login ;;
            *"Named"*) cf_manage_tunnels ;;
            *"Stop All"*) cf_stop_all ;;
            *"Return"*) return ;;
        esac
    done
}
