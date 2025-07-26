# NixOS System Configuration & VM Testing

This repository contains a complete NixOS system configuration with automated setup scripts and VM testing infrastructure.

## 🚀 Quick Start

### One-Line Installation

```bash
curl -L https://raw.githubusercontent.com/zach/system_config/main/cleanInstall.sh | bash
```

### Manual Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/zach/system_config.git ~/projects/system_config
   cd ~/projects/system_config
   ```

2. Run the clean install script:
   ```bash
   ./cleanInstall.sh
   ```

## 📁 Repository Structure

- **`cleanInstall.sh`** - Main installation script that sets up the entire system
- **`flake.nix`** - Nix flake for development environment with QEMU tools
- **`createTestVM.sh`** - Script to create VMs for testing the installation
- **`.envrc`** - Direnv configuration for automatic environment loading
- **`test-vm/`** - Generated VM testing environment

## 🛠️ Development Environment

This repository includes a Nix development shell with QEMU and testing tools:

```bash
# Install direnv (if not already installed)
# Then allow the environment
direnv allow

# Or manually enter the development shell
nix develop
```

### Available Tools

- **QEMU** - Virtual machine creation and management
- **qemu-img** - Disk image utilities
- **wget/curl** - For downloading ISOs
- **openssh** - For VM connectivity
- **git** - Version control

## 🧪 VM Testing

### Create Test VM

```bash
./createTestVM.sh
```

This creates a complete VM testing environment in `test-vm/` with:
- NixOS minimal ISO download
- VM disk image creation
- Helper scripts for installation and testing

### VM Usage

```bash
cd test-vm

# Start VM for fresh installation
./start-vm.sh --install

# Start installed VM
./start-vm.sh

# Test cleanInstall script remotely
./test-cleaninstall.sh
```

### VM Details

- **RAM**: 4GB
- **Cores**: 2
- **Disk**: 20GB
- **SSH**: Port 2222 forwarded to VM port 22
- **Test User**: `testuser` / `test123`

## 📋 What cleanInstall.sh Does

1. **Repository Setup**
   - Clones/updates the system configuration repository
   - Generates hardware configuration

2. **System Configuration**
   - Creates symlinks to `/etc/nixos/`
   - Links flake.nix, home.nix, and secrets.yaml

3. **User Environment**
   - Sets up XMonad configuration
   - Configures Home Manager
   - Links Spacemacs configuration

4. **Development Tools**
   - Configures Node.js environment (if available)
   - Sets up global npm packages
   - Configures Git with user details

5. **GTD Org Mode**
   - Creates organized directory structure in `~/org/`
   - Sets up inbox, projects, tasks, someday, waiting, tickler files
   - Prepares AI queries and calendar integration

6. **Security**
   - Imports GPG keys
   - Sets up encrypted authentication files

7. **System Application**
   - Applies NixOS configuration with `nixos-rebuild`
   - Attempts to detect and use appropriate hostname

## 🔧 Customization

### For New Systems

1. Run the installation script
2. Move `hardware-configuration.nix` to `hardwareConfigs/${HOSTNAME}-hardware.nix`
3. Create `hosts/${HOSTNAME}.nix` based on existing host configs
4. Update `flake.nix` to include your hostname
5. Apply configuration: `sudo nixos-rebuild switch --flake .#${HOSTNAME}`

### Configuration Files

- **System**: Modify files in `/etc/nixos/` (symlinked from repo)
- **User**: Edit `home.nix` for Home Manager configuration
- **Secrets**: Update `secrets.yaml` for system secrets

## 🎯 Features

- **Reproducible Builds** - Nix flakes ensure consistent environments
- **VM Testing** - Test configurations safely before applying
- **GTD Workflow** - Org-mode setup for Getting Things Done methodology
- **Development Ready** - Pre-configured development environment
- **Automated Setup** - One-command system configuration

## 🔍 Troubleshooting

### Common Issues

1. **QEMU not found**: Run `direnv allow` or `nix develop`
2. **Permission denied**: Ensure scripts are executable with `chmod +x`
3. **VM won't start**: Check KVM availability with `ls /dev/kvm`
4. **SSH connection failed**: Ensure VM is fully booted and SSH service is running

### VM Controls

- **Release mouse/keyboard**: Ctrl+Alt+G
- **Toggle fullscreen**: Ctrl+Alt+F
- **Stop VM**: Close window or Ctrl+C in terminal

## 📚 Dependencies

### Required
- NixOS system
- Git
- Internet connection

### Optional (provided by development shell)
- QEMU/KVM for VM testing
- direnv for automatic environment loading
- Node.js for development packages

## 🤝 Contributing

1. Test changes in a VM first using `createTestVM.sh`
2. Ensure the cleanInstall script works on fresh systems
3. Update documentation for any new features
4. Test on multiple NixOS configurations if possible

## 📄 License

This configuration is provided as-is for personal use. Adapt as needed for your own systems.
