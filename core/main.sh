#!/bin/bash
# TAV-X Core: Main 
set +m

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/deps.sh"
source "$TAVX_DIR/core/loader.sh"
source "$TAVX_DIR/core/security.sh"
source "$TAVX_DIR/core/updater.sh"
source "$TAVX_DIR/core/store.sh"
source "$TAVX_DIR/core/about.sh"
source "$TAVX_DIR/core/migrate_apps.sh"

check_dependencies
scan_and_load_modules
check_for_updates
send_analytics

app_drawer_menu() {
    while true; do
        if [ ${#REGISTERED_MODULE_NAMES[@]} -eq 0 ]; then
            ui_print warn "No loaded module scripts."
            ui_pause; return
        fi

        local APP_MENU_OPTS=()
        local VALID_INDICES=()
        
        for i in "${!REGISTERED_MODULE_NAMES[@]}"; do
            local name="${REGISTERED_MODULE_NAMES[$i]}"
            local id="${REGISTERED_MODULE_IDS[$i]}"
            
            local app_path=$(get_app_path "$id")
            if [ ! -d "$app_path" ] || [ -z "$(ls -A "$app_path" 2>/dev/null)" ]; then
                continue 
            fi
            
            local icon="⚪"
            if is_app_running "$id"; then
                icon="🟢"
            fi
            
            APP_MENU_OPTS+=("$icon $name")
            VALID_INDICES+=("$i")
        done
        
        if [ ${#APP_MENU_OPTS[@]} -eq 0 ]; then
            ui_print warn "No installed apps."
            echo "Please go to [🛒 App Store] to download and install apps."
            ui_pause; return
        fi
        
        APP_MENU_OPTS+=("🔙 Return to Main Menu")

        local CHOICE=$(ui_menu "My Apps" "${APP_MENU_OPTS[@]}")
        if [[ "$CHOICE" == *"Return"* ]]; then return; fi
        
        local found=false
        
        for idx in "${VALID_INDICES[@]}"; do
            local name="${REGISTERED_MODULE_NAMES[$idx]}"
            if [[ "$CHOICE" == *"$name" ]]; then
                local entry_func="${REGISTERED_MODULE_ENTRIES[$idx]}"
                if command -v "$entry_func" &>/dev/null; then
                    $entry_func
                else
                    ui_print error "Module entry function missing: $entry_func"
                    ui_pause
                fi
                found=true
                break
            fi
        done
        
        if [ "$found" = false ]; then
            ui_print error "Module match failed!"
            ui_pause
        fi
    done
}

while true; do
    MODULES_LINE=$(get_modules_status_line)
    MEM_STR=$(get_sys_resources_info)

    NET_DL="Auto Select"
    if [ -f "$NETWORK_CONFIG" ]; then
        CONF=$(cat "$NETWORK_CONFIG"); TYPE=${CONF%%|*}
        [ "$TYPE" == "PROXY" ] && NET_DL="Local Accelerated"
    fi

    ui_header ""
    ui_dashboard "$MODULES_LINE" "$NET_DL" "$MEM_STR"

    OPT_UPD="🔄 Check Script Updates"
    [ -f "$TAVX_DIR/.update_available" ] && OPT_UPD="🔄 Check Script Updates 🔔"

    FINAL_OPTS=()
    SHORTCUT_IDS=()
    
    if [ -f "$TAVX_DIR/config/shortcuts.list" ]; then
        shortcuts=($(cat "$TAVX_DIR/config/shortcuts.list"))
        if [ ${#shortcuts[@]} -gt 0 ]; then
            for sid in "${shortcuts[@]}"; do
                idx=-1
                for i in "${!REGISTERED_MODULE_IDS[@]}"; do
                    if [ "${REGISTERED_MODULE_IDS[$i]}" == "$sid" ]; then idx=$i; break; fi
                done
                
                if [ $idx -ge 0 ]; then
                    name="${REGISTERED_MODULE_NAMES[$idx]}"
                    icon="⚪"
                    if is_app_running "$sid"; then
                        icon="🟢"
                    fi
                    
                    FINAL_OPTS+=("$icon $name")
                    SHORTCUT_IDS+=("$sid")
                fi
            done
        fi
    fi

    FINAL_OPTS+=(
        "📂 My Apps"
        "🛒 App Store"
        "$OPT_UPD"
        "📦 Migrate Legacy Data"
        "⚙️  System Settings"
        "💡 Help & Support"
        "🚪 Exit Program"
    )

    CHOICE=$(ui_menu "Main Menu" "${FINAL_OPTS[@]}")
    
    if [[ "$CHOICE" != *"---"* ]]; then
        for i in "${!SHORTCUT_IDS[@]}"; do
            sid="${SHORTCUT_IDS[$i]}"
            idx=-1
            for j in "${!REGISTERED_MODULE_IDS[@]}"; do
                if [ "${REGISTERED_MODULE_IDS[$j]}" == "$sid" ]; then idx=$j; break; fi
            done
            
            if [ $idx -ge 0 ]; then
                name="${REGISTERED_MODULE_NAMES[$idx]}"
                if [[ "$CHOICE" == *"$name" ]]; then
                    entry="${REGISTERED_MODULE_ENTRIES[$idx]}"
                    if command -v "$entry" &>/dev/null; then
                        $entry
                    else
                        ui_print error "Cannot start module: $entry"
                        ui_pause
                    fi
                    continue 2
                fi
            fi
        done
    fi

    case "$CHOICE" in
        *"My Apps"*) app_drawer_menu ;;
        *"App Store"*) app_store_menu ;;
        *"Check Script Updates"*) perform_self_update ;;
        *"Migrate Legacy Data"*) migrate_legacy_apps ;;
        *"System Settings"*) system_settings_menu ;;
        *"Help & Support"*) show_about_page ;;
        *"Exit Program"*) 
            EXIT_OPT=$(ui_menu "Please select exit method" "🏃 Keep Running in Background" "🛑 Stop All Services and Exit" "🔙 Cancel")
            case "$EXIT_OPT" in
                *"Keep"*|*"Background"*)
                    write_log "EXIT" "User exited (Keeping services)"
                    ui_print info "Program minimized, services continue running in background."
                    ui_restore_terminal
                    exit 0
                    ;;
                *"Stop All"*)
                    echo ""
                    if ui_confirm "Are you sure you want to stop all services?"; then
                        write_log "EXIT" "User requested stop all"
                        ui_spinner "Stopping all processes..." "source \"$TAVX_DIR/core/utils.sh\"; stop_all_services_routine"
                        ui_print success "All services stopped."
                        ui_restore_terminal
                        exit 0
                    fi
                    ;;
            esac
            ;;
        *) 
            continue 
            ;;
    esac
done
