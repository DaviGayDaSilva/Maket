#!/data/data/com.termux/files/usr/bin/bash
#
# install.sh - Install maket to Termux
#

set -e

# Get project root directory (two levels up from scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
INSTALL_DIR="${TERMUX_PREFIX}/bin"
LIB_DIR="${TERMUX_PREFIX}/lib/maket"
SHARE_DIR="${TERMUX_PREFIX}/share/maket"

echo "Installing maket from: ${SCRIPT_DIR}"
echo ""

# Create directories
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LIB_DIR}"
mkdir -p "${SHARE_DIR}"

# Install main script
echo "Installing bin/maket..."
install -m 755 "${SCRIPT_DIR}/bin/maket" "${INSTALL_DIR}/maket"

# Install library
echo "Installing lib/maket-lib.sh..."
install -m 644 "${SCRIPT_DIR}/lib/maket-lib.sh" "${LIB_DIR}/maket-lib.sh"

# Create symlinks
ln -sf "${INSTALL_DIR}/maket" "${TERMUX_PREFIX}/bin/maket"

# Make executable
chmod +x "${INSTALL_DIR}/maket"

echo "maket installed successfully!"
echo ""
echo "Usage:"
echo "  maket run <iso_file>           - Run Linux ISO"
echo "  maket run --rootfs <dir>      - Run rootfs directory"
echo "  maket install-deps          - Install dependencies"
echo "  maket list                  - List available ISOs"
echo "  maket status                - Show status"
echo ""
echo "Examples:"
echo "  maket run archlinux.iso"
echo "  maket run --rootfs /sdcard/Download/ubuntu --display :2"