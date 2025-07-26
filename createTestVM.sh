#!/usr/bin/env bash
set -euo pipefail

# Script to create a VM for testing the cleanInstall script
# Requires: qemu, wget/curl for downloading NixOS ISO

VM_NAME="nixos-test-vm"
VM_DIR="./test-vm"
DISK_SIZE="20G"
RAM="4G"
CORES="2"
NIXOS_ISO_URL="https://channels.nixos.org/nixos-23.11/latest-nixos-minimal-x86_64-linux.iso"
ISO_FILE="$VM_DIR/nixos-minimal.iso"
DISK_FILE="$VM_DIR/$VM_NAME.qcow2"

echo "🚀 Setting up VM for testing cleanInstall script..."

# Create VM directory
mkdir -p "$VM_DIR"

# Download NixOS ISO if not present
if [ ! -f "$ISO_FILE" ]; then
    echo "📥 Downloading NixOS ISO..."
    if command -v wget &> /dev/null; then
        wget -O "$ISO_FILE" "$NIXOS_ISO_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o "$ISO_FILE" "$NIXOS_ISO_URL"
    else
        echo "❌ Neither wget nor curl found. Please install one of them."
        exit 1
    fi
    echo "✅ NixOS ISO downloaded"
else
    echo "✅ NixOS ISO already present"
fi

# Check for required dependencies
if ! command -v qemu-img &> /dev/null; then
    echo "❌ qemu-img not found!"
    echo "💡 To install dependencies:"
    echo "   1. Install direnv: your package manager should have it"
    echo "   2. Run: direnv allow"
    echo "   3. Or manually enter nix shell: nix develop"
    echo "   4. Or install qemu: nix-env -iA nixpkgs.qemu"
    exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "❌ qemu-system-x86_64 not found!"
    echo "💡 Please install QEMU (see above instructions)"
    exit 1
fi

# Create disk image if not present
if [ ! -f "$DISK_FILE" ]; then
    echo "💾 Creating VM disk image..."
    qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
    echo "✅ VM disk image created"
else
    echo "✅ VM disk image already exists"
fi

# Create VM startup script
cat > "$VM_DIR/start-vm.sh" << EOF
#!/usr/bin/env bash
set -euo pipefail

echo "🖥️  Starting NixOS test VM..."
echo "📋 VM Info:"
echo "   Name: $VM_NAME"
echo "   RAM: $RAM"
echo "   Cores: $CORES"
echo "   Disk: $DISK_SIZE"
echo ""
echo "🔧 VM Controls:"
echo "   - Press Ctrl+Alt+G to release mouse/keyboard from VM"
echo "   - Press Ctrl+Alt+F to toggle fullscreen"
echo "   - Close window or press Ctrl+C in this terminal to stop VM"
echo ""

# Check if we should boot from ISO (fresh install) or disk (existing install)
if [ "\${1:-}" = "--install" ]; then
    echo "🔄 Booting from ISO for fresh installation..."
    BOOT_ORDER="d"
    CDROM_ARGS="-cdrom $ISO_FILE"
else
    echo "🔄 Booting from disk..."
    BOOT_ORDER="c"
    CDROM_ARGS=""
fi

exec qemu-system-x86_64 \\
    -name "$VM_NAME" \\
    -machine type=q35,accel=kvm \\
    -cpu host \\
    -smp "$CORES" \\
    -m "$RAM" \\
    -drive file="$DISK_FILE",format=qcow2,if=virtio \\
    \$CDROM_ARGS \\
    -boot order=\$BOOT_ORDER \\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\
    -device virtio-net-pci,netdev=net0 \\
    -vga virtio \\
    -display gtk \\
    -usb \\
    -device usb-tablet
EOF

chmod +x "$VM_DIR/start-vm.sh"

# Create installation helper script
cat > "$VM_DIR/install-nixos.sh" << 'EOF'
#!/usr/bin/env bash
# Helper script to run inside the VM for basic NixOS installation

set -euo pipefail

echo "🔧 NixOS Installation Helper"
echo "This script helps set up a basic NixOS installation for testing"
echo ""

# Partition the disk
echo "💾 Partitioning disk..."
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart primary 512MiB -8GiB
parted /dev/vda -- mkpart primary linux-swap -8GiB 100%
parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/vda -- set 3 esp on

# Format partitions
echo "📁 Formatting partitions..."
mkfs.ext4 -L nixos /dev/vda1
mkswap -L swap /dev/vda2
mkfs.fat -F 32 -n boot /dev/vda3

# Mount partitions
echo "🔗 Mounting partitions..."
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/vda2

# Generate configuration
echo "⚙️  Generating NixOS configuration..."
nixos-generate-config --root /mnt

# Basic configuration modifications
cat >> /mnt/etc/nixos/configuration.nix << 'NIXEOF'

  # Enable SSH for remote access
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  
  # Create a user for testing
  users.users.testuser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "test123";
  };
  
  # Enable sudo for wheel group
  security.sudo.wheelNeedsPassword = false;
  
  # Enable networking
  networking.networkmanager.enable = true;
  
  # Enable git and curl for the cleanInstall script
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
    htop
  ];
NIXEOF

echo "🚀 Installing NixOS..."
nixos-install --no-root-passwd

echo "✅ Installation complete!"
echo "🔄 You can now reboot and test the cleanInstall script"
echo "📝 Login credentials:"
echo "   Username: testuser"
echo "   Password: test123"
echo "   Root password: (none set)"
EOF

# Create test script for running cleanInstall
cat > "$VM_DIR/test-cleaninstall.sh" << 'EOF'
#!/usr/bin/env bash
# Script to test the cleanInstall script in the VM

set -euo pipefail

echo "🧪 Testing cleanInstall script in VM..."

# SSH into the VM and run the cleanInstall script
ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null testuser@localhost << 'SSHEOF'
set -euo pipefail

echo "📥 Downloading and running cleanInstall script..."

# Download the script (adjust URL as needed)
curl -L -o cleanInstall.sh https://raw.githubusercontent.com/zach/system_config/main/cleanInstall.sh

# Make it executable
chmod +x cleanInstall.sh

# Run the script
./cleanInstall.sh

echo "✅ cleanInstall script completed!"
SSHEOF

echo "🎉 Test completed!"
EOF

chmod +x "$VM_DIR/test-cleaninstall.sh"

# Create README for the VM setup
cat > "$VM_DIR/README.md" << 'EOF'
# NixOS Test VM

This directory contains a VM setup for testing the cleanInstall script.

## Files

- `nixos-minimal.iso` - NixOS installation ISO
- `nixos-test-vm.qcow2` - VM disk image
- `start-vm.sh` - Script to start the VM
- `install-nixos.sh` - Helper script for NixOS installation inside VM
- `test-cleaninstall.sh` - Script to test cleanInstall via SSH

## Usage

### 1. First Installation

```bash
# Start VM with ISO for installation
./start-vm.sh --install

# Inside the VM, run the installation helper:
# (Copy and paste the install-nixos.sh content or transfer it somehow)
```

### 2. Regular Usage

```bash
# Start VM from installed system
./start-vm.sh

# Test the cleanInstall script remotely
./test-cleaninstall.sh
```

### 3. VM Access

- **Console**: Direct access through the VM window
- **SSH**: `ssh -p 2222 testuser@localhost` (password: test123)
- **File Transfer**: `scp -P 2222 file.txt testuser@localhost:~/`

## Notes

- VM forwards SSH port 22 to host port 2222
- Default test user: `testuser` / `test123`
- VM has 4GB RAM, 2 cores, 20GB disk
- Press Ctrl+Alt+G to release mouse/keyboard from VM
EOF

echo "✅ VM setup complete!"
echo ""
echo "📁 VM files created in: $VM_DIR"
echo ""
echo "🚀 Next steps:"
echo "1. Start VM for installation: cd $VM_DIR && ./start-vm.sh --install"
echo "2. Inside VM, partition disk and install NixOS (see install-nixos.sh)"
echo "3. Reboot VM: ./start-vm.sh"
echo "4. Test cleanInstall script: ./test-cleaninstall.sh"
echo ""
echo "📖 See $VM_DIR/README.md for detailed instructions"
