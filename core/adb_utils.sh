#!/bin/bash
# TAV-X Core: ADB & Keepalive Utils (Migrated from Module)
[ -n "$_TAVX_ADB_UTILS_LOADED" ] && return
_TAVX_ADB_UTILS_LOADED=true

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

PKG="com.termux"
LOG_FILE="$LOGS_DIR/adb_manager.log"
HEARTBEAT_PID="$RUN_DIR/audio_heartbeat.pid"
SILENCE_FILE="$CONFIG_DIR/silence.wav"
LEGACY_ADB_DIR="$TAVX_DIR/adb_tools"
OPTIMIZED_FLAG="$CONFIG_DIR/.adb_optimized"

revert_optimization_core() {
    local PKG="com.termux"
    adb shell device_config set_sync_disabled_for_tests none 2>/dev/null
    adb shell device_config delete activity_manager max_phantom_processes 2>/dev/null
    adb shell device_config delete activity_manager settings_enable_monitor_phantom_procs 2>/dev/null
    adb shell dumpsys deviceidle whitelist -$PKG 2>/dev/null
    adb shell cmd appops set $PKG RUN_IN_BACKGROUND default 2>/dev/null
    adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND default 2>/dev/null
    adb shell cmd appops set $PKG WAKE_LOCK default 2>/dev/null
    adb shell pm enable com.huawei.powergenie 2>/dev/null
    adb shell pm enable com.huawei.android.hwaps 2>/dev/null
    adb shell pm enable com.xiaomi.joyose 2>/dev/null
    adb shell pm enable com.xiaomi.powerchecker 2>/dev/null
    adb shell pm enable com.coloros.athena 2>/dev/null
    adb shell pm enable com.vivo.pem 2>/dev/null
    adb shell pm enable com.vivo.abe 2>/dev/null
    
    if command -v termux-wake-unlock &> /dev/null; then termux-wake-unlock; fi
    safe_rm "$OPTIMIZED_FLAG"
}
export -f revert_optimization_core

apply_universal_fixes() {
    local PKG="com.termux"
    local SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0
    
    if [ "$SDK_VER" -ge 31 ]; then
        adb shell device_config set_sync_disabled_for_tests persistent
        adb shell device_config put activity_manager max_phantom_processes 2147483647
        adb shell device_config put activity_manager settings_enable_monitor_phantom_procs false
    fi

    adb shell dumpsys deviceidle whitelist +$PKG >/dev/null 2>&1
    adb shell cmd appops set $PKG RUN_IN_BACKGROUND allow
    adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND allow
    adb shell cmd appops set $PKG WAKE_LOCK allow
    adb shell cmd appops set $PKG START_FOREGROUND allow
    adb shell am set-standby-bucket $PKG active >/dev/null 2>&1
    if command -v termux-wake-lock &> /dev/null; then termux-wake-lock; fi
}
export -f apply_universal_fixes

apply_vendor_fixes() {
    local MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
    local SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0

    ui_print info "Applying vendor deep strategy: ${CYAN}$MANUFACTURER${NC}"
    
    case "$MANUFACTURER" in
        *huawei*|*honor*) 
            ui_print info ">>> Executing Huawei/Honor PowerGenie freeze..."
            adb shell pm disable-user --user 0 com.huawei.powergenie 2>/dev/null
            adb shell pm disable-user --user 0 com.huawei.android.hwaps 2>/dev/null
            adb shell am stopservice hwPfwService 2>/dev/null
            echo -e "${YELLOW}💡 Tip: Recommend setting Termux to [Manual Management] in [Battery Management].${NC}"
            ;;
            
        *xiaomi*|*redmi*) 
            ui_print info ">>> Executing Xiaomi Joyose/Cloud Control freeze..."
            adb shell pm disable-user --user 0 com.xiaomi.joyose 2>/dev/null
            adb shell pm disable-user --user 0 com.xiaomi.powerchecker 2>/dev/null
            adb shell am start -n com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity >/dev/null 2>&1
            echo -e "${YELLOW}💡 Tip: Please enable Termux [Auto-Start] in the popup interface.${NC}"
            ;;
            
        *oppo*|*realme*|*oneplus*) 
            ui_print info ">>> Executing ColorOS Athena optimization..."
            if [ "$SDK_VER" -ge 34 ]; then
                ui_print warn "Android 14+ detected: Skipping Athena disable (brick protection)."
                adb shell settings put global coloros_super_power_save 0
            else
                adb shell pm disable-user --user 0 com.coloros.athena 2>/dev/null
            fi
            adb shell am start -n com.coloros.safecenter/.startupapp.StartupAppListActivity >/dev/null 2>&1
            echo -e "${YELLOW}💡 Tip: Please allow Termux auto-start in the popup window.${NC}"
            ;; 

        *vivo*|*iqoo*) 
            ui_print info ">>> Executing OriginOS PEM/ABE optimization..."
            ui_print warn "Note: Attempting to disable core keep-alive components for deep persistence..."
            adb shell pm disable-user --user 0 com.vivo.pem 2>/dev/null
            adb shell pm disable-user --user 0 com.vivo.abe 2>/dev/null
            adb shell am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS >/dev/null 2>&1
            echo -e "${YELLOW}💡 Tip: Please confirm Termux is set to [Don't Optimize Battery] in the popup interface.${NC}"
            ;; 

        *)
            ui_print info "Non-mainstream device, applying AOSP universal keep-alive only."
            ;;
    esac
}

export -f apply_vendor_fixes

ensure_silence_file() {
    if [ -f "$SILENCE_FILE" ]; then return 0; fi
    ui_print info "Generating silence config file..."
    mkdir -p "$(dirname "$SILENCE_FILE")"
    # Generate 1 second silent wav file base64 
    echo "UklGRigAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=" | base64 -d > "$SILENCE_FILE"
    return 0
}
check_adb_binary() {
    command -v adb &> /dev/null
}

check_adb_connection() {
    check_adb_binary || return 1
    timeout 2 adb devices 2>/dev/null | grep -q "device$"
}

ensure_adb_installed() {
    if [ -d "$LEGACY_ADB_DIR" ]; then 
        safe_rm "$LEGACY_ADB_DIR"
        sed -i '/adb_tools\/platform-tools/d' "$HOME/.bashrc" 2>/dev/null
    fi

    if check_adb_binary; then return 0; fi
    ui_header "ADB Component Installation"
    ui_print info "Attempting to auto-install ADB toolkit..."
    
    local pkg_name="android-tools"
    [ "$OS_TYPE" == "LINUX" ] && pkg_name="adb"
    
    sys_install_pkg "$pkg_name"
    check_adb_binary
}

start_heartbeat() {
    if [ "$OS_TYPE" == "LINUX" ]; then
        ui_print warn "Linux environment usually doesn't need audio keep-alive, unless you're debugging."
        if ! ui_confirm "Still want to start?"; then return; fi
    fi

    source "$TAVX_DIR/core/deps.sh"
    command -v mpv &>/dev/null || { 
        ui_print info "Installing audio component..."; 
        sys_install_pkg "mpv"
    }
    
    ensure_silence_file || { ui_pause; return 1; }
    ui_header "Start Audio Heartbeat"
    setsid nohup bash -c "while true; do mpv --no-terminal --volume=0 --loop=inf \"$SILENCE_FILE\"; sleep 1; done" > /dev/null 2>&1 &
    echo $! > "$HEARTBEAT_PID"
    ui_print success "Audio heartbeat started in background, simulating foreground occupation..."
    ui_pause
}

stop_heartbeat() {
    kill_process_safe "$HEARTBEAT_PID" "mpv"
    if command -v termux-wake-unlock &> /dev/null; then termux-wake-unlock; fi
    ui_print success "Audio heartbeat stopped."
}

uninstall_adb() {
    ui_header "Uninstall ADB Keep-Alive Module"

    if ! verify_kill_switch; then return; fi

    if [ -f "$HEARTBEAT_PID" ] && kill -0 $(cat "$HEARTBEAT_PID") 2>/dev/null; then
        ui_print info "Stopping background audio heartbeat..."
        stop_heartbeat
    fi

    echo ""
    echo -e "${YELLOW}🔍 Checking residual configurations...${NC}"

    echo -e "You may have applied system-level keep-alive strategies before."
    if ui_confirm "Restore system parameters to default?"; then
        ui_spinner "Rolling back system settings..." "revert_optimization_core"
        ui_print success "System settings restored."
    else
        ui_print info "Keeping system optimization settings."
    fi

    if command -v mpv &> /dev/null; then
        echo ""
        echo -e "${YELLOW}Detected mpv player installed.${NC}"
        echo -e "If it was installed specifically for keep-alive, recommend uninstalling."
        if ui_confirm "Uninstall mpv?"; then
            sys_remove_pkg "mpv"
            ui_print success "Dependencies cleaned."
        fi
    fi

    echo ""
    if [ -d "$LEGACY_ADB_DIR" ] || [ -f "$LOG_FILE" ]; then
        ui_spinner "Cleaning module files..." "
            safe_rm '$LEGACY_ADB_DIR'
            safe_rm '$LOG_FILE'
            safe_rm '$HEARTBEAT_PID'
            sed -i '/adb_tools\/platform-tools/d' '$HOME/.bashrc'
        "
        ui_print success "Module files cleaned."
    fi

    if command -v adb &> /dev/null; then
        echo ""
        if ui_confirm "Also uninstall system ADB?"; then
            local pkg_name="android-tools"
            [ "$OS_TYPE" == "LINUX" ] && pkg_name="adb"
            sys_remove_pkg "$pkg_name"
            ui_print success "ADB uninstalled."
        fi
    fi

    ui_print success "Uninstall complete."
    ui_pause
}

adb_manager_ui() {
    ensure_adb_installed || { ui_print error "ADB not installed and cannot auto-repair."; ui_pause; return; }
    while true; do
        ui_header "ADB Smart Assistant (Keep-Alive & Repair)"
        local state="stopped"; local text="Not Connected"; local info=()
        if check_adb_connection; then
            state="success"; text="Connected"
            local dev_count=$(adb devices | grep "device$" | wc -l)
            info+=( "Devices: $dev_count" )
        elif ! check_adb_binary; then
            state="error"; text="Not Installed"
        fi

        if [ -f "$HEARTBEAT_PID" ] && kill -0 $(cat "$HEARTBEAT_PID") 2>/dev/null; then
            info+=( "Audio Heartbeat: ⚡ Running" )
            [ "$state" == "success" ] && state="running" || state="warn"
        fi

        [ -f "$OPTIMIZED_FLAG" ] && info+=( "Keep-Alive Strategy: 🔥 Aggressive Mode" )
        ui_status_card "$state" "$text" "${info[@]}"
        
        local CHOICE=$(ui_menu "Please select operation" "🤝 Wireless Pairing" "🔗 Quick Connect" "⚡ Execute Smart Keep-Alive" "🎵 Start Audio Heartbeat" "🔇 Stop Audio Heartbeat" "♻️  Revert All Optimizations" "🗑️  Reset Environment" "🔙 Return")
        case "$CHOICE" in
            *"Pairing"*)
                local host=$(ui_input_validated "Enter IP:Port" "127.0.0.1:" "host")
                local code=$(ui_input_validated "Enter 6-digit pairing code" "" "numeric")
                [ -n "$code" ] && ui_spinner "Pairing..." "adb pair '$host' '$code'" && ui_pause ;;
            *"Connect"*)
                local target=$(ui_input_validated "Enter IP:Port" "127.0.0.1:" "host")
                [ -n "$target" ] && ui_spinner "Connecting..." "adb connect '$target'" && ui_pause ;;
            *"Keep-Alive"*)
                if ! check_adb_connection; then ui_print error "Please connect device first!"; ui_pause; continue; fi
                local sub=$(ui_menu "Strategy" "🛡️ Universal Keep-Alive (AOSP)" "🔥 Aggressive Keep-Alive (with vendor strategies)" "🔙 Return")
                if [[ "$sub" == *"Universal"* ]]; then
                    ui_spinner "Applying universal strategy..." "apply_universal_fixes" && {
                        touch "$OPTIMIZED_FLAG"
                        ui_print success "Applied, recommend restarting."
                    }
                    ui_pause
                elif [[ "$sub" == *"Aggressive"* ]]; then
                    if ui_confirm "Aggressive mode may affect heat and fast charging, confirm execution?"; then
                        ui_spinner "Applying universal strategy..." "apply_universal_fixes"
                        apply_vendor_fixes
                        touch "$OPTIMIZED_FLAG"
                        ui_print success "Aggressive strategy executed, please restart your phone."; ui_pause
                    fi
                fi ;; 
            *"Start Audio"*) start_heartbeat ;; 
            *"Stop Audio"*) stop_heartbeat; ui_pause ;; 
            *"Revert"*) 
                if ui_confirm "Restore system default parameters?"; then
                    ui_spinner "Rolling back..." "revert_optimization_core"
                    ui_print success "Restored."; ui_pause
                fi ;; 
            *"Reset"*|*"Uninstall"*) uninstall_adb ;; 
            *"Return"*) return ;; 
        esac
    done
}
