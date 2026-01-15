#!/bin/bash
# TAV-X Core: Dependency Manager
[ -n "$_TAVX_DEPS_LOADED" ] && return
_TAVX_DEPS_LOADED=true

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

install_gum_linux() {
    echo -e "${YELLOW}>>> Installing Gum (UI Component)...${NC}"
    local ARCH=$(uname -m)
    local G_ARCH=""
    case "$ARCH" in
        x86_64) G_ARCH="x86_64" ;; 
        aarch64) G_ARCH="arm64" ;; 
        *) ui_print error "Auto-install Gum not supported for this architecture: $ARCH"; return 1 ;; 
    esac
    
    local VER="0.17.0"
    local URL="https://github.com/charmbracelet/gum/releases/download/v${VER}/gum_${VER}_Linux_${G_ARCH}.tar.gz"
    
    if [ -n "$SELECTED_MIRROR" ] && [[ "$SELECTED_MIRROR" != *"github.com"* ]]; then
         URL="${SELECTED_MIRROR}${URL}"
    fi

    local DL_CMD="curl -L -o $TMP_DIR/gum.tar.gz '$URL'"
    if ui_stream_task "Downloading Gum (UI Component)..." "$DL_CMD"; then
        cd "$TMP_DIR"
        tar -xzf gum.tar.gz
        local BIN_DIR="/usr/local/bin"
        if [ ! -w "$BIN_DIR" ] && [ -z "$SUDO_CMD" ]; then
             BIN_DIR="$HOME/.local/bin"
             mkdir -p "$BIN_DIR"
        fi
        
        $SUDO_CMD mv gum "$BIN_DIR/gum"
        $SUDO_CMD chmod +x "$BIN_DIR/gum"
        safe_rm gum.tar.gz LICENSE README.md 2>/dev/null
        
        [[ "$BIN_DIR" == *".local"* ]] && [[ ":$PATH:" != *":$BIN_DIR:"* ]] && export PATH="$BIN_DIR:$PATH"
        
        if command -v gum &>/dev/null; then 
            ui_print success "Gum installed successfully"
            return 0
        fi
    fi
    ui_print error "Gum installation failed, please download manually."
    return 1
}
export -f install_gum_linux

install_yq() {
    if command -v yq &>/dev/null; then return 0; fi
    ui_print info "Fetching yq (YAML parser)..."
    
    if [ "$OS_TYPE" == "TERMUX" ]; then
        if sys_install_pkg "yq"; then
            ui_print success "yq installed successfully (pkg)"
            return 0
        fi
        ui_print warn "pkg install failed, switching to manual download mode..."
    fi

    local ARCH=$(uname -m)
    local YQ_ARCH="amd64"
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && YQ_ARCH="arm64"
    
    local BIN_DIR="/usr/local/bin"
    [ "$OS_TYPE" == "TERMUX" ] && BIN_DIR="$PREFIX/bin"
    if [ ! -w "$BIN_DIR" ] && [ -z "$SUDO_CMD" ]; then 
        BIN_DIR="$TAVX_BIN"
        mkdir -p "$BIN_DIR"
    fi

    local VER="v4.44.3"
    local URL="https://github.com/mikefarah/yq/releases/download/${VER}/yq_linux_${YQ_ARCH}"
    local DL_CMD="source \"$TAVX_DIR/core/utils.sh\"; download_file_smart '$URL' '$BIN_DIR/yq'"
    
    if ui_stream_task "Downloading yq component..." "$DL_CMD"; then
        chmod +x "$BIN_DIR/yq"
        if command -v "$BIN_DIR/yq" &>/dev/null; then
            ui_print success "yq installed successfully"
            return 0
        fi
    fi
    ui_print error "yq installation failed, some config features will be unavailable."
    return 1
}
export -f install_yq

install_cloudflared_linux() {
    ui_print info "Fetching Cloudflared ($OS_TYPE)..."
    local ARCH=$(uname -m)
    local C_ARCH=""
    case "$ARCH" in
        x86_64) C_ARCH="amd64" ;; 
        aarch64) C_ARCH="arm64" ;; 
        *) return 1 ;; 
    esac
    
    local URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${C_ARCH}"
    
    if [ -n "$SELECTED_MIRROR" ] && [[ "$SELECTED_MIRROR" != *"github.com"* ]]; then
         URL="${SELECTED_MIRROR}${URL}"
    fi
     
    local DL_CMD="curl -L -o $TMP_DIR/cloudflared '$URL'"
    if ui_stream_task "Downloading Cloudflared..." "$DL_CMD"; then
         local BIN_DIR="/usr/local/bin"
         [ ! -w "$BIN_DIR" ] && [ -z "$SUDO_CMD" ] && BIN_DIR="$HOME/.local/bin"
         mkdir -p "$BIN_DIR"
         
         $SUDO_CMD mv "$TMP_DIR/cloudflared" "$BIN_DIR/cloudflared"
         $SUDO_CMD chmod +x "$BIN_DIR/cloudflared"
         
         [[ "$BIN_DIR" == *".local"* ]] && [[ ":$PATH:" != *":$BIN_DIR:"* ]] && export PATH="$BIN_DIR:$PATH"
         return 0
    fi
    return 1
}
export -f install_cloudflared_linux

check_python_installed() {
    if command -v python3 &>/dev/null && command -v pip3 &>/dev/null; then
        return 0
    fi
    return 1
}
export -f check_python_installed

install_python_system() {
    ui_header "Python Environment Installation"
    ui_print info "Detected current module requires Python runtime..."
    
    if check_python_installed; then
        ui_print success "Python environment ready."
        sleep 1
        return 0
    fi

    echo -e "${YELLOW}About to install Python and its base components...${NC}"
    echo "----------------------------------------"
    
    local pkgs="python"
    [ "$OS_TYPE" == "LINUX" ] && pkgs="python3 python3-pip python3-venv"
    
    if sys_install_pkg "$pkgs"; then
        if check_python_installed; then
            ui_print success "Python installed successfully!"
            pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple >/dev/null 2>&1
            return 0
        fi
    fi
    
    ui_print error "Python installation failed, please check network or software sources."
    ui_pause
    return 1
}

check_node_version() {
    if ! command -v node &> /dev/null; then return 1; fi
    
    local ver=$(node -v | tr -d 'v' | cut -d '.' -f 1)
    
    if [ -z "$ver" ] || [ "$ver" -lt 20 ]; then
        return 1
    fi
    return 0
}

setup_nodesource() {
    ui_print info "Configuring NodeSource repository..."
    sys_install_pkg "curl gnupg ca-certificates" || return 1
    
    local SETUP_CMD="curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO_CMD bash -"
        if ui_stream_task "Injecting NodeSource repository..." "$SETUP_CMD"; then
            if sys_install_pkg "nodejs"; then
                ui_print success "Node.js installation complete."
                return 0
            fi
        fi
        ui_print error "Node.js installation failed, please check network."
        return 1
    }
    export -f setup_nodesource
    
    install_motd_hook() {
        [ "$OS_TYPE" != "TERMUX" ] && return
        
        local hook_file="$PREFIX/etc/profile.d/tavx_status.sh"
        [ -f "$hook_file" ] && return # Already installed, skip
        
        ui_print info "Configuring terminal startup notification..."
        cat > "$hook_file" <<'EOF'
#!/bin/sh
# TAV-X Auto-status check
if [ -d "$PREFIX/var/service" ] && command -v sv >/dev/null; then
    _tx_srvs=""
    for s in "$PREFIX/var/service"/*; do
        if [ -f "$s/.tavx_managed" ] && sv status "$(basename "$s")" 2>/dev/null | grep -q "^run:"; then
            _tx_srvs="$_tx_srvs $(basename "$s")"
        fi
    done
    [ -n "$_tx_srvs" ] && echo -e "\033[1;36m✨ TAV-X background services running:$_tx_srvs\033[0m"
fi
EOF
        chmod +x "$hook_file"
    }
    export -f install_motd_hook

    check_dependencies() {
        if [ "$DEPS_CHECKED" == "true" ]; then 
            [ "$OS_TYPE" == "TERMUX" ] && install_motd_hook
            return 0 
        fi
    
        local MISSING_PKGS=""
        local ALL_FOUND=true
        local NEEDS_UI=false

        for dep in "${CORE_DEPENDENCIES[@]}"; do
            local cmd="${dep%%|*}"
            if [ "$cmd" == "node" ]; then
                if ! check_node_version; then NEEDS_UI=true; break; fi
            elif ! command -v "$cmd" &> /dev/null; then
                NEEDS_UI=true; break
            fi
        done

        if [ "$NEEDS_UI" == "true" ]; then
            ui_header "Environment Initialization"
            echo -e "${BLUE}[INFO]${NC} Checking full core component suite ($OS_TYPE)..."
        fi

        for dep in "${CORE_DEPENDENCIES[@]}"; do
            local cmd="${dep%%|*}"
            local pkg_termux=$(echo "$dep" | cut -d'|' -f2)
            local pkg_linux=$(echo "$dep" | cut -d'|' -f3)
            
            if [ "$cmd" == "node" ]; then
                if ! check_node_version; then
                    if [ "$OS_TYPE" == "TERMUX" ]; then MISSING_PKGS="$MISSING_PKGS $pkg_termux"
                    else
                        [ "$NEEDS_UI" == "false" ] && ui_header "Environment Initialization"
                        echo -e "${YELLOW}Node.js version too low or not installed, configuring NodeSource...${NC}"
                        setup_nodesource || ALL_FOUND=false
                    fi
                fi
                continue
            fi

            if ! command -v "$cmd" &> /dev/null; then
                if [ "$OS_TYPE" == "LINUX" ]; then
                    if [ "$cmd" == "gum" ]; then install_gum_linux || ALL_FOUND=false; continue; fi
                    if [ "$cmd" == "yq" ]; then install_yq || ALL_FOUND=false; continue; fi
                fi

                echo -e "${YELLOW}[WARN]${NC} Dependency not found: $cmd"
                [ "$OS_TYPE" == "TERMUX" ] && MISSING_PKGS="$MISSING_PKGS $pkg_termux" || MISSING_PKGS="$MISSING_PKGS $pkg_linux"
            fi
        done
    
        if [ -n "$MISSING_PKGS" ]; then
            ui_print info "Repairing missing dependencies: $MISSING_PKGS"
            if ! sys_install_pkg "$MISSING_PKGS"; then
                ALL_FOUND=false
            fi
        fi
        
        [ "$OS_TYPE" == "TERMUX" ] && install_motd_hook

        if [ "$ALL_FOUND" == "true" ]; then
            export DEPS_CHECKED="true"
            if [ "$NEEDS_UI" == "true" ]; then
                ui_print success "Environment fully repaired!"
                ui_pause
            fi
            return 0
        else
            ui_print error "Environment repair incomplete, please check error messages."
            ui_pause
            return 1
        fi
    }
    export -f check_dependencies
