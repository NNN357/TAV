#!/bin/bash
# TAV-X Core: Core Updater
[ -n "$_TAVX_UPDATER_LOADED" ] && return
_TAVX_UPDATER_LOADED=true

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

check_for_updates() {
    [ ! -d "$TAVX_DIR/.git" ] && return
    (
        cd "$TAVX_DIR" || exit
        local check_url=$(get_dynamic_repo_url "Future-404/TAV-X.git")
        local REMOTE_HASH=$(git ls-remote "$check_url" HEAD | awk '{print $1}')
        local LOCAL_HASH=$(git rev-parse HEAD)
        
        if [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
            echo "true" > "$TAVX_DIR/.update_available"
        else
            rm -f "$TAVX_DIR/.update_available"
        fi
    ) >/dev/null 2>&1 &
}
export -f check_for_updates

perform_self_update() {
    ui_header "TAV-X Script Update"
    
    echo -e "Current version: ${CYAN}${CURRENT_VERSION:-3.0}${NC}"
    echo -e "This operation will sync the latest TAV-X script core from GitHub."
    echo ""
    
    if ! ui_confirm "Are you sure you want to update the script core now?"; then return; fi

    prepare_network_strategy
    local TEMP_URL=$(get_dynamic_repo_url "Future-404/TAV-X.git")
    local UPD_CMD="cd \"$TAVX_DIR\"; git fetch \"$TEMP_URL\" main; git reset --hard FETCH_HEAD"
    
    if ui_spinner "Syncing script core..." "$UPD_CMD"; then
        rm -f "$TAVX_DIR/.update_available"
        
        chmod +x "$TAVX_DIR/st.sh" 2>/dev/null
        chmod +x "$TAVX_DIR/core/"*.sh 2>/dev/null
        chmod +x "$TAVX_DIR/modules/"**/*.sh 2>/dev/null
        chmod +x "$TAVX_DIR/bin/"* 2>/dev/null
        
        reset_to_official_remote "$TAVX_DIR" "Future-404/TAV-X.git"
        
        ui_print success "Script core updated! Restarting..."
        sleep 1
        exec bash "$TAVX_DIR/st.sh"
    else
        ui_print error "Update failed, please check network."
        ui_pause
    fi
}
export -f perform_self_update
