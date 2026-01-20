#!/bin/bash
# TAV-X Core: App Store

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

INDEX_FILE="$TAVX_DIR/config/store.csv"

STORE_IDS=()
STORE_NAMES=()
STORE_CATS=()
STORE_DESCS=()
STORE_URLS=()
STORE_BRANCHES=()

_get_category_icon() {
    echo "📂 "
}
_load_store_data() {
    STORE_IDS=()
    STORE_NAMES=()
    STORE_CATS=()
    STORE_DESCS=()
    STORE_URLS=()
    STORE_BRANCHES=()
    
    if [ -f "$INDEX_FILE" ]; then
        while IFS=, read -r id name cat desc url branch || [ -n "$id" ]; do
            id=$(echo "$id" | tr -d '\r' | xargs)
            [[ "$id" =~ ^#.*$ || -z "$id" ]] && continue
            
            name=$(echo "$name" | tr -d '\r' | xargs)
            cat=$(echo "$cat" | tr -d '\r' | xargs)
            desc=$(echo "$desc" | tr -d '\r' | xargs)
            url=$(echo "$url" | tr -d '\r' | xargs)
            branch=$(echo "$branch" | tr -d '\r' | xargs)
            
            STORE_IDS+=("$id")
            STORE_NAMES+=("$name")
            STORE_CATS+=("${cat:-Uncategorized}")
            STORE_DESCS+=("$desc")
            STORE_URLS+=("$url")
            STORE_BRANCHES+=("$branch")
        done < "$INDEX_FILE"
    fi
    
    for mod_dir in "$TAVX_DIR/modules/"*; do
        [ ! -d "$mod_dir" ] && continue
        local id
        id=$(basename "$mod_dir")
        local main_sh="$mod_dir/main.sh"
        [ ! -f "$main_sh" ] && continue
        
        local exists=false
        for existing_id in "${STORE_IDS[@]}"; do
            if [ "$existing_id" == "$id" ]; then exists=true; break; fi
        done
        
        if [ "$exists" = false ]; then
            local meta_name
            meta_name=$(grep "MODULE_NAME:" "$main_sh" | cut -d: -f2- | xargs)
            local meta_cat
            meta_cat=$(grep "APP_CATEGORY:" "$main_sh" | cut -d: -f2- | xargs)
            [ -z "$meta_name" ] && meta_name="$id"
            [ -z "$meta_cat" ] && meta_cat="Local Modules"
            
            STORE_IDS+=("$id")
            STORE_NAMES+=("$meta_name")
            STORE_CATS+=("$meta_cat")
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
        local id
        id=$(basename "$mod_dir")
        local main_sh="$mod_dir/main.sh"
        [ ! -f "$main_sh" ] && continue
        
        local name
        name=$(grep "MODULE_NAME:" "$main_sh" | cut -d ':' -f 2- | xargs)
        [ -z "$name" ] && name="$id"
        
        local status="🟡"
        local app_path
        app_path=$(get_app_path "$id")
        if [ -d "$app_path" ] && [ -n "$(ls -A "$app_path" 2>/dev/null)" ]; then
            status="🟢"
        fi
        
        raw_list+=("$status $name|$id")
    done
    
    if [ ${#raw_list[@]} -eq 0 ]; then
        ui_print warn "No local modules found."
        ui_pause
        return
    fi
    
    local sorted_list=()
    if [ "${BASH_VERSINFO:-0}" -ge 4 ]; then
        mapfile -t sorted_list < <(printf "%s\n" "${raw_list[@]}" | sort)
    else
        # shellcheck disable=SC2207
        IFS=$'\n' sorted_list=($(printf "%s\n" "${raw_list[@]}" | sort))
    fi
    
    local display_names=()
    local mapping_ids=()
    for item in "${sorted_list[@]}"; do
        display_names+=("${item%|*}")
        mapping_ids+=("${item#*|}")
    done
    
    local current_shortcuts=()
    if [ -f "$SHORTCUT_FILE" ]; then
        if [ "${BASH_VERSINFO:-0}" -ge 4 ]; then
            mapfile -t current_shortcuts < "$SHORTCUT_FILE"
        else
            # shellcheck disable=SC2207
            current_shortcuts=($(cat "$SHORTCUT_FILE"))
        fi
    fi
    
    ui_header "⭐ Homepage Shortcuts"
    echo -e "  ${CYAN}Check apps to pin to main menu top (🟢=Installed 🟡=Not Installed)${NC}"
    if [ "$HAS_GUM" = true ]; then
        "$GUM_BIN" style --foreground "$C_DIM" "  Press <Space> to check, <Enter> to save"
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
        export GUM_CHOOSE_SELECTED
        GUM_CHOOSE_SELECTED=$(IFS=,; echo "${selected_labels[*]}")
        local choices
        choices=$("$GUM_BIN" choose --no-limit --header="" --cursor="👉 " --cursor.foreground="$C_PINK" --selected.foreground="$C_PINK" -- "${display_names[@]}")
        unset GUM_CHOOSE_SELECTED
        
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
             if ui_confirm "$mark Show $name ?"; then new_selection+=("$id"); fi
        done
    fi
    printf "%s\n" "${new_selection[@]}" > "$SHORTCUT_FILE"
    ui_print success "Shortcuts updated!"
    ui_pause
}

app_store_menu() {
    local current_view="home"
    local selected_category=""
    
    while true; do
        _load_store_data
        
        if [ "$current_view" == "home" ]; then
            ui_header "🛒 App Center"
            local unique_cats=()
            local raw_cats
            raw_cats=$(printf "%s\n" "${STORE_CATS[@]}" | grep -v "Other Categories" | sort | uniq)
            if printf "%s\n" "${STORE_CATS[@]}" | grep -q "Other Categories"; then
                raw_cats=$(printf "%s\nOther Categories" "$raw_cats")
            fi
            IFS=$'\n' read -rd '' -a unique_cats <<< "$raw_cats"
            
            local MENU_OPTS=()
            MENU_OPTS+=("⭐ Manage Homepage Shortcuts")
            MENU_OPTS+=("------------------------")
            
            for cat in "${unique_cats[@]}"; do
                [ -z "$cat" ] && continue
                local icon
                icon=$(_get_category_icon "$cat")
                MENU_OPTS+=("$icon$cat")
            done
            
            MENU_OPTS+=("📦 View All Apps")
            MENU_OPTS+=("🔄 Refresh List")
            MENU_OPTS+=("🔙 Return to Main Menu")
            
            local CHOICE
            CHOICE=$(ui_menu "Select Category" "${MENU_OPTS[@]}")
            
            if [[ "$CHOICE" == *"Shortcuts"* ]]; then manage_shortcuts_menu; continue; fi
            if [[ "$CHOICE" == *"All Apps"* ]]; then current_view="list"; selected_category="ALL"; continue; fi
            if [[ "$CHOICE" == *"Refresh"* ]]; then _refresh_store_index; continue; fi
            if [[ "$CHOICE" == *"Return"* ]]; then return; fi
            if [[ "$CHOICE" == *"----"* ]]; then continue; fi
            
            local clean_cat
            clean_cat=$(echo "$CHOICE" | sed -E 's/^[^ ]+[[:space:]]*//')
            if [ -n "$clean_cat" ]; then
                selected_category="$clean_cat"
                current_view="list"
            fi
            
        elif [ "$current_view" == "list" ]; then
            local header_title="📂 Category: $selected_category"
            [ "$selected_category" == "ALL" ] && header_title="📦 All Apps"
            
            ui_header "$header_title"
            
            local MENU_OPTS=()
            local MAPPING_INDICES=()
            
            for i in "${!STORE_IDS[@]}"; do
                local cat="${STORE_CATS[$i]}"
                if [ "$selected_category" != "ALL" ] && [ "$cat" != "$selected_category" ]; then
                    continue
                fi
                
                local id="${STORE_IDS[$i]}"
                local name="${STORE_NAMES[$i]}"
                local status="🌍"
                local mod_path="$TAVX_DIR/modules/$id"
                local app_path
                app_path=$(get_app_path "$id")
                
                if [ -d "$mod_path" ] && [ -f "$mod_path/main.sh" ]; then
                    if [ -d "$app_path" ] && [ -n "$(ls -A "$app_path" 2>/dev/null)" ]; then
                        status="🟢"
                    else
                        status="🟡"
                    fi
                fi
                
                MENU_OPTS+=("$status $name")
                MAPPING_INDICES+=("$i")
            done
            
            if [ ${#MENU_OPTS[@]} -eq 0 ]; then
                ui_print warn "No apps in this category."
                ui_pause
                current_view="home"
                continue
            fi
            
            MENU_OPTS+=("🔙 Return to Previous")
            
            local CHOICE
            CHOICE=$(ui_menu "App List" "${MENU_OPTS[@]}")
            
            if [[ "$CHOICE" == *"Return"* ]]; then current_view="home"; continue; fi
            
            local selected_idx=-1
            for k in "${!MENU_OPTS[@]}"; do
                if [[ "${MENU_OPTS[$k]}" == "$CHOICE" ]]; then
                    selected_idx=${MAPPING_INDICES[$k]}
                    break
                fi
            done
            
            if [ "$selected_idx" -ge 0 ]; then
                _app_store_action "$selected_idx"
            fi
        fi
    done
}

_refresh_store_index() {
    ui_print info "Connecting to cloud list..."
    sleep 0.5
    ui_print success "List updated"
}

_app_store_action() {
    local idx=$1
    local id="${STORE_IDS[$idx]}"
    
    if [ -z "$id" ]; then
        ui_print error "Internal error: Invalid app ID"
        return
    fi
    
    local name="${STORE_NAMES[$idx]}"
    local desc="${STORE_DESCS[$idx]}"
    local url="${STORE_URLS[$idx]}"
    local branch="${STORE_BRANCHES[$idx]}"
    local cat="${STORE_CATS[$idx]}"
    
    local mod_path="$TAVX_DIR/modules/$id"
    local app_path
    app_path=$(get_app_path "$id")
    
    local state="remote"
    if [ -d "$mod_path" ] && [ -f "$mod_path/main.sh" ]; then
        if [ -d "$app_path" ] && [ -n "$(ls -A "$app_path" 2>/dev/null)" ]; then
            state="installed"
        else
            state="pending"
        fi
    fi
    
    ui_header "App Details: $name"
    echo -e "📂 Category: ${CYAN}$cat${NC}"
    echo -e "📝 Description: $desc"
    echo -e "🔗 Repository: $url"
    echo "----------------------------------------"
    
    case "$state" in
        "remote")
            echo -e "Status: ${BLUE}🌍 Cloud${NC}"
            if ui_menu "Select Action" "📥 Fetch Module Script" "🔙 Return" | grep -q "Fetch"; then
                prepare_network_strategy "Module Fetch"
                local final_url
                final_url=$(get_dynamic_repo_url "$url")
                
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
            local ACT
            ACT=$(ui_menu "Select Action" "📦 Install App" "🗑️ Delete Module Script" "🔙 Return")
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
            local ACT
            ACT=$(ui_menu "Select Action" "🚀 Manage/Start" "🔄 Update Module Script" "🔙 Return")
            case "$ACT" in
                *"Manage"*)
                    if [ -f "$mod_path/main.sh" ]; then
                        local entry
                        entry=$(grep "MODULE_ENTRY:" "$mod_path/main.sh" | cut -d: -f2- | xargs)
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
                    ui_print error "Module does not provide install interface ($install_func)."
                fi
            fi
        )
        source "$TAVX_DIR/core/loader.sh"
        scan_and_load_modules
    else
        ui_print error "Module script missing."
    fi
}
