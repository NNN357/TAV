#!/bin/bash
# TAV-X Core: About & Support

AUTHOR_QQ="317032529"
GROUP_QQ="616353694"
CONTACT_EMAIL="future_404@outlook.com"
PROJECT_URL="https://github.com/NNN357/TAV"
SLOGAN="Don't let virtual warmth steal the real warmth you deserve in life."
UPDATE_SUMMARY="v3.0 TMIS Architecture Refactoring Milestone:
  1. [Refactor] Core decentralization, implementing 'kernel+app' plugin architecture
  2. [New] Unified App Center, supporting local scanning, remote fetching, tiered installation
  3. [Optimize] Automated log black box system, supporting auto-dump on task failure and history archiving
  4. [Standardize] Unified path standards across all modules (apps/, logs/, run/), fully compatible with legacy data
  5. [Migration] All modules promoted: Tavern, ClewdR, Mihomo, GCLI, AutoGLM, Gemini"

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
        ACTION=$(gum choose "🔙 Return to Main Menu" "🔥 Join QQ Group" "🐙 GitHub Project Page")
    else
        echo "1. Return to Main Menu"
        echo "2. Join QQ Group"
        echo "3. Open GitHub Project Page"
        read -p "Please select: " idx
        case "$idx" in
            "2") ACTION="Join QQ Group" ;;
            "3") ACTION="GitHub" ;;
            *)   ACTION="Return" ;;
        esac
    fi

    case "$ACTION" in
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
