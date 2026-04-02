# maket - Run Linux ISO or rootfs without root on Termux

`maket` is a Termux package that allows running Linux ISO or rootfs without requiring root access. It's an alternative to proot that uses QEMU to virtualize x86_64 Linux systems on Android devices.

## Features

- Run Linux ISO files directly in QEMU
- Run rootfs directories (alternative to proot)
- Built-in VNC server for graphical access
- No root required
- Works on any Android device with Termux

## Installation

```bash
# Clone or download this repository
cd maket

# Run install script
bash scripts/install.sh
```

Or manually:

```bash
# Install dependencies first
pkg install qemu-system-x86_64 xorriso squashfs-tools parted e2fsprogs

# Copy to Termux
cp bin/maket $PREFIX/bin/maket
cp lib/maket-lib.sh $PREFIX/lib/maket/

# Make executable
chmod +x $PREFIX/bin/maket
```

## Usage

### Run Linux ISO

```bash
maket run archlinux-2024.01.01-x86_64.iso
```

With options:
```bash
maket run debian-12.0.0-amd64.iso --display :2 --memory 1G --cpu 4
```

### Run rootfs directory (alternative to proot)

```bash
maket run --rootfs /sdcard/Download/ubuntu
```

With options:
```bash
maket run --rootfs /sdcard/Download/ubuntu --display :2 --memory 1G
```

### Other commands

```bash
# List available ISOs and rootfs
maket list

# Install dependencies
maket install-deps

# Show status
maket status

# Clean up
maket cleanup
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --display` | VNC display number | `:1` |
| `-m, --memory` | RAM for QEMU | `512M` |
| `-c, --cpu` | CPU cores | `2` |
| `--no-vnc` | Run without VNC (console) | `false` |
| `--vnc-passwd` | VNC password | - |

## Requirements

- Termux (latest)
- QEMU (x86_64)
- VNC server (vinagre or tightvnc)
- At least 2GB RAM
- Storage permission for ISO files

## How it works

### ISO Mode

1. Mounts ISO file (using fuseiso or 7z)
2. Finds kernel (vmlinuz) and initrd
3. Starts VNC server
4. Runs QEMU with ISO as CD-ROM

### Rootfs Mode

1. Validates rootfs directory structure
2. Creates disk image from rootfs
3. Starts VNC server
4. Runs QEMU with disk image

## Connecting via VNC

After starting:
- Connect to `localhost:5901` (display :1)
- Use any VNC client (VNC Viewer, bVNC, etc.)
- Password (if set): the password you specified

## Troubleshooting

### QEMU not started
```bash
# Check dependencies
maket install-deps

# Check installation
which qemu-system-x86_64
```

### VNC not working
```bash
# Start VNC manually
vncserver :1

# Check if running
pgrep -a vnc
```

### ISO not found
```bash
# Place ISO in common locations:
# /storage/shared/*.iso
# /storage/downloads/*.iso
# /sdcard/Download/*.iso
```

## License

MIT License - See LICENSE file

## Credits

- QEMU: https://www.qemu.org/
- Termux: https://termux.com/