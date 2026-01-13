#!/bin/bash
# [METADATA]
# MODULE_ID: aistudio
# MODULE_NAME: AIStudio Proxy
# MODULE_ENTRY: aistudio_menu
# [END_METADATA]

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

_aistudio_vars() {
    AI_ST_DIR=$(get_app_path "sillytavern")
    AI_REPO="https://github.com/starowo/AIStudioBuildProxy"
    AI_PLUGIN_NAME="AIStudioBuildProxy"
    AI_PATH_SERVER="$AI_ST_DIR/plugins/$AI_PLUGIN_NAME"
    AI_PATH_CLIENT="$AI_ST_DIR/public/scripts/extensions/third-party/$AI_PLUGIN_NAME"
}

aistudio_install() {
    _aistudio_vars
    if [ ! -d "$AI_ST_DIR" ]; then
        ui_print error "Please install SillyTavern first!"
        ui_pause; return 1
    fi
    
    ui_header "Deploy AIStudio Plugin"
    
    if command -v yq &>/dev/null; then
        yq -i '.enableServerPlugins = true' "$AI_ST_DIR/config.yaml" 2>/dev/null
    else
        sed -i 's/enableServerPlugins: false/enableServerPlugins: true/' "$AI_ST_DIR/config.yaml" 2>/dev/null
    fi

    prepare_network_strategy "$AI_REPO"
    
    ui_print info "Deploying server component..."
    safe_rm "$AI_PATH_SERVER"
    local CMD_S="source '$TAVX_DIR/core/utils.sh'; git_clone_smart '-b server' '$AI_REPO' '$AI_PATH_SERVER'"
    if ui_stream_task "Fetching server repository..." "$CMD_S"; then
        [ -f "$AI_PATH_SERVER/package.json" ] && npm_install_smart "$AI_PATH_SERVER"
    else
        return 1
    fi

    ui_print info "Deploying client component..."
    safe_rm "$AI_PATH_CLIENT"
    mkdir -p "$(dirname "$AI_PATH_CLIENT")"
    local CMD_C="source '$TAVX_DIR/core/utils.sh'; git_clone_smart '-b client' '$AI_REPO' '$AI_PATH_CLIENT'"
    if ui_stream_task "Fetching client extension..." "$CMD_C"; then
        ui_print success "🎉 AIStudio plugin installation complete! Please restart tavern."
    else
        return 1
    fi
}

aistudio_uninstall() {
    _aistudio_vars
    if verify_kill_switch; then
        ui_spinner "Cleaning files..." "safe_rm '$AI_PATH_SERVER'; safe_rm '$AI_PATH_CLIENT'"
        ui_print success "Uninstalled."
        return 2
    fi
}

aistudio_menu() {
    while true; do
        _aistudio_vars
        ui_header "AIStudio Plugin Management"
        local state="stopped"; local text="Not Installed"; local info=()
        if [ -d "$AI_PATH_SERVER" ] && [ -d "$AI_PATH_CLIENT" ]; then
            state="success"; text="Installed"; info+=( "Location: Tavern plugins directory" )
        fi
        ui_status_card "$state" "$text" "${info[@]}"
        
        local CHOICE=$(ui_menu "Operation Menu" "📥 Install/Update Plugin" "🗑️  Uninstall Plugin" "🔙 Return")
        case "$CHOICE" in
            *"Install"*) aistudio_install ;;
            *"Uninstall"*) aistudio_uninstall && [ $? -eq 2 ] && return ;;
            *"Return"*) return ;;
        esac
        ui_pause
    done
}
