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
    
    check_dependencies() {
        if [ "$DEPS_CHECKED" == "true" ]; then return 0; fi
    
        local MISSING_PKGS=""
        
        local HAS_NODE=false; check_node_version && HAS_NODE=true
        local HAS_GIT=false; command -v git &> /dev/null && HAS_GIT=true
        local HAS_YQ=false; command -v yq &> /dev/null && HAS_YQ=true
        local HAS_GUM=false; command -v gum &> /dev/null && HAS_GUM=true
        local HAS_TAR=false; command -v tar &> /dev/null && HAS_TAR=true
        local HAS_LESS=false; command -v less &> /dev/null && HAS_LESS=true
    
        if $HAS_NODE && $HAS_GIT && $HAS_YQ && $HAS_GUM && $HAS_TAR && $HAS_LESS; then
            export DEPS_CHECKED="true"
            return 0
        fi
    
        ui_header "Environment Initialization"
        echo -e "${BLUE}[INFO]${NC} Checking full component suite ($OS_TYPE)..."
    
        if ! $HAS_LESS; then
            echo -e "${YELLOW}[WARN]${NC} less not found (log pager)"
            MISSING_PKGS="$MISSING_PKGS less"
        fi
        
        if ! $HAS_YQ; then
            echo -e "${YELLOW}[WARN]${NC} yq not found (YAML tool)"
            install_yq
            command -v yq &>/dev/null && HAS_YQ=true
        fi
    
        if ! $HAS_NODE; then 
            echo -e "${YELLOW}[WARN]${NC} Node.js not found or version too low (<v20)"
            if [ "$OS_TYPE" == "TERMUX" ]; then 
                MISSING_PKGS="$MISSING_PKGS nodejs"
            else 
                echo -e "${YELLOW}Linux environment detected, auto-configure NodeSource repository to install latest Node.js?${NC}"
                if ui_confirm "This requires root privileges (sudo) and will modify system source list."; then
                    setup_nodesource
                    if check_node_version; then HAS_NODE=true; else MISSING_PKGS="$MISSING_PKGS nodejs"; fi
                else
                     echo -e "${RED}[ERROR]${NC} Skipping Node.js configuration. SillyTavern may not start."
                     MISSING_PKGS="$MISSING_PKGS nodejs npm"
                fi
            fi
        fi
    
        if ! $HAS_GIT; then 
            echo -e "${YELLOW}[WARN]${NC} Git not found"
            MISSING_PKGS="$MISSING_PKGS git"
        fi
        
        if ! $HAS_TAR; then MISSING_PKGS="$MISSING_PKGS tar"; fi
    
        if [ "$OS_TYPE" == "TERMUX" ]; then
            if ! $HAS_GUM; then MISSING_PKGS="$MISSING_PKGS gum"; fi
        fi
    
        if [ -n "$MISSING_PKGS" ]; then
            ui_print info "Repairing missing dependencies: $MISSING_PKGS"
            sys_install_pkg "$MISSING_PKGS"
        fi
        
        if [ "$OS_TYPE" == "LINUX" ]; then
            if ! command -v gum &>/dev/null; then install_gum_linux; fi
        fi
        
        if command -v node &> /dev/null && \
           command -v git &> /dev/null && \
           command -v yq &> /dev/null && \
           command -v gum &> /dev/null && \
           command -v less &> /dev/null; then
            
            echo -e "${GREEN}[DONE]${NC} Environment fully repaired!"
            export DEPS_CHECKED="true"
            ui_pause
        else
            echo -e "${RED}[ERROR]${NC} Environment repair incomplete!"
            echo -e "${YELLOW}Please try running install commands manually or check network.${NC}"
            ui_pause
        fi
    }
    export -f check_dependencies
