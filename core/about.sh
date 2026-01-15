#!/bin/bash
# TAV-X Core: About & Support

AUTHOR_QQ="317032529"
GROUP_QQ="616353694"
CONTACT_EMAIL="future_404@outlook.com"
PROJECT_URL="https://github.com/NNN357/TAV"
SLOGAN="Don't let virtual warmth steal the real warmth you deserve in life."
UPDATE_SUMMARY="v3.1.0 Architecture-Level Refactoring Upgrade:
  1. [Refactor] Introduced termux-services (Runit) for daemon processes and crash recovery
  2. [New] Core dependency manifest for instant environment initialization
  3. [New] CLI shortcuts support (st ps, st re, st log, st stop)
  4. [New] Boot auto-start management menu with one-click service toggle
  5. [Optimize] Removed redundant log timestamps, adapted terminal MOTD startup notification"

show_shortcuts_help() {
    ui_header "Shortcut Commands Usage"
    echo -e "${YELLOW}Quick operations without entering main menu - just type in terminal:${NC}"
    echo ""
    printf "  ${CYAN}%-15s${NC} %s\n" "st" "Enter interactive management panel"
    printf "  ${CYAN}%-15s${NC} %s\n" "st ps" "View currently running services"
    printf "  ${CYAN}%-15s${NC} %s\n" "st re" "Restart all running services"
    printf "  ${CYAN}%-15s${NC} %s\n" "st stop" "Stop all services at once"
    printf "  ${CYAN}%-15s${NC} %s\n" "st update" "Force enter script update mode"
    printf "  ${CYAN}%-15s${NC} %s\n" "st log" "View available app IDs for logs"
    printf "  ${CYAN}%-15s${NC} %s\n" "st log [ID]" "Monitor specified app logs in real-time"
    echo ""
    echo -e "${BLUE}💡 Tip:${NC} Press ${YELLOW}q${NC} to exit log monitoring."
    ui_pause
}

show_about_page() {
    ui_header "Help & Support"

    if [ "$HAS_GUM" = true ]; then
        echo ""
        gum style --foreground 212 --bold "  🚀 Update Preview"
        gum style --foreground 250 --padding "0 2" "• $UPDATE_SUMMARY"
        echo ""

        local label_style="gum style --foreground 99 --width 10"
        local value_style="gum style --foreground 255"

        echo -e "  $($label_style "Author QQ:")  $($value_style "$AUTHOR_QQ")"
        echo -e "  $($label_style "QQ Group:")  $($value_style "$GROUP_QQ")"
        echo -e "  $($label_style "Email:")  $($value_style "$CONTACT_EMAIL")"
        echo -e "  $($label_style "Project:")  $($value_style "$PROJECT_URL")"
        echo ""
        echo ""

        gum style \
            --border rounded \
            --border-foreground 82 \
            --padding "1 4" \
            --margin "0 2" \
            --align center \
            --foreground 82 \
            --bold \
            "$SLOGAN"

    else
        local C_BRIGHT_GREEN='\033[1;32m'
        
        echo -e "${YELLOW}🚀 Update Preview:${NC}"
        echo -e "   $UPDATE_SUMMARY"
        echo ""
        echo "----------------------------------------"
        echo -e "👤 Author QQ:  ${CYAN}$AUTHOR_QQ${NC}"
        echo -e "💬 QQ Group: ${CYAN}$GROUP_QQ${NC}"
        echo -e "📮 Email: ${CYAN}$CONTACT_EMAIL${NC}"
        echo -e "🐙 Project: ${BLUE}$PROJECT_URL${NC}"
        echo "----------------------------------------"
        echo ""
        echo -e "   ${C_BRIGHT_GREEN}\"$SLOGAN\"${NC}"
        echo ""
    fi

    echo ""
    local ACTION=""
    
    if [ "$HAS_GUM" = true ]; then
        ACTION=$(gum choose "🔙 Return to Main Menu" "⌨️ Shortcut Commands" "🔥 Join QQ Group" "🐙 GitHub Project Page")
    else
        echo "1. Return to Main Menu"
        echo "2. ⌨️  Shortcut Commands"
        echo "3. Join QQ Group"
        echo "4. Open GitHub Project Page"
        read -p "Please select: " idx
        case "$idx" in
            "2") ACTION="Shortcut Commands" ;;
            "3") ACTION="Join QQ Group" ;;
            "4") ACTION="GitHub" ;;
            *)   ACTION="Return" ;;
        esac
    fi

    case "$ACTION" in
        *"Shortcut"*)
            show_shortcuts_help
            show_about_page
            ;;
        *"QQ Group"*)
            ui_print info "Attempting to launch QQ..."
            local qq_scheme="mqqapi://card/show_pslcard?src_type=internal&version=1&uin=${GROUP_QQ}&card_type=group&source=qrcode"
            if command -v termux-open &> /dev/null; then
                termux-open "$qq_scheme"
                if command -v termux-clipboard-set &> /dev/null; then
                    termux-clipboard-set "$GROUP_QQ"
                    ui_print success "Group number copied to clipboard!"
                fi
            else
                ui_print warn "termux-tools not detected, cannot auto-launch."
                echo -e "Please manually add group number: ${CYAN}$GROUP_QQ${NC}"
            fi
            ui_pause
            ;;
            
        *"GitHub"*)
            termux-open "$PROJECT_URL" 2>/dev/null || start "$PROJECT_URL" 2>/dev/null
            ui_print info "Attempted to open link in browser."
            ui_pause
            ;;
            
        *) return ;;
    esac
}
