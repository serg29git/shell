#!/bin/bash
# whereami-installer.sh - minimal interactive installer

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
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header(){ echo -e "${BLUE}$1${NC}"; }

# --- Detect distro ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${PRETTY_NAME:-$NAME}"
    else
        DISTRO="unknown"
    fi
    echo "found distro: ${DISTRO}"
}

# --- Find best directory for binary ---
find_bin_dir() {
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
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

# --- Check existing whereami ---
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

# --- Check existing manpage ---
check_existing_man() {
    local dir="$1"
    if [ -f "${dir}/${MAN_PAGE}" ]; then
        echo "${dir}/${MAN_PAGE}"
    else
        echo ""
    fi
}

# --- Install whereami ---
install_whereami() {
    local target_dir="$1"
    local use_sudo="$2"
    local dest_file="${target_dir}/${SCRIPT_NAME}"
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        error "Script ${SCRIPT_NAME} not found in installer directory: $INSTALLER_DIR"
    fi
    
    if [ "$use_sudo" = "yes" ]; then
        sudo cp "$SCRIPT_PATH" "$dest_file" || return 1
        sudo chmod +x "$dest_file" || return 1
    else
        cp "$SCRIPT_PATH" "$dest_file" || return 1
        chmod +x "$dest_file" || return 1
    fi
    info "installed whereami into ${target_dir}"
    return 0
}

# --- Install manpage ---
install_manpage() {
    local target_dir="$1"
    local use_sudo="$2"
    local dest_file="${target_dir}/${MAN_PAGE}"
    
    if [ ! -f "$MAN_PATH" ]; then
        warn "man page file ${MAN_PAGE} not found. Skipping."
        return 0
    fi
    
    if [ "$use_sudo" = "yes" ]; then
        sudo cp "$MAN_PATH" "$dest_file" || { warn "Failed to install man page."; return 1; }
    else
        cp "$MAN_PATH" "$dest_file" || { warn "Failed to install man page."; return 1; }
    fi
    info "install manpage into ${target_dir}"
    return 0
}

# --- Remove existing ---
remove_existing() {
    local path="$1"
    if [ -n "$path" ] && [ -f "$path" ]; then
        rm -f "$path"
        info "deleted existing whereami: $path"
    fi
}

# --- Remove existing manpage ---
remove_existing_man() {
    local path="$1"
    if [ -n "$path" ] && [ -f "$path" ]; then
        rm -f "$path"
        info "deleted existing manpage: $path"
    fi
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
            echo "whereami not found."
        fi
    fi
}

# --- Delete whereami and manpage ---
delete_all() {
    local bin_dir="$1"
    local man_dir="$2"
    local bin_path="${bin_dir}/${SCRIPT_NAME}"
    local man_path="${man_dir}/${MAN_PAGE}"
    
    if [ -f "$bin_path" ]; then
        rm -f "$bin_path"
        info "deleted whereami from $bin_path"
    fi
    if [ -n "$man_dir" ] && [ -f "$man_path" ]; then
        rm -f "$man_path"
        info "deleted manpage from $man_path"
    fi
}

# --- Main ---
main() {
    detect_distro
    
    # Find default directories
    BIN_DIR=$(find_bin_dir)
    MAN_DIR=$(find_man_dir)
    
    if [ -n "$BIN_DIR" ]; then
        echo "found dir for whereami installation: $BIN_DIR"
    else
        echo "no default dir found for whereami installation."
        read -p "Enter directory for whereami (e.g., /usr/local/bin): " BIN_DIR
        BIN_DIR="${BIN_DIR/#\~/$HOME}"
        mkdir -p "$BIN_DIR" || error "Cannot create $BIN_DIR"
    fi
    
    if [ -n "$MAN_DIR" ]; then
        echo "found dir for manpage: $MAN_DIR"
    else
        echo "no default dir found for manpage."
        read -p "Enter directory for manpage (e.g., /usr/share/man/man1) or leave empty to skip: " MAN_DIR
        if [ -n "$MAN_DIR" ]; then
            MAN_DIR="${MAN_DIR/#\~/$HOME}"
            mkdir -p "$MAN_DIR" || warn "Cannot create $MAN_DIR. Manpage will be skipped."
        fi
    fi
    
    # Check existing
    EXISTING_BIN=$(check_existing "$BIN_DIR")
    EXISTING_MAN=$(check_existing_man "$MAN_DIR")
    
    if [ -n "$EXISTING_BIN" ] || [ -n "$EXISTING_MAN" ]; then
        echo "another whereami was found. will be removed if user agrees on installation"
        if [ -n "$EXISTING_BIN" ]; then
            echo "  binary: $EXISTING_BIN"
        fi
        if [ -n "$EXISTING_MAN" ]; then
            echo "  manpage: $EXISTING_MAN"
        fi
    fi
    
    # Ask for installation
    echo
    read -p "install whereami into $BIN_DIR? (may require sudo) [Y/n]: " install_choice
    if [[ "$install_choice" =~ ^[Nn]$ ]]; then
        echo "Aborting."
        exit 0
    fi
    
    # Try with sudo
    use_sudo="yes"
    if [ -w "$BIN_DIR" ]; then
        use_sudo="no"
    fi
    
    # If we have existing, remove them
    if [ -n "$EXISTING_BIN" ]; then
        remove_existing "$EXISTING_BIN"
    fi
    if [ -n "$EXISTING_MAN" ]; then
        remove_existing_man "$EXISTING_MAN"
    fi
    
    # Install
    echo "Installing..."
    if ! install_whereami "$BIN_DIR" "$use_sudo"; then
        echo "couldnt install whereami to $BIN_DIR. try without sudo? [y/N]: "
        read try_without_sudo
        if [[ "$try_without_sudo" =~ ^[Yy]$ ]]; then
            use_sudo="no"
            if ! install_whereami "$BIN_DIR" "$use_sudo"; then
                error "Installation failed without sudo. Aborting."
            fi
        else
            error "Installation aborted."
        fi
    fi
    
    # Install manpage if MAN_DIR is set
    if [ -n "$MAN_DIR" ]; then
        if ! install_manpage "$MAN_DIR" "$use_sudo"; then
            warn "Manpage installation failed."
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
            test_whereami
            ;;
        9)
            delete_all "$BIN_DIR" "$MAN_DIR"
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

