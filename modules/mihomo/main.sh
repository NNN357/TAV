#!/bin/bash
# [METADATA]
# MODULE_ID: mihomo
# MODULE_NAME: Mihomo Proxy Core
# MODULE_ENTRY: mihomo_menu
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

_mihomo_vars() {
    MIHOMO_APP_ID="mihomo"
    MIHOMO_DIR=$(get_app_path "$MIHOMO_APP_ID")
    MIHOMO_BIN="$MIHOMO_DIR/mihomo"
    MIHOMO_CONF="$MIHOMO_DIR/config.yaml"
    MIHOMO_LOG="$LOGS_DIR/mihomo.log"
    MIHOMO_PID="$RUN_DIR/mihomo.pid"
    MIHOMO_SUBS="$CONFIG_DIR/mihomo_subs.list"
    MIHOMO_SECRET_CONF="$CONFIG_DIR/mihomo_secret.conf"
    MIHOMO_PATCH="$CONFIG_DIR/mihomo_patch.yaml"
    MIHOMO_VER="v1.19.18"
}

mihomo_install() {
    _mihomo_vars
    ui_header "Install/Update Mihomo Core"
    mkdir -p "$MIHOMO_DIR"
    
    local arch=$(uname -m)
    local dl_arch="amd64"
    [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && dl_arch="arm64"

    local filename="mihomo-linux-${dl_arch}-${MIHOMO_VER}.gz"
    local url="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VER}/${filename}"
    local tmp_gz="$TMP_DIR/$filename"
    
    local CMD="source '$TAVX_DIR/core/utils.sh'; download_file_smart '$url' '$tmp_gz' 'true' && gzip -d -f '$tmp_gz' && mv '${tmp_gz%.gz}' '$MIHOMO_BIN' && chmod +x '$MIHOMO_BIN'"

    if ! ui_stream_task "Deploying core binary..." "$CMD"; then
        ui_print error "Download failed."
        return 1
    fi

    local ui_dir="$MIHOMO_DIR/ui"
    if [ ! -d "$ui_dir" ]; then
        ui_print info "Deploying local WebUI..."
        sys_install_pkg "unzip"
        local ui_url="https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        local tmp_ui="$TMP_DIR/ui.zip"
        local UI_CMD="source '$TAVX_DIR/core/utils.sh'; download_file_smart '$ui_url' '$tmp_ui' 'true' && unzip -o '$tmp_ui' -d '$MIHOMO_DIR' && safe_rm '$tmp_ui'"
        
        if ui_stream_task "Downloading panel resources..." "$UI_CMD"; then
            local extracted_dir=$(find "$MIHOMO_DIR" -maxdepth 1 -type d -name "metacubexd-*" | head -n 1)
            [ -n "$extracted_dir" ] && mv "$extracted_dir" "$ui_dir"
            ui_print success "WebUI ready."
        fi
    fi
}

mihomo_start() {
    _mihomo_vars
    [ ! -f "$MIHOMO_BIN" ] && { mihomo_install || return 1; }
    
    if [ ! -s "$MIHOMO_SUBS" ]; then
        ui_print warn "No subscriptions added yet."
        return 1
    fi
    
    local secret=""
    [ -f "$MIHOMO_SECRET_CONF" ] && secret=$(cat "$MIHOMO_SECRET_CONF")
    
    mkdir -p "$MIHOMO_DIR/proxy_providers"
    cat > "$MIHOMO_CONF" <<EOF
port: 17890
socks-port: 17891
allow-lan: true
mode: rule
log-level: warning
external-controller: 0.0.0.0:19090
external-ui: ui
secret: "$secret"
EOF

    echo "proxy-providers:" >> "$MIHOMO_CONF"
    local provider_names=()
    local i=1
    while IFS= read -r url; do
        [[ -z "$url" || "$url" =~ ^# ]] && continue
        local name="Sub$i"
        provider_names+=("$name")
        cat >> "$MIHOMO_CONF" <<EOF
  $name:
    type: http
    url: "$url"
    path: ./proxy_providers/sub_$i.yaml
    interval: 3600
    proxy: DIRECT
    override:
      additional-http-headers:
        User-Agent: "ClashMeta"
    health-check:
      enable: true
      interval: 600
      url: http://www.gstatic.com/generate_204
EOF
        ((i++))
    done < "$MIHOMO_SUBS"

    local use_list=$(printf ", %s" "${provider_names[@]}")
    use_list=${use_list:2}
    
    cat >> "$MIHOMO_CONF" <<EOF
proxy-groups:
  - name: "🚀 Node Select"
    type: select
    use: [$use_list]
    proxies: [DIRECT]
rules:
  - MATCH,🚀 Node Select
EOF

    if [ -f "$MIHOMO_PATCH" ] && command -v yq &>/dev/null; then
        ui_print info "Custom config patch detected, merging..."
        yq -i '. *= load("'$MIHOMO_PATCH'")' "$MIHOMO_CONF"
        
        if [ $? -eq 0 ]; then
            ui_print success "Patch applied successfully."
        else
            ui_print error "Patch application failed, please check YAML syntax."
        fi
    fi

    mihomo_stop
    echo "--- Mihomo Start $(date) --- " > "$MIHOMO_LOG"
    
    ui_print info "Starting Mihomo core service..."
    cd "$MIHOMO_DIR" || return 1
    
    local START_CMD="setsid ./mihomo -d . >> '$MIHOMO_LOG' 2>&1 & echo \$!"
    local new_pid=$(eval "$START_CMD")
    
    if [ -n "$new_pid" ]; then
        echo "$new_pid" > "$MIHOMO_PID"
        renice -n -5 -p "$new_pid" >/dev/null 2>&1
        
        sleep 2
        if check_process_smart "$MIHOMO_PID" "mihomo"; then
            ui_print success "Core service started successfully!"
            echo -e "  - Control Panel: http://127.0.0.1:19090/ui"
            echo -e "  - Proxy Ports: 17890 (HTTP) / 17891 (SOCKS5)"
        else
            ui_print error "Service failed to start properly."
            echo -e "${YELLOW}Last 10 lines of log:${NC}"
            tail -n 10 "$MIHOMO_LOG"
        fi
    else
        ui_print error "System process creation failed."
    fi
}

mihomo_stop() {
    _mihomo_vars
    kill_process_safe "$MIHOMO_PID" "mihomo" >/dev/null 2>&1
    pkill -9 -f "mihomo" >/dev/null 2>&1
    rm -f "$MIHOMO_PID"
}

mihomo_uninstall() {
    _mihomo_vars
    if verify_kill_switch; then
        mihomo_stop
        ui_spinner "Cleaning files..." "safe_rm '$MIHOMO_DIR' '$MIHOMO_SUBS' '$MIHOMO_SECRET_CONF' '$MIHOMO_PID' '$MIHOMO_LOG' '$MIHOMO_PATCH'"
        ui_print success "Uninstall complete."
        return 2
    fi
}

mihomo_menu() {
    while true; do
        _mihomo_vars
        ui_header "Mihomo Proxy Manager"
        local state="stopped"; local text="Stopped"; local info=()
        if check_process_smart "$MIHOMO_PID" "mihomo"; then
            state="running"; text="Running"
            info+=( "Panel: http://127.0.0.1:19090/ui" "Proxy: 127.0.0.1:17890" )
        fi
        ui_status_card "$state" "$text" "${info[@]}"
        
        local CHOICE=$(ui_menu "Operation Menu" "🚀 Start/Restart" "🛑 Stop Service" "🔗 Set Subscriptions" "🔧 Advanced Config (Patch)" "🔑 Set Secret" "📊 Open Panel" "📜 View Logs" "⚙️  Update Core" "🗑️  Uninstall Module" "🔙 Return")
        case "$CHOICE" in
            *"Start"*) mihomo_start; ui_pause ;; 
            *"Stop"*) mihomo_stop; ui_print success "Stopped"; ui_pause ;; 
            *"Subscriptions"*) 
                while true; do
                    ui_header "Subscription Management"
                    local count=0; [ -f "$MIHOMO_SUBS" ] && count=$(grep -c "^http" "$MIHOMO_SUBS")
                    echo -e "Currently added ${CYAN}$count${NC} subscription URLs"
                    echo "----------------------------------------"
                    local sub_opt=$(ui_menu "Subscription Operations" "➕ Add New Subscription" "📜 View Added" "🗑️  Clear All" "🔙 Return")
                    case "$sub_opt" in
                        *"➕"*)
                            local url=$(ui_input_validated "Enter subscription URL" "" "url")
                            [ -n "$url" ] && { echo "$url" >> "$MIHOMO_SUBS"; ui_print success "Added successfully"; }
                            ;;
                        *"📜"*)
                            if [ -s "$MIHOMO_SUBS" ]; then
                                ui_header "Added Subscriptions"
                                cat "$MIHOMO_SUBS" | sed 's/^/  🔗 /'
                            else
                                ui_print warn "No subscription URLs currently."
                            fi
                            ui_pause
                            ;;
                        *"🗑️"*)
                            if ui_confirm "Are you sure you want to delete all subscriptions?"; then
                                safe_rm "$MIHOMO_SUBS"
                                ui_print success "Cleared."
                            fi
                            ;;
                        *) break ;;
                    esac
                done ;;
            *"Advanced"*)
                if [ ! -f "$MIHOMO_PATCH" ]; then
                    ui_print info "Generating sample patch file..."
                    cat > "$MIHOMO_PATCH" <<EOF
# Mihomo Advanced Config Patch
# This file content will be merged into config.yaml at startup 
# You can override default settings or add custom rules here

# [Example] Enable TUN mode
# tun:
#   enable: true
#   stack: gvisor
#   auto-route: true
#   auto-detect-interface: true

# [Example] Custom DNS
# dns:
#   enable: true
#   ipv6: false
#   listen: 0.0.0.0:1053
#   nameserver:
#     - 223.5.5.5
#     - 119.29.29.29

# [Example] Custom rules (override default rules)
# rules:
#   - DOMAIN-SUFFIX,google.com,🚀 Node Select
#   - MATCH,🚀 Node Select
EOF
                fi
                "${EDITOR:-nano}" "$MIHOMO_PATCH"
                ui_print info "Changes saved, restart service to take effect."
                ui_pause ;;
            *"Secret"*) 
                local cur=""; [ -f "$MIHOMO_SECRET_CONF" ] && cur=$(cat "$MIHOMO_SECRET_CONF")
                local sec=$(ui_input "Panel Secret" "$cur" "false")
                echo "$sec" > "$MIHOMO_SECRET_CONF"; ui_print success "Saved"; ui_pause ;; 
            *"Panel"*) open_browser "http://127.0.0.1:19090/ui" ;; 
            *"Logs"*) safe_log_monitor "$MIHOMO_LOG" ;; 
            *"Update"*) mihomo_install ;; 
            *"Uninstall"*) mihomo_uninstall && [ $? -eq 2 ] && return ;; 
            *"Return"*) return ;; 
        esac
    done
}
