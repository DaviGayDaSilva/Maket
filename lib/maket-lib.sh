#!/data/data/com.termux/files/usr/bin/bash
#
# maket-lib.sh - Core library functions for maket
#

# Configuration
LIB_DIR="${SCRIPT_DIR}/../lib"
CONFIG_DIR="${HOME}/.config/maket"
ISO_MOUNT_DIR="${HOME}/.maket/isomnt"
ROOTFS_RUN_DIR="${HOME}/.maket/rootfs_run"
VNC_LOG="${HOME}/.maket/vnc.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running in Termux
check_termux() {
    if [[ ! -d "/data/data/com.termux/files/home" ]]; then
        echo -e "${RED}Error: This script must be run in Termux${NC}"
        exit 1
    fi
}

# Check required dependencies
check_dependencies() {
    local missing=()
    
    for pkg in qemu-system-x86_64 xorriso squashfs-tools parted e2fsprogs; do
        if ! command -v "${pkg}" &>/dev/null; then
            missing+=("${pkg}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing dependencies: ${missing[*]}${NC}"
        echo "Run: maket install-deps"
        return 1
    fi
    return 0
}

# Install required dependencies
install_dependencies() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    
    pkg update -y
    pkg install -y qemu-system-x86_64 xorriso squashfs-tools parted e2fsprogs openssl vinagre
    
    echo -e "${GREEN}Dependencies installed successfully${NC}"
}

# Find ISO file
find_iso() {
    local iso_name="$1"
    local search_paths=(
        "${HOME}/storage/shared"
        "${HOME}/storage/downloads"
        "${HOME}/storage/shared/ISO"
        "/sdcard/Download"
        "/sdcard"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -f "${path}/${iso_name}" ]]; then
            echo "${path}/${iso_name}"
            return 0
        fi
        if [[ -f "${path^^}/${iso_name}" ]]; then  # Case insensitive
            echo "${path^^}/${iso_name}"
            return 0
        fi
    done
    
    # Search recursively
    for path in "${search_paths[@]}"; do
        local result
        result=$(find "${path}" -maxdepth 3 -name "*${iso_name}*" -type f 2>/dev/null | head -1)
        if [[ -n "${result}" ]]; then
            echo "${result}"
            return 0
        fi
    done
    
    return 1
}

# Extract and mount ISO
mount_iso() {
    local iso_file="$1"
    local iso_name
    
    # Resolve ISO path
    if [[ -f "${iso_file}" ]]; then
        iso_name=$(basename "${iso_file}")
    else
        iso_file=$(find_iso "${iso_file}")
        if [[ -z "${iso_file}" ]]; then
            echo -e "${RED}ISO file not found: $1${NC}"
            return 1
        fi
        iso_name=$(basename "${iso_file}")
    fi
    
    local mount_point="${ISO_MOUNT_DIR}/${iso_name%.iso}"
    
    if [[ -d "${mount_point}" ]]; then
        echo -e "${YELLOW}ISO already mounted at: ${mount_point}${NC}"
        echo "${mount_point}"
        return 0
    fi
    
    echo -e "${BLUE}Mounting ISO: ${iso_name}${NC}"
    mkdir -p "${mount_point}"
    
    # Mount ISO using fuseiso or 7z
    if command -v fuseiso &>/dev/null; then
        fuseiso "${iso_file}" "${mount_point}"
    elif command -v 7z &>/dev/null; then
        7z x "${iso_file}" -o"${mount_point}" -y
    else
        # Fallback: copy ISO content
        cp "${iso_file}" "${mount_point}/${iso_name}"
    fi
    
    echo -e "${GREEN}ISO mounted at: ${mount_point}${NC}"
    echo "${mount_point}"
}

# Unmount ISO
umount_iso() {
    local iso_name="$1"
    local mount_point="${ISO_MOUNT_DIR}/${iso_name%.iso}"
    
    if [[ -d "${mount_point}" ]]; then
        fusermount -u "${mount_point}" 2>/dev/null
        rm -rf "${mount_point}"
        echo -e "${GREEN}ISO unmounted${NC}"
    fi
}

# List available ISOs and rootfs
list_available() {
    echo -e "${BLUE}Available ISOs:${NC}"
    
    local search_paths=(
        "${HOME}/storage/shared"
        "${HOME}/storage/downloads"
        "/sdcard/Download"
    )
    
    for path in "${search_paths[@]}"; do
        find "${path}" -maxdepth 2 -name "*.iso" -type f 2>/dev/null | while read -r iso; do
            echo "  $(basename "${iso}")"
        done
    done
    
    echo -e "${BLUE}Available rootfs:${NC}"
    for path in "${search_paths[@]}"; do
        find "${path}" -maxdepth 2 -type d -name "*rootfs*" 2>/dev/null | while read -r dir; do
            if [[ -d "${dir}/etc" && -d "${dir}/bin" ]]; then
                echo "  ${dir}"
            fi
        done
    done
}

# Setup QEMU with VNC
setup_qemu_vnc() {
    local display="$1"
    local memory="$2"
    local cpu="$3"
    local no_vnc="$4"
    local vnc_passwd="$5"
    
    # Configure VNC display
    export DISPLAY="${display}"
    
    # Start VNC server if not running
    if ! pgrep -f "vncserver" &>/dev/null; then
        echo -e "${BLUE}Starting VNC server on ${display}${NC}"
        
        if [[ -n "${vnc_passwd}" ]]; then
            echo "${vnc_passwd}" | vncpasswd -f > "${CONFIG_DIR}/passwd"
            chmod 600 "${CONFIG_DIR}/passwd"
        fi
        
        vncserver "${display}" -geometry 1280x720 -depth 24 \
            ${vnc_passwd:+-passwd "${CONFIG_DIR}/passwd"} \
            -localhost no \
            -fg >/dev/null 2>&1
    fi
    
    echo -e "${GREEN}VNC server running on ${display}${NC}"
}

# Run ISO in QEMU
run_iso() {
    local iso_file="$1"
    local display="$2"
    local memory="$3"
    local cpu="$4"
    local no_vnc="$5"
    local vnc_passwd="$6"
    local iso_name
    
    # Resolve ISO path
    if [[ -f "${iso_file}" ]]; then
        iso_name=$(basename "${iso_file}")
    else
        iso_file=$(find_iso "${iso_file}")
        if [[ -z "${iso_file}" ]]; then
            echo -e "${RED}ISO file not found: $1${NC}"
            return 1
        fi
        iso_name=$(basename "${iso_file}")
    fi
    
    echo -e "${BLUE}Running ISO: ${iso_name}${NC}"
    
    # Mount ISO
    local mount_point
    mount_point=$(mount_iso "${iso_file}")
    
    # Find kernel and initrd
    local kernel initrd
    kernel=$(find "${mount_point}" -name "vmlinuz*" -type f 2>/dev/null | head -1)
    initrd=$(find "${mount_point}" -name "initrd*" -type f 2>/dev/null | head -1)
    
    if [[ -z "${kernel}" ]]; then
        echo -e "${RED}Kernel not found in ISO${NC}"
        return 1
    fi
    
    # Setup VNC if needed
    if [[ "${no_vnc}" == "false" ]]; then
        setup_qemu_vnc "${display}" "${memory}" "${cpu}" "${no_vnc}" "${vnc_passwd}"
    fi
    
    # Download QEMU EFI firmware if not exists
    local ovmf_file="${CONFIG_DIR}/ovmf.fd"
    if [[ ! -f "${ovmf_file}" ]]; then
        echo -e "${BLUE}Downloading QEMU EFI firmware...${NC}"
        mkdir -p "${CONFIG_DIR}"
        curl -L -o "${ovmf_file}" "https://github.com/qemu/qemu/raw/master/pc-bios/ovmf-x86_64-code.bin" 2>/dev/null || \
        touch "${ovmf_file}"
    fi
    
    # Run QEMU
    echo -e "${GREEN}Starting QEMU with ${memory} RAM and ${cpu} CPU cores${NC}"
    
    local qemu_cmd=(
        qemu-system-x86_64
        -m "${memory}"
        -smp "${cpu}"
        -cdrom "${iso_file}"
        -boot d
        -enable-kvm
        -display vnc="${display}"
    )
    
    if [[ -f "${ovmf_file}" ]]; then
        qemu_cmd+=(-drive "file=${ovmf_file},if=pflash,format=raw,unit=0,readonly=on")
    fi
    
    "${qemu_cmd[@]}" &
    local qemu_pid=$!
    
    echo -e "${GREEN}QEMU started with PID: ${qemu_pid}${NC}"
    echo "${qemu_pid}" > "${ROOTFS_RUN_DIR}/qemu.pid"
    
    # Wait and show VNC connection info
    sleep 2
    
    if [[ "${no_vnc}" == "false" ]]; then
        local vnc_port=$((5900 + ${display#:}))
        echo -e "${GREEN}Connect to VNC: localhost:${vnc_port}${NC}"
    fi
    
    echo "Press Ctrl+C to stop"
    
    # Wait for QEMU
    wait ${qemu_pid}
}

# Run rootfs directory (alternative to proot)
run_rootfs() {
    local rootfs_dir="$1"
    local display="$2"
    local memory="$3"
    local cpu="$4"
    local no_vnc="$5"
    local vnc_passwd="$6"
    
    # Resolve rootfs path
    if [[ ! -d "${rootfs_dir}" ]]; then
        echo -e "${RED}Rootfs directory not found: ${rootfs_dir}${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Running rootfs: ${rootfs_dir}${NC}"
    
    # Check if it's a valid rootfs
    if [[ ! -d "${rootfs_dir}/etc" || ! -d "${rootfs_dir}/bin" ]]; then
        echo -e "${RED}Invalid rootfs directory${NC}"
        return 1
    fi
    
    # Create working directory
    local work_dir="${ROOTFS_RUN_DIR}/$(basename "${rootfs_dir}")"
    mkdir -p "${work_dir}"
    
    # Copy rootfs if needed
    if [[ "${rootfs_dir}" != "${work_dir}" ]]; then
        echo -e "${BLUE}Copying rootfs to working directory...${NC}"
        rsync -a --delete "${rootfs_dir}/" "${work_dir}/" 2>/dev/null || \
        cp -a "${rootfs_dir}/." "${work_dir}/"
    fi
    
    # Setup VNC if needed
    if [[ "${no_vnc}" == "false" ]]; then
        setup_qemu_vnc "${display}" "${memory}" "${cpu}" "${no_vnc}" "${vnc_passwd}"
    fi
    
    # Find kernel
    local kernel
    kernel=$(find /data/data/com.termux/files/usr/share -name "vmlinuz*" -type f 2>/dev/null | head -1)
    
    if [[ -z "${kernel}" ]]; then
        echo -e "${YELLOW}No kernel found, using default QEMU setup${NC}"
    fi
    
    # Create minimal disk image
    local disk_img="${work_dir}.img"
    local rootfs_size=$(du -sb "${work_dir}" | cut -f1)
    local img_size=$((rootfs_size / 1024 / 1024 + 512))
    
    echo -e "${BLUE}Creating disk image (${img_size}M)...${NC}"
    dd if=/dev/zero of="${disk_img}" bs=1M count="${img_size}" status=progress
    mkfs.ext4 -F "${disk_img}"
    
    # Mount and populate disk
    local mnt_dir="/data/local/tmp/maket_mnt_${$}"
    mkdir -p "${mnt_dir}"
    mount -o loop "${disk_img}" "${mnt_dir}"
    cp -a "${work_dir}/." "${mnt_dir}/"
    umount "${mnt_dir}"
    rm -rf "${mnt_dir}"
    
    # Download QEMU EFI firmware if needed
    local ovmf_file="${CONFIG_DIR}/ovmf.fd"
    if [[ ! -f "${ovmf_file}" ]]; then
        echo -e "${BLUE}Downloading QEMU EFI firmware...${NC}"
        mkdir -p "${CONFIG_DIR}"
        curl -L -o "${ovmf_file}" "https://github.com/qemu/qemu/raw/master/pc-bios/ovmf-x86_64-code.bin" 2>/dev/null || \
        touch "${ovmf_file}"
    fi
    
    # Run QEMU with rootfs
    echo -e "${GREEN}Starting QEMU with ${memory} RAM and ${cpu} CPU cores${NC}"
    
    local qemu_cmd=(
        qemu-system-x86_64
        -m "${memory}"
        -smp "${cpu}"
        -hda "${disk_img}"
        -enable-kvm
    )
    
    if [[ "${no_vnc}" == "false" ]]; then
        qemu_cmd+=(-display "vnc=${display}")
    else
        qemu_cmd+=(-display "gtk")
    fi
    
    if [[ -f "${ovmf_file}" ]]; then
        qemu_cmd+=(-drive "file=${ovmf_file},if=pflash,format=raw,unit=0,readonly=on")
    fi
    
    "${qemu_cmd[@]}" &
    local qemu_pid=$!
    
    echo -e "${GREEN}QEMU started with PID: ${qemu_pid}${NC}"
    echo "${qemu_pid}" > "${ROOTFS_RUN_DIR}/qemu.pid"
    
    sleep 2
    
    if [[ "${no_vnc}" == "false" ]]; then
        local vnc_port=$((5900 + ${display#:}))
        echo -e "${GREEN}Connect to VNC: localhost:${vnc_port}${NC}"
    fi
    
    echo "Press Ctrl+C to stop"
    
    wait ${qemu_pid}
}

# Show current status
show_status() {
    echo -e "${BLUE}maket Status${NC}"
    echo "===================="
    
    # Check running QEMU
    if [[ -f "${ROOTFS_RUN_DIR}/qemu.pid" ]]; then
        local pid
        pid=$(cat "${ROOTFS_RUN_DIR}/qemu.pid")
        if kill -0 "${pid}" 2>/dev/null; then
            echo -e "Running QEMU: PID ${GREEN}${pid}${NC}"
        else
            echo -e "QEMU not running (stale PID)"
        fi
    else
        echo -e "No QEMU running"
    fi
    
    # Check VNC
    if pgrep -f "vncserver" &>/dev/null; then
        echo -e "VNC Server: ${GREEN}Running${NC}"
    else
        echo -e "VNC Server: ${RED}Not running${NC}"
    fi
    
    # Show mounted ISOs
    echo -e "${BLUE}Mounted ISOs:${NC}"
    ls -la "${ISO_MOUNT_DIR}" 2>/dev/null || echo "  None"
}

# Cleanup temporary files
cleanup_temp() {
    echo -e "${BLUE}Cleaning up...${NC}"
    
    # Kill running QEMU
    if [[ -f "${ROOTFS_RUN_DIR}/qemu.pid" ]]; then
        local pid
        pid=$(cat "${ROOTFS_RUN_DIR}/qemu.pid")
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null
            echo -e "Stopped QEMU (PID: ${pid})"
        fi
    fi
    
    # Unmount ISOs
    for mount_point in "${ISO_MOUNT_DIR}"/*; do
        if [[ -d "${mount_point}" ]]; then
            fusermount -u "${mount_point}" 2>/dev/null
            rm -rf "${mount_point}"
        fi
    done
    
    # Clean working directory
    rm -rf "${ROOTFS_RUN_DIR}"/*
    
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Initialize on load
check_termux