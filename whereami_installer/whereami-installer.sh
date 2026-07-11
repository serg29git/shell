#!/bin/bash
# whereami-installer.sh - automatic installer with sudo-first logic

set -e

SCRIPT_NAME="whereami.sh"
MAN_PAGE="whereami.1"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${INSTALLER_DIR}/${SCRIPT_NAME}"
MAN_PATH="${INSTALLER_DIR}/${MAN_PAGE}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Detect distro ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${PRETTY_NAME:-$NAME}"
    else
        DISTRO="unknown"
    fi
    echo "detected distro: ${DISTRO}"
}

# --- Find best directory for binary ---
find_bin_dir() {
    if [ -d "/usr/local/bin" ]; then
        echo "/usr/local/bin"
    elif [ -d "$HOME/.local/bin" ]; then
        echo "$HOME/.local/bin"
    else
        echo ""
    fi
}

# --- Find best directory for manpage ---
find_man_dir() {
    if [ -d "/usr/share/man/man1" ]; then
        echo "/usr/share/man/man1"
    elif [ -d "$HOME/man/man1" ]; then
        echo "$HOME/man/man1"
    else
        echo ""
    fi
}

# --- Check existing installation ---
check_existing() {
    local dir="$1"
    if [ -f "${dir}/${SCRIPT_NAME}" ]; then
        echo "${dir}/${SCRIPT_NAME}"
    elif command -v whereami &>/dev/null; then
        command -v whereami
    else
        echo ""
    fi
}

# --- Remove with sudo-first fallback ---
remove_with_sudo_fallback() {
    local path="$1"
    if [ -z "$path" ] || [ ! -f "$path" ]; then
        return 0
    fi
    echo "deleting $path"
    if sudo rm -f "$path" 2>/dev/null; then
        echo "done"
    elif rm -f "$path" 2>/dev/null; then
        echo "done"
    else
        warn "could not delete $path"
        return 1
    fi
    return 0
}

# --- Install with sudo-first fallback ---
install_with_sudo_fallback() {
    local src="$1"
    local dst="$2"
    local mode="$3"
    
    if sudo cp "$src" "$dst" 2>/dev/null; then
        sudo chmod "$mode" "$dst" 2>/dev/null || true
        return 0
    elif cp "$src" "$dst" 2>/dev/null; then
        chmod "$mode" "$dst" 2>/dev/null || true
        return 0
    else
        return 1
    fi
}

# --- Main ---
main() {
    detect_distro
    
    BIN_DIR=$(find_bin_dir)
    MAN_DIR=$(find_man_dir)
    
    # If no bin dir found, ask
    if [ -z "$BIN_DIR" ]; then
        read -p "No default dir found. Enter install directory (e.g., /usr/local/bin): " BIN_DIR
        BIN_DIR="${BIN_DIR/#\~/$HOME}"
    fi
    # Create directory (try with sudo first)
    if ! mkdir -p "$BIN_DIR" 2>/dev/null; then
        sudo mkdir -p "$BIN_DIR" || error "Cannot create $BIN_DIR (even with sudo)"
    fi
    
    echo "found dir for whereami installation: $BIN_DIR"
    
    # If no man dir found, ask (or skip)
    if [ -z "$MAN_DIR" ]; then
        read -p "No default man dir found. Enter man directory (e.g., /usr/share/man/man1) or leave empty to skip: " MAN_DIR
        if [ -n "$MAN_DIR" ]; then
            MAN_DIR="${MAN_DIR/#\~/$HOME}"
            if ! mkdir -p "$MAN_DIR" 2>/dev/null; then
                sudo mkdir -p "$MAN_DIR" 2>/dev/null || warn "Cannot create $MAN_DIR. Skipping manpage."
            fi
        fi
    fi
    
    if [ -n "$MAN_DIR" ]; then
        echo "found dir for manpage: $MAN_DIR"
    fi
    
    # Check existing
    EXISTING_BIN=$(check_existing "$BIN_DIR")
    if [ -n "$EXISTING_BIN" ]; then
        echo "another whereami was found: $EXISTING_BIN"
    fi
    
    # Ask for installation
    echo
    read -p "install whereami? [Y/n]: " install_choice
    if [[ "$install_choice" =~ ^[Nn]$ ]]; then
        echo "Aborting."
        exit 0
    fi
    
    # Remove existing if any
    if [ -n "$EXISTING_BIN" ]; then
        remove_with_sudo_fallback "$EXISTING_BIN"
    fi
    
    # Install binary
    echo "Installing..."
    if install_with_sudo_fallback "$SCRIPT_PATH" "${BIN_DIR}/${SCRIPT_NAME}" 755; then
        info "installed whereami into $BIN_DIR"
    else
        error "could not install whereami to $BIN_DIR (even with sudo). Aborting."
    fi
    
    # Install manpage if MAN_DIR is set
    if [ -n "$MAN_DIR" ]; then
        if [ -f "$MAN_PATH" ]; then
            if install_with_sudo_fallback "$MAN_PATH" "${MAN_DIR}/${MAN_PAGE}" 644; then
                info "installed manpage into $MAN_DIR"
            else
                warn "could not install manpage to $MAN_DIR"
            fi
        else
            warn "manpage file $MAN_PAGE not found in installer directory."
        fi
    fi
    
    echo
    echo "installed. options:"
    echo "  1  test whereami"
    echo "  9  delete whereami (for some reason)"
    echo "  0  exit"
    echo
    read -p ": " choice
    case "$choice" in
        1)
            if command -v whereami &>/dev/null; then
                whereami
            else
                warn "whereami not in PATH. Try running ${BIN_DIR}/${SCRIPT_NAME}"
            fi
            ;;
        9)
            remove_with_sudo_fallback "${BIN_DIR}/${SCRIPT_NAME}"
            if [ -n "$MAN_DIR" ] && [ -f "${MAN_DIR}/${MAN_PAGE}" ]; then
                remove_with_sudo_fallback "${MAN_DIR}/${MAN_PAGE}"
            fi
            ;;
        0)
            echo "Exiting."
            ;;
        *)
            echo "Invalid option. Exiting."
            ;;
    esac
}

main "$@"
