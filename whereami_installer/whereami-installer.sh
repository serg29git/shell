#!/bin/bash
# whereami-installer.sh
# Interactive installer for whereami
# Usage: ./whereami-installer.sh

set -e

SCRIPT_NAME="whereami.sh"
MAN_PAGE="whereami.1"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${INSTALLER_DIR}/${SCRIPT_NAME}"
MAN_PATH="${INSTALLER_DIR}/${MAN_PAGE}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header(){ echo -e "${BLUE}$1${NC}"; }

# --- Detect distro from /etc/os-release ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${PRETTY_NAME:-$NAME}"
    else
        DISTRO="Unknown (no /etc/os-release)"
    fi
    header "detected distro: ${DISTRO}"
}

# --- Check for existing whereami ---
check_existing() {
    local target_dir="$1"
    local found=""
    if [ -f "${target_dir}/${SCRIPT_NAME}" ]; then
        found="${target_dir}/${SCRIPT_NAME}"
    elif command -v whereami &>/dev/null; then
        found=$(command -v whereami)
    fi
    echo "$found"
}

# --- Check for existing man page ---
check_man_existing() {
    local man_dir="$1"
    if [ -f "${man_dir}/${MAN_PAGE}" ]; then
        echo "${man_dir}/${MAN_PAGE}"
    else
        echo ""
    fi
}

# --- Ask for install directory ---
ask_install_dir() {
    echo
    read -p "Enter the directory where you want to install whereami (e.g., /usr/local/bin): " INSTALL_DIR
    if [ -z "$INSTALL_DIR" ]; then
        warn "No directory entered. Defaulting to /usr/local/bin"
        INSTALL_DIR="/usr/local/bin"
    fi
    # Expand ~ if present
    INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
    mkdir -p "$INSTALL_DIR" || error "Cannot create directory $INSTALL_DIR"
    info "Install directory: $INSTALL_DIR"
}

# --- Ask for man page directory ---
ask_man_dir() {
    echo
    read -p "Enter the man page directory (e.g., /usr/share/man/man1) or leave empty to skip: " MAN_DIR
    if [ -n "$MAN_DIR" ]; then
        MAN_DIR="${MAN_DIR/#\~/$HOME}"
        mkdir -p "$MAN_DIR" || warn "Cannot create man directory $MAN_DIR. Man page will be skipped."
    else
        MAN_DIR=""
        warn "No man directory provided. Man page will be skipped."
    fi
}

# --- Remove existing installation ---
remove_existing() {
    local path="$1"
    if [ -n "$path" ] && [ -f "$path" ]; then
        rm -f "$path"
        info "Removed existing whereami from $path"
    fi
}

# --- Remove existing man page ---
remove_man_existing() {
    local path="$1"
    if [ -n "$path" ] && [ -f "$path" ]; then
        rm -f "$path"
        info "Removed existing man page from $path"
    fi
}

# --- Install whereami ---
install_whereami() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        error "Script ${SCRIPT_NAME} not found in installer directory: $INSTALLER_DIR"
    fi
    cp "$SCRIPT_PATH" "${INSTALL_DIR}/${SCRIPT_NAME}" || error "Failed to copy ${SCRIPT_NAME}"
    chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
    info "Installed whereami to ${INSTALL_DIR}/${SCRIPT_NAME}"
}

# --- Install man page ---
install_man() {
    if [ -z "$MAN_DIR" ]; then
        warn "Man directory not set. Skipping man page installation."
        return
    fi
    if [ ! -f "$MAN_PATH" ]; then
        warn "Man page file ${MAN_PAGE} not found in installer directory."
        return
    fi
    cp "$MAN_PATH" "${MAN_DIR}/${MAN_PAGE}" || warn "Failed to copy man page."
    info "Installed man page to ${MAN_DIR}/${MAN_PAGE}"
}

# --- Test whereami ---
test_whereami() {
    if command -v whereami &>/dev/null; then
        echo "Running whereami:"
        whereami
    else
        warn "whereami not found in PATH. Try running it directly:"
        if [ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
            echo "${INSTALL_DIR}/${SCRIPT_NAME}"
        else
            error "whereami not found."
        fi
    fi
}

# --- Remove whereami and man page ---
remove_all() {
    local target_dir="$1"
    local man_dir="$2"
    if [ -f "${target_dir}/${SCRIPT_NAME}" ]; then
        rm -f "${target_dir}/${SCRIPT_NAME}"
        info "Removed ${SCRIPT_NAME} from ${target_dir}"
    fi
    if [ -n "$man_dir" ] && [ -f "${man_dir}/${MAN_PAGE}" ]; then
        rm -f "${man_dir}/${MAN_PAGE}"
        info "Removed ${MAN_PAGE} from ${man_dir}"
    fi
}

# --- Remove installer folder ---
remove_installer_folder() {
    local installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    warn "This will remove the entire installer folder: $installer_dir"
    read -p "Are you sure? This cannot be undone. [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        cd /tmp || error "Cannot change directory"
        rm -rf "$installer_dir"
        info "Removed installer folder: $installer_dir"
    else
        info "Aborted removal of installer folder."
    fi
}

# --- Main menu after installation ---
main_menu() {
    local target_dir="$1"
    local man_dir="$2"
    while true; do
        echo
        header "=== post install options ==="
        echo "  1) test whereami and remove installer folder"
        echo "  2) test whereami"
        echo "  8) remove whereami and man page"
        echo "  9) remove whereami, man page, and installer folder"
        echo "  0) exit"
        echo "  01) exit and remove installer folder"
        echo
        read -p "Select option [0,1,2,8,9,01]: " choice
        case "$choice" in
            1)
                test_whereami
                remove_installer_folder
                exit 0
                ;;
            2)
                test_whereami
                ;;
            8)
                remove_all "$target_dir" "$man_dir"
                ;;
            9)
                remove_all "$target_dir" "$man_dir"
                remove_installer_folder
                exit 0
                ;;
            0)
                echo "Exiting."
                exit 0
                ;;
            01)
                remove_installer_folder
                exit 0
                ;;
            *)
                warn "Invalid option. Please choose 0,1,2,8,9, or 01."
                ;;
        esac
    done
}

# --- Main installation flow ---
main() {
    detect_distro

    # Check for existing whereami in common places
    existing_path=$(check_existing "/usr/local/bin")
    if [ -z "$existing_path" ]; then
        existing_path=$(check_existing "$HOME/.local/bin")
    fi

    # Check for existing man page in common places
    existing_man=""
    if [ -d "/usr/share/man/man1" ]; then
        existing_man=$(check_man_existing "/usr/share/man/man1")
    fi

    if [ -n "$existing_path" ] || [ -n "$existing_man" ]; then
        warn "whereami was found."
        if [ -n "$existing_path" ]; then
            echo "  Found binary: $existing_path"
        fi
        if [ -n "$existing_man" ]; then
            echo "  Found man page: $existing_man"
        fi
        read -p "Remove previous and install this one? [y/N]: " remove_choice
        if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
            if [ -n "$existing_path" ]; then
                remove_existing "$existing_path"
            fi
            if [ -n "$existing_man" ]; then
                remove_man_existing "$existing_man"
            fi
        else
            info "Keeping existing installation. Aborting."
            exit 0
        fi
    fi

    ask_install_dir
    ask_man_dir

    echo
    read -p "Install whereami? [Y/n]: " install_confirm
    if [[ "$install_confirm" =~ ^[Nn]$ ]]; then
        echo "Aborting."
        exit 0
    fi

    echo "Installing whereami..."
    install_whereami
    install_man

    info "Installation complete."

    main_menu "$INSTALL_DIR" "$MAN_DIR"
}

main "$@"
