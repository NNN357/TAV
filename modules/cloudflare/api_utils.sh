#!/bin/bash
# TAV-X Cloudflare API Utilities
# Handles Cloudflare API interaction logic

_cf_api_vars() {
    CF_API_TOKEN_FILE="$CONFIG_DIR/cf_api_token"
}

_cf_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    _cf_api_vars
    if [ ! -f "$CF_API_TOKEN_FILE" ]; then return 1; fi
    local token=$(cat "$CF_API_TOKEN_FILE")
    
    local args=("-s" "-X" "$method" "-H" "Authorization: Bearer $token" "-H" "Content-Type: application/json")
    [ -n "$data" ] && args+=("-d" "$data")
    
    local response=$(curl "${args[@]}" "https://api.cloudflare.com/client/v4$endpoint")
    
    if echo "$response" | grep -q '"success":true'; then
        echo "$response"
        return 0
    else
        echo "$response" >&2
        return 1
    fi
}
export -f _cf_api_vars
export -f _cf_api_call


cf_verify_token() {
    ui_spinner "Verifying Token..." "_cf_api_call 'GET' '/user/tokens/verify' >/dev/null"
}

cf_configure_api_token() {
    _cf_api_vars
    ui_header "Configure API Token"
    echo -e "${YELLOW}Advanced Feature: Binding API Token enables automatic DNS cleanup.${NC}"
    echo -e "Please go to Dashboard -> API Tokens to create one."
    echo -e "Required permission: ${CYAN}Zone.DNS:Edit${NC}"
    echo ""
    
    local current=""
    [ -f "$CF_API_TOKEN_FILE" ] && current=$(cat "$CF_API_TOKEN_FILE")
    
    if [ -n "$current" ]; then
        echo -e "Current status: ${GREEN}Configured${NC} (${current:0:6}...)"
        if ! ui_confirm "Reconfigure?"; then return; fi
    fi
    
    local token=$(ui_input "Paste API Token" "" "true")
    if [ -n "$token" ]; then
        echo "$token" > "$CF_API_TOKEN_FILE"
        if cf_verify_token; then
            ui_print success "Verification passed!"
        else
            ui_print error "Verification failed, Token invalid."
            rm -f "$CF_API_TOKEN_FILE"
        fi
    fi
    ui_pause
}

cf_api_delete_dns() {
    local hostname="$1"
    [ -z "$hostname" ] && return 1
    
    _cf_api_vars
    if [ ! -f "$CF_API_TOKEN_FILE" ]; then return 2; fi
    
    ui_print info "Searching DNS records via API..."
    local zones_json
    if ! zones_json=$(_cf_api_call "GET" "/zones?per_page=50"); then
        ui_print error "Failed to get zone list."
        return 1
    fi
    
    local zone_id=""
    local zone_name=""
    local best_len=0

    while read -r z_id z_name; do
        if [[ "$hostname" == "$z_name" || "$hostname" == *"$z_name" ]]; then
            local len=${#z_name}
            if (( len > best_len )); then
                best_len=$len
                zone_id="$z_id"
                zone_name="$z_name"
            fi
        fi
    done < <(
        echo "$zones_json" \
        | grep -oE '"id":"[a-f0-9]+","name":"[^"]+"' \
        | sed 's/"id":"//;s/","name":"/ /;s/"//'
    )

    if [ -z "$zone_id" ]; then
        ui_print warn "No matching Zone found (longest suffix match failed)."
        return 1
    fi

    ui_print info "Matched Zone: $zone_name"
    
    local dns_json
    if ! dns_json=$(_cf_api_call "GET" "/zones/$zone_id/dns_records?name=$hostname"); then
        ui_print error "Failed to query DNS records."
        return 1
    fi
    
    local record_id=$(echo "$dns_json" | grep -oE '"id":"[a-f0-9]+"' | head -n 1 | cut -d'"' -f4)
    
    if [ -z "$record_id" ]; then
        ui_print warn "No DNS record found for this domain, may already be deleted."
        return 0
    fi
    
    if _cf_api_call "DELETE" "/zones/$zone_id/dns_records/$record_id" >/dev/null; then
        ui_print success "API: Successfully deleted DNS record ($hostname)"
        return 0
    else
        ui_print error "API: Failed to delete DNS record."
        return 1
    fi
}

cf_scan_orphan_dns() {
    _cf_api_vars
    if [ ! -f "$CF_API_TOKEN_FILE" ]; then
        ui_print error "API Token not configured, cannot scan DNS."
        ui_print info "Please first select [🔑 API Token Settings] in the menu to configure."
        ui_pause
        return 2
    fi
    
    if [ ! -f "$CF_USER_DATA/cert.pem" ]; then
        ui_print error "Not logged into Cloudflare Tunnel, cannot compare UUIDs."
        ui_pause
        return 1
    fi

    ui_header "🧹 Scan Orphan Tunnel DNS"

    local zones_json
    if ! zones_json=$(_cf_api_call "GET" "/zones?per_page=50"); then
        ui_print error "Cannot get Zone list."
        return 1
    fi

    ui_print info "Getting local active Tunnel list..."
    local alive_tunnels
alive_tunnels=$(cloudflared tunnel list 2>/dev/null | awk 'NR>1 {print $1}')

    local found_any=false

    while read -r zone_id zone_name; do

        ui_print info "Scanning Zone: $zone_name"

        local dns_json
        
        if ! dns_json=$(_cf_api_call "GET" "/zones/$zone_id/dns_records?per_page=100&type=CNAME" 2>/dev/null); then
            ui_print warn "Skipping: Cannot access this Zone (may lack permission)."
            continue
        fi

        while read -r line; do
            [ -z "$line" ] && continue

            local record_id
            local hostname
            local target
            local uuid

            record_id=$(echo "$line" | grep -oE '"id":"[a-f0-9]+"' | cut -d'"' -f4)
            hostname=$(echo "$line" | grep -oE '"name":"[^"]+"' | cut -d'"' -f4)
            target=$(echo "$line" | grep -oE '"content":"[^"]+"' | cut -d'"' -f4)
            uuid=${target%%.*}

            if ! echo "$alive_tunnels" | grep -q "$uuid"; then
                found_any=true
                echo ""
                echo -e "${YELLOW}⚠️  Found orphan DNS:${NC}"
                echo "  Hostname : $hostname"
                echo "  Target   : $target"
                echo "  Zone     : $zone_name"

                if ui_confirm "Delete this DNS?"; then
                    if _cf_api_call "DELETE" "/zones/$zone_id/dns_records/$record_id" >/dev/null; then
                        ui_print success "Deleted $hostname"
                    else
                        ui_print error "Failed to delete: $hostname"
                    fi
                fi
            fi
        done < <(echo "$dns_json" | grep -oE '"id":"[a-f0-9]+".*"type":"CNAME".*"content":"[^ "]+cfargotunnel.com"')

    done < <(echo "$zones_json" | grep -oE '"id":"[a-f0-9]+","name":"[^"]+"' | sed 's/"id":"//;s/","name":"/ /;s/"//')

    echo ""
    if [ "$found_any" = false ]; then
        ui_print success "Scan complete, no orphan DNS records found."
    else
        ui_print success "Cleanup work completed."
    fi
    ui_pause
}
