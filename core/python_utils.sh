#!/bin/bash
# TAV-X Core: Python Utilities

[ -n "$_TAVX_PY_UTILS_LOADED" ] && return
_TAVX_PY_UTILS_LOADED=true

source "$TAVX_DIR/core/utils.sh"

PY_CONFIG="$TAVX_DIR/config/python.conf"

select_pypi_mirror() {
    local current_mirror=""
    if [ -f "$PY_CONFIG" ]; then
        current_mirror=$(grep "^PYPI_INDEX_URL=" "$PY_CONFIG" | cut -d'=' -f2)
    fi

    if [ "$1" == "quiet" ]; then
        if [ -n "$current_mirror" ]; then
            export PIP_INDEX_URL="$current_mirror"
            return 0
        fi
        return 1
    fi

    ui_header "PyPI Mirror Source Settings"
    echo -e "Current source: ${CYAN}${current_mirror:-Official}${NC}"
    echo "----------------------------------------"

    local CHOICE=$(ui_menu "Please select mirror source" \
        "🇨🇳 Tsinghua University" \
        "🇨🇳 Alibaba Cloud" \
        "🇨🇳 Tencent Cloud" \
        "🌐 Official Source" \
        "✏️  Custom Input" \
        "🔙 Return" \
    )
    if [[ "$CHOICE" == *"Return"* ]]; then return; fi
    
    local new_url=""
    case "$CHOICE" in
        *"Tsinghua"*) new_url="https://pypi.tuna.tsinghua.edu.cn/simple" ;; 
        *"Alibaba"*) new_url="https://mirrors.aliyun.com/pypi/simple/" ;; 
        *"Tencent"*) new_url="https://mirrors.cloud.tencent.com/pypi/simple" ;; 
        *"Official"*) new_url="https://pypi.org/simple" ;; 
        *"Custom"*) new_url=$(ui_input "Please enter full Index URL" "" "false") ;; 
    esac

    if [ -n "$new_url" ]; then
        write_env_safe "$PY_CONFIG" "PYPI_INDEX_URL" "$new_url"
        ui_print success "Preferred source saved."
        if command -v pip &>/dev/null; then
            pip config set global.index-url "$new_url" >/dev/null 2>&1
        fi
    fi
}
export -f select_pypi_mirror

ensure_python_build_deps() {
    if [ "$OS_TYPE" == "TERMUX" ]; then
        local missing=false
        for cmd in rustc cargo clang make; do
            if ! command -v $cmd &>/dev/null; then missing=true; break; fi
        done
        
        if [ "$missing" == "false" ]; then
            local test_file="$TMP_DIR/rust_test_$"
            echo 'fn main(){}' > "$test_file.rs"
            if ! rustc "$test_file.rs" -o "$test_file.bin" >/dev/null 2>&1; then
                missing=true
            fi
            rm -f "$test_file.rs" "$test_file.bin"
        fi

        if [ "$missing" == "true" ]; then
            ui_print warn "Build environment missing or corrupted, attempting auto-repair..."
            sys_remove_pkg "rust"
            if sys_install_pkg "rust binutils clang make python"; then
                ui_print success "Build environment repaired successfully."
            else
                return 1
            fi
        fi
    else
        local missing_sys=false
        if ! command -v make &>/dev/null; then missing_sys=true; fi
        if ! command -v gcc &>/dev/null; then missing_sys=true; fi
        
        if [ "$missing_sys" = true ]; then
             ui_print warn "Detected missing basic build tools."
             if ui_confirm "Try installing build-essential?"; then
                 sys_install_pkg "build-essential python3-dev"
             fi
        fi
        
        if ! command -v cargo &>/dev/null || ! command -v rustc &>/dev/null; then
            ui_print warn "Rust build environment not detected."
            if ui_confirm "Auto-install Rust?"; then
                ui_print info "Downloading and installing Rustup..."
                if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
                    source "$HOME/.cargo/env"
                    if command -v rustc &>/dev/null; then
                        ui_print success "Rust installed successfully."
                    else
                        ui_print error "Rustup script completed but rustc not detected, please check if ~/.cargo/bin is in PATH."
                    fi
                else
                    ui_print error "Rustup download/install failed."
                fi
            else
                ui_print warn "Skipping Rust installation, subsequent dependency compilation may fail."
            fi
        fi
    fi
    return 0
}
export -f ensure_python_build_deps

create_venv_smart() {
    local venv_path="$1"
    local use_system_site="${2:-false}"
    
    if [ "$OS_TYPE" == "TERMUX" ] && [ -z "$2" ]; then
        use_system_site="true"
    fi
    
    if [ -d "$venv_path" ]; then
        safe_rm "$venv_path"
    fi
    
    ensure_python_build_deps
    
    local args=""
    [ "$use_system_site" == "true" ] && args="--system-site-packages"
    python3 -m venv "$venv_path" $args
    
    if [ ! -f "$venv_path/bin/activate" ]; then
        return 1
    fi
    return 0
}
export -f create_venv_smart

install_requirements_smart() {
    local venv_path="$1"
    local req_file="$2"
    local mode="${3:-standard}"
    
    local pypi_url=$(grep "^PYPI_INDEX_URL=" "$PY_CONFIG" 2>/dev/null | cut -d'=' -f2)
    if [ -n "$pypi_url" ]; then
        export PIP_INDEX_URL="$pypi_url"
        export UV_PYPI_MIRROR="$pypi_url" 
    fi

    export PIP_DISABLE_PIP_VERSION_CHECK=1
    
    if [ "$OS_TYPE" == "TERMUX" ] && [ -f "$req_file" ]; then
        local sys_pkgs=""
        
        if grep -qE "^numpy" "$req_file"; then sys_pkgs="$sys_pkgs python-numpy"; fi
        if grep -qE "^pillow" "$req_file"; then sys_pkgs="$sys_pkgs python-pillow"; fi
        if grep -qE "^pandas" "$req_file"; then sys_pkgs="$sys_pkgs python-pandas"; fi
        if grep -qE "^lxml" "$req_file"; then sys_pkgs="$sys_pkgs python-lxml"; fi
        if grep -qE "^cryptography" "$req_file"; then sys_pkgs="$sys_pkgs python-cryptography"; fi
        if grep -qE "^grpcio" "$req_file"; then sys_pkgs="$sys_pkgs python-grpcio"; fi
        
        if [ -n "$sys_pkgs" ]; then
            if command -v ui_print &>/dev/null; then
                ui_print info "Heavy dependencies detected, enabling Termux system source acceleration..."
            else
                echo ">>> Heavy dependencies detected, enabling Termux system source acceleration..."
            fi

            if ! pkg list-repos 2>/dev/null | grep -q "tur"; then
                 sys_install_pkg "tur-repo"
            fi
            
            sys_install_pkg "$sys_pkgs"
        fi
        
        if grep -q "pydantic" "$req_file"; then
            if command -v ui_print &>/dev/null; then
                ui_print info "Compiling pydantic-core for Termux..."
            else
                echo ">>> Compiling pydantic-core for Termux..."
            fi
            ensure_python_build_deps
        fi
    fi

    if [ ! -f "$venv_path/bin/activate" ]; then
        echo "Error: Venv not found at $venv_path"
        return 1
    fi
    
    source "$venv_path/bin/activate"
    
    if [ "$OS_TYPE" == "TERMUX" ] && grep -q "pydantic" "$req_file"; then
        echo ">>> [Termux] Force compiling pydantic-core to fix runtime library compatibility..."
        pip install pydantic-core --no-binary pydantic-core
    fi
    
    if [ "$OS_TYPE" == "TERMUX" ] && [ "$mode" == "compile" ]; then
        export CC="clang"
        export CXX="clang++"
        export MATHLIB="m"
        export PIP_IGNORE_INSTALLED=0 
    fi

    echo ">>> Installing dependencies (Mode: $mode, Index: ${pypi_url:-Default})..."

    if [ "$OS_TYPE" == "LINUX" ]; then
        if ! command -v uv &>/dev/null; then
            echo ">>> [Linux] uv not installed, attempting auto-fetch..."
            curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
            export PATH="$HOME/.cargo/bin:$PATH"
        fi

        if command -v uv &>/dev/null; then
            if ui_stream_task "UV fast install..." "uv pip install -r '$req_file'"; then return 0; else return 1; fi
        fi
    fi
    
    if ui_stream_task "Pip installing dependencies..." "pip install -r '$req_file'"; then
        return 0
    else
        return 1
    fi
}
export -f install_requirements_smart

python_environment_manager_ui() {
    while true; do
        ui_header "Python Infrastructure Management"
        
        local state="stopped"; local text="Environment Missing"; local info=()
        if command -v python3 &>/dev/null; then
            state="success"; text="Environment OK"
            info+=( "Version: $(python3 --version | awk '{print $2}')" )
            command -v pip3 &>/dev/null && info+=( "Pip: Ready" ) || info+=( "Pip: Not Installed" )
        fi
        
        ui_status_card "$state" "$text" "${info[@]}"
        local CHOICE=$(ui_menu "Operation Menu" "🛠️ Install/Repair System Python" "⚙️  Set PyPI Mirror Source" "⚡ Install/Sync UV" "🔍 Environment Diagnostics" "💥 Completely Uninstall Python" "🔙 Return")
        case "$CHOICE" in
            *"Install/Repair"*) 
                source "$TAVX_DIR/core/deps.sh"
                install_python_system ;;
            *"Mirror"*) select_pypi_mirror ;;
            *"Uninstall"*) 
                ui_header "Uninstall Python Environment"
                echo -e "${RED}Warning: This operation will perform the following actions:${NC}"
                if [ "$OS_TYPE" == "TERMUX" ]; then
                    echo -e "  1. Completely remove Python and all its binaries from Termux"
                    echo -e "  2. Clear global Pip cache"
                else
                    echo -e "  1. Clean current user's Python residuals"
                    echo -e "  2. Clear global Pip cache"
                    echo -e "  (Note: For safety, system-level Python3 won't be removed on Linux)"
                fi
                echo ""
                if ! verify_kill_switch; then continue; fi
                
                ui_print info "Executing cleanup..."
                if [ "$OS_TYPE" == "TERMUX" ]; then
                    sys_remove_pkg "python"
                fi
                ui_spinner "Cleaning user data..." "source \"$TAVX_DIR/core/utils.sh\"; safe_rm ~/.cache/pip ~/.local/lib/python*"
                
                ui_print success "Python environment reset to zero."
                ui_pause ;;
            *"UV"*) 
                ui_header "UV Installation"
                if [ "$OS_TYPE" == "TERMUX" ]; then ui_print warn "Termux environment recommends using standard Pip."; else
                    ui_print info "Fetching UV..."
                    curl -LsSf https://astral.sh/uv/install.sh | sh
                fi; ui_pause ;;
            *"Diagnostics"*) 
                ui_header "Environment Diagnostics"
                command -v python3 &>/dev/null && echo -e "Python3: ${GREEN}OK${NC}" || echo -e "Python3: ${RED}Missing${NC}"
                command -v pip3 &>/dev/null && echo -e "Pip3: ${GREEN}OK${NC}" || echo -e "Pip3: ${RED}Missing${NC}"
                [ "$OS_TYPE" == "TERMUX" ] && { command -v rustc &>/dev/null && echo -e "Rustc: ${GREEN}OK${NC}" || echo -e "Rustc: ${RED}Missing${NC}"; }
                ui_pause ;;
            *"Return"*) return ;;
        esac
    done
}
