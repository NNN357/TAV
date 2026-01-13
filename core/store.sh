#!/bin/bash
# TAV-X Core: App Store (Unified Library)

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

INDEX_FILE="$TAVX_DIR/config/store.csv"

STORE_IDS=()
STORE_NAMES=()
STORE_DESCS=()
STORE_URLS=()
STORE_BRANCHES=()

_load_store_data() {
    STORE_IDS=()
    STORE_NAMES=()
    STORE_DESCS=()
    STORE_URLS=()
    STORE_BRANCHES=()
    
    if [ -f "$INDEX_FILE" ]; then
        while IFS=, read -r id name desc url branch; do
            [[ "$id" =~ ^#.*$ || -z "$id" ]] && continue
            STORE_IDS+=("$id")
            STORE_NAMES+=("$name")
            STORE_DESCS+=("$desc")
            STORE_URLS+=("$url")
            STORE_BRANCHES+=("$branch")
        done < "$INDEX_FILE"
    fi
    
    for mod_dir in "$TAVX_DIR/modules/"*; do
        [ ! -d "$mod_dir" ] && continue
        local id=$(basename "$mod_dir")
        local main_sh="$mod_dir/main.sh"
        [ ! -f "$main_sh" ] && continue
        local exists=false
        for existing_id in "${STORE_IDS[@]}"; do
            if [ "$existing_id" == "$id" ]; then exists=true; break; fi
        done
        if [ "$exists" = false ]; then
            local meta_name=$(grep "MODULE_NAME:" "$main_sh" | cut -d: -f2 | xargs)
            [ -z "$meta_name" ] && meta_name="$id"
            STORE_IDS+=("$id")
            STORE_NAMES+=("$meta_name")
            STORE_DESCS+=("Locally installed module")
            STORE_URLS+=("local")
            STORE_BRANCHES+=("-")
        fi
    done
}

manage_shortcuts_menu() {
    local SHORTCUT_FILE="$TAVX_DIR/config/shortcuts.list"
    local raw_list=()
    
    for mod_dir in "$TAVX_DIR/modules/"*; do
        [ ! -d "$mod_dir" ] && continue
        local id=$(basename "$mod_dir")
        local main_sh="$mod_dir/main.sh"
        [ ! -f "$main_sh" ] && continue
        
        local name=$(grep "MODULE_NAME:" "$main_sh" | cut -d ':' -f 2 | xargs)
        [ -z "$name" ] && name="$id"
        
        local status="🟡"
        local app_path=$(get_app_path "$id")
        if [ -d "$app_path" ] && [ -n "$(ls -A "$app_path" 2>/dev/null)" ]; then
            status="🟢"
        fi
        
        raw_list+=("$status $name|$id")
    done
    
    if [ ${#raw_list[@]} -eq 0 ]; then
        ui_print warn "No modules found locally."
        ui_pause
        return
    fi
    
    IFS=$'\n' sorted_list=($(printf "%s\n" "${raw_list[@]}" | sort))
    
    local display_names=()
    local mapping_ids=()
    for item in "${sorted_list[@]}"; do
        display_names+=("${item%|*}")
        mapping_ids+=("${item#*|}")
    done
    
    local current_shortcuts=()
    if [ -f "$SHORTCUT_FILE" ]; then
        mapfile -t current_shortcuts < "$SHORTCUT_FILE"
    fi
    
    ui_header "⭐ Home Shortcuts"
    echo -e "  ${CYAN}Check apps to pin to main menu top (🟢=Installed 🟡=Not Installed)${NC}"
    if [ "$HAS_GUM" = true ]; then
        gum style --foreground "$C_DIM" "  Press <Space> to check, press <Enter> to save"
        echo ""
    else
        echo "----------------------------------------"
    fi
    
    local new_selection=()
    
    if [ "$HAS_GUM" = true ]; then
        local selected_labels=()
        for cur in "${current_shortcuts[@]}"; do
            for i in "${!mapping_ids[@]}"; do
                if [ "${mapping_ids[$i]}" == "$cur" ]; then
                    selected_labels+=("${display_names[$i]}")
                    break
                fi
            done
        done
        
        export GUM_CHOOSE_SELECTED=$(IFS=,; echo "${selected_labels[*]}")
        local choices=$(gum choose --no-limit --header="" --cursor="👉 " --cursor.foreground="$C_PINK" --selected.foreground="$C_PINK" -- "${display_names[@]}")
        unset GUM_CHOOSE_SELECTED
        
        new_selection=()
        IFS=$'\n' read -rd '' -a choices_arr <<< "$choices"
        for choice in "${choices_arr[@]}"; do
            [ -z "$choice" ] && continue
            for i in "${!display_names[@]}"; do
                if [ "${display_names[$i]}" == "$choice" ]; then
                    new_selection+=("${mapping_ids[$i]}")
                    break
                fi
            done
        done
    else
        for i in "${!display_names[@]}"; do
             local id="${mapping_ids[$i]}"
             local name="${display_names[$i]}"
             local is_pinned="false"
             for cur in "${current_shortcuts[@]}"; do [[ "$cur" == "$id" ]] && is_pinned="true"; done
             
             local mark="[ ]"; [ "$is_pinned" == "true" ] && mark="[x]"
             if ui_confirm "$mark Show $name ?"; then
                 new_selection+=("$id")
             fi
        done
    fi
    
    printf "%s\n" "${new_selection[@]}" > "$SHORTCUT_FILE"
    ui_print success "Shortcuts updated!"
    ui_pause
}

app_store_menu() {
    while true; do
        _load_store_data
        ui_header "🛒 App Center"
        
        local MENU_OPTS=()
        MENU_OPTS+=("⭐ Manage Home Shortcuts")
        MENU_OPTS+=("------------------------")
        
        for i in "${!STORE_IDS[@]}"; do
            local id="${STORE_IDS[$i]}"
            local name="${STORE_NAMES[$i]}"
            local status="☁️"
            local mod_path="$TAVX_DIR/modules/$id"
            local app_path=$(get_app_path "$id")
            if [ -d "$mod_path" ] && [ -f "$mod_path/main.sh" ]; then
                if [ -d "$app_path" ] && [ -n "$(ls -A "$app_path" 2>/dev/null)" ]; then
                    status="🟢"
                else
                    status="🟡"
                fi
            fi
            
            MENU_OPTS+=("$status $name")
        done
        
        MENU_OPTS+=("🔄 Refresh List")
        MENU_OPTS+=("🔙 Return to Main Menu")
        
        local CHOICE=$(ui_menu "All Apps" "${MENU_OPTS[@]}")
        
        if [[ "$CHOICE" == *"Shortcuts"* ]]; then manage_shortcuts_menu; continue; fi
        if [[ "$CHOICE" == *"----"* ]]; then continue; fi
        if [[ "$CHOICE" == *"Return"* ]]; then return; fi
        if [[ "$CHOICE" == *"Refresh"* ]]; then _refresh_store_index; continue; fi
        
        local selected_idx=-1
        local offset=2
        
        for i in "${!MENU_OPTS[@]}"; do
            if [ $i -lt $offset ]; then continue; fi
            local clean_opt="${MENU_OPTS[$i]}"
            if [[ "$CHOICE" == *"$clean_opt"* ]] || [[ "$CHOICE" == "$clean_opt" ]]; then
                selected_idx=$((i - offset))
                break
            fi
        done
        
        if [ $selected_idx -ge 0 ] && [ $selected_idx -lt ${#STORE_IDS[@]} ]; then
            _app_store_action $selected_idx
        fi
    done
}

_refresh_store_index() {
    ui_print info "Connecting to cloud list..."
    sleep 0.5
    ui_print success "List updated (simulated)"
}

_app_store_action() {
    local idx=$1
    local id="${STORE_IDS[$idx]}"
    
    if [ -z "$id" ]; then
        ui_print error "Internal error: Invalid app ID (Index: $idx)"
        return
    fi
    
    local name="${STORE_NAMES[$idx]}"
    local desc="${STORE_DESCS[$idx]}"
    local url="${STORE_URLS[$idx]}"
    local branch="${STORE_BRANCHES[$idx]}"
    local mod_path="$TAVX_DIR/modules/$id"
    local app_path=$(get_app_path "$id")
    
    local state="remote"
    if [ -d "$mod_path" ] && [ -f "$mod_path/main.sh" ]; then
        if [ -d "$app_path" ] && [ -n "$(ls -A "$app_path" 2>/dev/null)" ]; then
            state="installed"
        else
            state="pending"
        fi
    fi
    
    ui_header "App Details: $name"
    echo -e "📝 Description: $desc"
    echo -e "🔗 Repository: $url"
    echo "----------------------------------------"
    
    case "$state" in
        "remote")
            echo -e "Status: ${BLUE}☁️ Cloud${NC}"
            if ui_menu "Select operation" "📥 Fetch Module Script" "🔙 Return" | grep -q "Fetch"; then
                prepare_network_strategy "Module Fetch"
                local final_url=$(get_dynamic_repo_url "$url")
                
                local CMD="mkdir -p '$mod_path'; git clone -b $branch '$final_url' '$mod_path'"
                if ui_stream_task "Fetching script..." "$CMD"; then
                    chmod +x "$mod_path"/*.sh 2>/dev/null
                    ui_print success "Script fetched successfully!"
                    source "$TAVX_DIR/core/loader.sh"
                    scan_and_load_modules
                    if ui_confirm "Install app now?"; then
                        _trigger_app_install "$id"
                    fi
                else
                    ui_print error "Fetch failed."
                    safe_rm "$mod_path"
                fi
            fi
            ;;
            
        "pending")
            echo -e "Status: ${YELLOW}🟡 Pending Deployment${NC}"
            local ACT=$(ui_menu "Select operation" "📦 Install App" "🗑️ Delete Module Script" "🔙 Return")
            case "$ACT" in
                *"Install"*) _trigger_app_install "$id" ;;
                *"Delete"*) 
                    if ui_confirm "Delete module script?"; then
                        safe_rm "$mod_path"
                        source "$TAVX_DIR/core/loader.sh"
                        scan_and_load_modules
                        ui_print success "Deleted."
                    fi 
                    ;;
            esac
            ;;
            
        "installed")
            echo -e "Status: ${GREEN}🟢 Ready${NC}"
            local ACT=$(ui_menu "Select operation" "🚀 Manage/Start" "🔄 Update Module Script" "🔙 Return")
            case "$ACT" in
                *"Manage"*)
                    if [ -f "$mod_path/main.sh" ]; then
                        local entry=$(grep "MODULE_ENTRY:" "$mod_path/main.sh" | cut -d: -f2 | xargs)
                        if [ -n "$entry" ]; then
                            source "$mod_path/main.sh"
                            $entry
                        else
                            ui_print error "Cannot identify entry function."
                        fi
                    fi
                    ;;
                *"Update"*)
                    ui_stream_task "Updating script..." "cd '$mod_path' && git pull"
                    ui_print success "Script updated."
                    ;;
            esac
            ;;
    esac
}

_trigger_app_install() {
    local id=$1
    local mod_path="$TAVX_DIR/modules/$id"
    local install_func="${id}_install"
    
    ui_header "Installing App: $id"
    if [ -f "$mod_path/main.sh" ]; then
        (
            source "$mod_path/main.sh"
            if command -v "$install_func" &>/dev/null; then
                "$install_func"
            else
                if command -v app_install &>/dev/null; then
                    app_install
                else
                    ui_print error "Module doesn't provide install interface ($install_func)."
                fi
            fi
        )
        source "$TAVX_DIR/core/loader.sh"
        scan_and_load_modules
    else
        ui_print error "Module script missing."
    fi
    ui_pause
}
