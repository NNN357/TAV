#!/bin/bash
# TAV-X Universal Installer & Launcher

DEFAULT_POOL=(
    "https://ghproxy.net/"
    "https://mirror.ghproxy.com/"
    "https://ghproxy.cc/"
    "https://gh.likk.cc/"
    "https://hub.gitmirror.com/"
    "https://hk.gh-proxy.com/"
    "https://ui.ghproxy.cc/"
    "https://gh-proxy.com/"
    "https://gh.jasonzeng.dev/"
    "https://gh.idayer.com/"
    "https://edgeone.gh-proxy.com/"
    "https://ghproxy.site/"
    "https://www.gitwarp.com/"
    "https://cors.isteed.cc/"
    "https://ghproxy.vip/"
    "https://github.com/"
)

PROXY_PORTS=(
    "7890:http"
    "7891:http"
    "10809:http"
    "10808:http"
    "20171:http"
    "20170:http"
    "9090:http"
    "8080:http"
    "1080:http"
    "2080:http"
)

: "${REPO_PATH:=Future-404/TAV-X.git}"
: "${TAV_VERSION:=Latest}"

export TAVX_DIR="${HOME}/.tav_x"

FORCE_UPDATE=false
if [ "$TAVX_INSTALLER_MODE" == "true" ]; then FORCE_UPDATE=true; fi
if [[ "$1" == "update" || "$1" == "install" || "$1" == "reinstall" ]]; then FORCE_UPDATE=true; fi

if [ -f "$TAVX_DIR/core/main.sh" ] && [ "$FORCE_UPDATE" == "false" ]; then
    exec bash "$TAVX_DIR/core/main.sh" "$@"
fi

echo -e "\033[1;36m>>> TAV-X Installer initializing...\033[0m"
if [ -n "$TERMUX_VERSION" ]; then
    pkg update -y >/dev/null 2>&1
    if ! command -v git &> /dev/null; then pkg install git -y; fi
    if ! command -v gum &> /dev/null; then pkg install gum -y; fi
else
    if command -v apt-get &> /dev/null; then
        if ! command -v git &> /dev/null; then 
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install git -y
        fi
    fi
fi

DL_URL=""

probe_local_ports() {
    for entry in "${PROXY_PORTS[@]}"; do
        port=${entry%%:*}
        if timeout 0.1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            echo -e "\033[1;32m✔ Local proxy port detected: $port\033[0m"
            export http_proxy="http://127.0.0.1:$port"
            export https_proxy="http://127.0.0.1:$port"
            return 0
        fi
    done
    return 1
}

check_github_speed() {
    local THRESHOLD=819200
    local CLEAN_REPO=${REPO_PATH%.git} 
    local TEST_URL="https://raw.githubusercontent.com/${CLEAN_REPO}/main/st.sh"
    
    echo -e "\033[1;33mTesting GitHub direct connection speed (threshold: 800KB/s)...\033[0m"
    
    local speed=$(curl -s -L -m 5 -w "%{speed_download}\n" -o /dev/null "$TEST_URL" 2>/dev/null)
    speed=${speed%.*}
    if [ -z "$speed" ]; then speed=0; fi
    local speed_kb=$((speed / 1024))
    
    if [ "$speed" -ge "$THRESHOLD" ]; then
        echo -e "\033[1;32m✔ Speed acceptable: ${speed_kb}KB/s (using direct connection)\033[0m"
        return 0
    else
        if [ "$speed" -eq 0 ]; then
             echo -e "\033[1;31m✘ Cannot connect to GitHub.\033[0m"
        else
             echo -e "\033[1;33m⚠ Speed insufficient: ${speed_kb}KB/s (below 800KB/s), switching to mirror selection.\033[0m"
        fi
        return 1
    fi
}

select_mirror_interactive() {
    echo -e "\n\033[1;36m>>> Starting fallback: Mirror source speed test\033[0m"
    echo -e "\033[1;33mRunning concurrent speed tests, please wait...\033[0m"
    local tmp_file=$(mktemp)
    
    for url in "${DEFAULT_POOL[@]}"; do
        (
            start=$(date +%s%N)
            if curl -fsL -I -m 2 "${url}https://github.com/${REPO_PATH}" >/dev/null 2>&1; then
                end=$(date +%s%N)
                dur=$(( (end - start) / 1000000 ))
                echo "$dur $url" >> "$tmp_file"
            fi
        ) &
    done
    wait
    
    local VALID_URLS=()
    if [ -s "$tmp_file" ]; then
        sort -n "$tmp_file" -o "$tmp_file"
        echo -e "\n\033[1;36mAvailable mirror list:\033[0m"
        local i=1
        while read -r dur url; do
            local mark="\033[1;32m🟢"
            [ "$dur" -gt 800 ] && mark="\033[1;33m🟡"
            [ "$dur" -gt 1500 ] && mark="\033[1;31m🔴"
            local domain=$(echo "$url" | awk -F/ '{print $3}')
            echo -e "$i. $mark ${dur}ms \033[0m| $domain"
            VALID_URLS+=("$url")
            ((i++))
        done < "$tmp_file"
    else
        echo -e "\033[1;31m✘ All mirrors timed out. Forcing official source.\033[0m"
        DL_URL="https://github.com/${REPO_PATH}"
        rm -f "$tmp_file"
        return
    fi
    rm -f "$tmp_file"
    
    echo -e "$i. 🌐 Official Source"
    VALID_URLS+=("https://github.com/")
    
    echo ""
    read -p "Select mirror number [default 1]: " USER_CHOICE
    USER_CHOICE=${USER_CHOICE:-1}
    
    if [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] && [ "$USER_CHOICE" -ge 1 ] && [ "$USER_CHOICE" -le "${#VALID_URLS[@]}" ]; then
        local best_url="${VALID_URLS[$((USER_CHOICE-1))]}"
        if [[ "$best_url" == *"github.com"* ]]; then
            DL_URL="https://github.com/${REPO_PATH}"
        else
            DL_URL="${best_url}https://github.com/${REPO_PATH}"
        fi
        echo -e "\033[1;32m✔ Selected: $best_url\033[0m"
    else
        echo -e "\033[1;31mInvalid selection, using first option by default.\033[0m"
        DL_URL="${VALID_URLS[0]}https://github.com/${REPO_PATH}"
    fi
}

if probe_local_ports; then
    DL_URL="https://github.com/${REPO_PATH}"
elif check_github_speed; then
    DL_URL="https://github.com/${REPO_PATH}"
else
    select_mirror_interactive
fi

echo -e "\n\033[1;36m>>> Processing Core ($TAV_VERSION)...\033[0m"
echo -e "Source: $DL_URL"

INSTALL_SUCCESS=false
if [ -d "$TAVX_DIR/.git" ]; then
    echo -e "\033[1;33mExisting installation detected, attempting repair update for TAV-X...\033[0m"
    cd "$TAVX_DIR" || exit
    git remote set-url origin "$DL_URL"
    if git fetch origin main && git reset --hard origin/main; then
        INSTALL_SUCCESS=true
    fi
else
    if git clone --depth 1 "$DL_URL" "$TAVX_DIR"; then
        INSTALL_SUCCESS=true
    fi
fi

if [ "$INSTALL_SUCCESS" = true ]; then
    (
        cd "$TAVX_DIR" || exit
        git remote set-url origin "https://github.com/${REPO_PATH}"
    )
    
    chmod +x "$TAVX_DIR/st.sh" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    
    if [ ! -f "$HOME/.bashrc" ]; then
        touch "$HOME/.bashrc"
    fi

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc_file" ]; then
            sed -i '/alias st=/d' "$rc_file" 2>/dev/null
            echo "alias st='bash $TAVX_DIR/st.sh'" >> "$rc_file"
        fi
    done

    echo -e "\n\033[1;32m✔ Installation Complete!\033[0m"
    echo -e "------------------------------------------------"
    echo -e "💡 Run the following command to activate the shortcut:"
    echo -e "   \033[1;33msource ~/.bashrc\033[0m"
    echo -e ""
    echo -e "🚀 Then simply type \033[1;33mst\033[0m to launch the script menu"
    echo -e "------------------------------------------------"
    exit 0
else
    echo -e "\n\033[1;31m✘ Installation Failed.\033[0m"
    exit 1
fi
