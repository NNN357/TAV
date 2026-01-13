#!/bin/bash
# SillyTavern Module: Plugin Manager
# Manages third-party extension plugins for SillyTavern

[ -z "$TAVX_DIR" ] && source "$HOME/.tav_x/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

API_URL="https://tav-x-api.future404.qzz.io"
CURRENT_MODULE_DIR="$(dirname "${BASH_SOURCE[0]}")"
PLUGIN_LIST_FILE="$CURRENT_MODULE_DIR/plugins.list"

_st_plugin_is_installed() {
    local d=$1
    if [ -d "$ST_DIR/plugins/$d" ] || [ -d "$ST_DIR/public/scripts/extensions/third-party/$d" ]; then return 0; else return 1; fi
}

_st_extract_repo_path() {
    local url=$1
    local short=${url#*github.com/}
    echo "$short"
}

app_plugin_install_single() {
    _st_vars
    local name=$1; local repo_url=$2; local s=$3; local c=$4; local dir=$5
    
    if [[ "$dir" == *".."* || "$dir" == *"/"* ]]; then
        ui_print error "Invalid plugin directory name: $dir"
        ui_pause; return
    fi

    ui_header "Install Plugin: $name"
    
    if _st_plugin_is_installed "$dir"; then
        if ! ui_confirm "Plugin already exists, reinstall?"; then return; fi
    fi

    local repo_path=$(_st_extract_repo_path "$repo_url")

    prepare_network_strategy "SillyTavern Plugin"
    
    local TASKS=""
    
    if [ "$s" != "-" ]; then
        local b_arg=""; [ "$s" != "HEAD" ] && b_arg="-b $s"
        TASKS+="safe_rm '$ST_DIR/plugins/$dir'; git_clone_smart '$b_arg' '$repo_path' '$ST_DIR/plugins/$dir' || exit 1;"
    fi
    
    if [ "$c" != "-" ]; then
        local b_arg=""; [ "$c" != "HEAD" ] && b_arg="-b $c"
        TASKS+="safe_rm '$ST_DIR/public/scripts/extensions/third-party/$dir'; git_clone_smart '$b_arg' '$repo_path' '$ST_DIR/public/scripts/extensions/third-party/$dir' || exit 1;"
    fi
    
    local WRAP_CMD="source \"$TAVX_DIR/core/utils.sh\"; $TASKS"
    
    if ui_stream_task "Downloading plugin..." "$WRAP_CMD"; then
        local plugin_path="$ST_DIR/plugins/$dir"
        [ "$s" == "-" ] && plugin_path="$ST_DIR/public/scripts/extensions/third-party/$dir"
        
        if [ -f "$plugin_path/package.json" ]; then
            ui_print info "Plugin dependencies detected, auto-installing..."
            npm_install_smart "$plugin_path"
        fi
        ui_print success "Installation complete!"
    else
        ui_print error "Download failed, try switching network strategy."
    fi
    ui_pause
}

app_plugin_list_menu() {
    if [ ! -f "$PLUGIN_LIST_FILE" ]; then ui_print error "Plugin list not found: $PLUGIN_LIST_FILE"; ui_pause; return; fi

    while true; do
        ui_header "Plugin Repository"
        MENU_ITEMS=()
        local map_file="$TAVX_DIR/.plugin_map"
        safe_rm "$map_file"
        
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            IFS='|' read -r name repo s c dir <<< "$line"
            name=$(echo "$name"|xargs); dir=$(echo "$dir"|xargs)
            
            if _st_plugin_is_installed "$dir"; then ICON="✅"; else ICON="📦"; fi
            ITEM="$ICON $name  [$dir]"
            MENU_ITEMS+=("$ITEM")
            echo "$ITEM|$line" >> "$map_file"
        done < "$PLUGIN_LIST_FILE"
        
        MENU_ITEMS+=("🔙 Return")
        CHOICE=$(ui_menu "Enter keyword to search" "${MENU_ITEMS[@]}")
        if [[ "$CHOICE" == *"Return"* ]]; then return; fi
        
        RAW_LINE=$(grep -F "$CHOICE|" "$map_file" | head -n 1 | cut -d'|' -f2-)
        if [ -n "$RAW_LINE" ]; then
            IFS='|' read -r n r s c d <<< "$RAW_LINE"
            app_plugin_install_single "$(echo "$n"|xargs)" "$(echo "$r"|xargs)" "$(echo "$s"|xargs)" "$(echo "$c"|xargs)" "$(echo "$d"|xargs)"
        else
            ui_print error "Data parsing error"
            ui_pause
        fi
    done
}

app_plugin_submit() {
    ui_header "Submit New Plugin"
    echo -e "${YELLOW}Welcome to contribute plugins!${NC}"
    echo -e "Data will be submitted to: $API_URL"
    echo ""
    local name=$(ui_input "1. Plugin Name (Required)" "" "false")
    if [[ -z "$name" || "$name" == "0" ]]; then ui_print info "Cancelled"; ui_pause; return; fi
    local url=$(ui_input "2. GitHub URL (Required)" "https://github.com/" "false")
    if [[ -z "$url" || "$url" == "0" || "$url" == "https://github.com/" ]]; then ui_print info "Cancelled"; ui_pause; return; fi
    if [[ "$url" != http* ]]; then ui_print error "Invalid URL format"; ui_pause; return; fi
    local dir=$(ui_input "3. English Directory Name (Optional, 0 to cancel)" "" "false")
    if [[ "$dir" == "0" ]]; then ui_print info "Cancelled"; ui_pause; return; fi
    
    echo -e "------------------------"
    echo -e "Name: $name"
    echo -e "URL: $url"
    echo -e "Directory: ${dir:-Auto-detect}"
    echo -e "------------------------"
    
    if ! ui_confirm "Confirm submission?"; then ui_print info "Cancelled"; ui_pause; return; fi
    
    local JSON=$(printf '{"name":"%s", "url":"%s", "dirName":"%s"}' "$name" "$url" "$dir")
    
    _auto_heal_network_config
    local network_conf="$TAVX_DIR/config/network.conf"
    local proxy_args=""
    if [ -f "$network_conf" ]; then
        local c=$(cat "$network_conf")
        if [[ "$c" == PROXY* ]]; then
            local val=${c#*|}; val=$(echo "$val"|tr -d '\n\r')
            proxy_args="-x $val"
        fi
    fi
    
    if ui_spinner "Submitting..." "curl -s $proxy_args -X POST -H 'Content-Type: application/json' -d '$JSON' '$API_URL/submit' > $TAVX_DIR/.api_res"; then
        RES=$(cat "$TAVX_DIR/.api_res")
        if echo "$RES" | grep -q "success"; then
            ui_print success "Submission successful! Please wait for review."
        else
            ui_print error "Submission failed: $RES"
        fi
    else
        ui_print error "API connection failed, please check network."
    fi
    ui_pause
}

app_plugin_reset() {
    local PLUGIN_ROOT="$ST_DIR/public/scripts/extensions/third-party"
    if [ -z "$(ls -A "$PLUGIN_ROOT" 2>/dev/null)" ]; then ui_print info "Plugin directory is already empty."; ui_pause; return; fi

    ui_header "💥 Plugin Factory Reset"
    echo -e "${RED}Warning: This will delete all third-party extensions!${NC}"
    if ui_confirm "Confirm to clear?"; then
        if ui_spinner "Shredding files..." "safe_rm '$PLUGIN_ROOT'; mkdir -p '$PLUGIN_ROOT'"; then
            ui_print success "Cleanup complete. Please restart SillyTavern."
        else
            ui_print error "Operation failed.";
        fi
    fi
    ui_pause
}

app_plugin_menu() {
    _st_vars
    if [ ! -d "$ST_DIR" ]; then ui_print error "Please install SillyTavern first!"; ui_pause; return; fi
    while true; do
        ui_header "Plugin Ecosystem Center"
        CHOICE=$(ui_menu "Please Select" \
            "📥 Install Plugins Online" \
            "➕ Submit New Plugin" \
            "💥 Reset All Plugins" \
            "🔙 Return"
        )
        case "$CHOICE" in
            *"Install"*) app_plugin_list_menu ;; 
            *"Submit"*) app_plugin_submit ;; 
            *"Reset"*) app_plugin_reset ;; 
            *"Return"*) return ;; 
        esac 
    done
}
