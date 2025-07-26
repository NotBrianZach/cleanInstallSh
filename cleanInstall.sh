#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash

#if [ -z "$IN_NIX_SHELL" ]; then
# nix shell --extra-experimental-features 'nix-command flakes' nixpkgs#nodejs nixpkgs#git nixpkgs#gnupg
#    # exec nix shell nixpkgs#nodejs nixpkgs#git nixpkgs#gnupg --command bash "$0" "$@"
#    exec nix shell --extra-experimental-features 'nix-command flakes' nixpkgs#nodejs nixpkgs#git nixpkgs#gnupg  --command bash "$0" "$@"
#fi

echo "Assumptions: current nixos system with partitions and a file system"
echo "0. MAYBE TODO get ssh key?" # (eh might just keep this manually/on usb)
echo "1. Place symlinks"

source_dir="$PWD"
destination_dir="/etc/nixos"

sudo nixos-generate-config
cp /etc/nixos/hardware-configuration.nix $source_dir
echo "nixos hardware-configuration.nix generated and copied from /etc/nixos, probly need to move into hardwareConfigs and modify flake.nix as appropriate"

sudo ln -sf $(realpath ./secrets.yaml) /etc/nixos/secrets.yaml
sudo ln -sf $(realpath ./flake.nix) /etc/nixos/flake.nix
echo "nixos flake symlink created successfully in /etc/nixos"

sudo ln -sf $(realpath ./home.nix) /etc/nixos/home.nix
echo "home-manager symlink created successfully in /etc/nixos"


ln -fs $(realpath ./xmonad.hs) $HOME/.config/xmonad/xmonad.hs

mkdir -p ~/.config/home-manager
ln -fs $(realpath ./home.nix) $HOME/.config/home-manager/home.nix

# gpg --encrypt --recipient "Brian Zachary Abel" ./.authinfo
# gpg --decrypt ./.authinfo.gpg
chmod 600 ./.authinfo.gpg
ln -fs $(realpath ./.authinfo.gpg) $HOME/.authinfo.gpg
chmod 600 $HOME/.authinfo.gpg
# POSSIBLE TODO
# https://github.com/NotBrianZach/spacemacs-nix
ln -fs $(realpath ./.spacemacs) $HOME/
git clone https://github.com/syl20bnr/spacemacs $HOME/.emacs.d
ln -s $HOME/projects/system_config/emacs.d/private/ $HOME/.emacs.d/private/org-ai


mkdir ~/global_mutable_node_modules

cp -r ./.npmrc ~/
npm ~/global_mutable_node_modules
npm add -g pnpm

npm install -g eslint \
    eslint-plugin-jsx-a11y \
    eslint-config-airbnb \
    eslint-plugin-import \
    babel-eslint \
    eslint-plugin-react \
    ajv-cli \
    es-beautifier \
    tern

git config --global user.email "darklordvadermort@gmail.com"
git config --global user.name "Zach Abel"

# GTD Org Mode Setup
echo "Setting up GTD Org Mode structure..."
mkdir -p ~/org

# Create GTD org files with basic structure
cat > ~/org/inbox.org << 'EOF'
* Inbox
** TODO [Captured tasks will go here]
EOF

cat > ~/org/projects.org << 'EOF'
* Projects
** Example Project Alpha
*** TODO Define requirements  
*** TODO Draft design document  
*** TODO Review with team  
EOF

cat > ~/org/tasks.org << 'EOF'
* Tasks
** TODO Example: Buy groceries  
** TODO Example: Call the plumber  
** TODO Example: Renew car registration  
EOF

cat > ~/org/someday.org << 'EOF'
* Someday/Maybe
** TODO Example: Learn a new language
** TODO Example: Plan vacation to Japan
EOF

cat > ~/org/waiting.org << 'EOF'
* Waiting For
** WAITING Example: Bob to send the report
EOF

cat > ~/org/tickler.org << 'EOF'
* Tickler/Future
** TODO Example: Review quarterly goals
   SCHEDULED: <2025-10-01 Wed>
EOF

cat > ~/org/gcal.org << 'EOF'
* Google Calendar Events
EOF

cat > ~/org/ai-queries.org << 'EOF'
* AI Queries
EOF

echo "GTD Org files created in ~/org/"
echo "Remember to configure your .spacemacs with the GTD settings from gtd.org"

nixos-rebuild switch --flake '.#zMothership2'

# curl -o ./public_key.gpg https://raw.githubusercontent.com/NotBrianZach/publicgpg/refs/heads/main/public_key.gpg

gpg --import ./public_key.gpg
# Clean install script for NixOS system configuration
# Usage: curl -L https://raw.githubusercontent.com/zach/system_config/main/cleanInstallSh/cleanInstall.sh | bash

REPO_URL="https://github.com/zach/system_config.git"
REPO_DIR="$HOME/projects/system_config"

echo "🚀 Starting NixOS system configuration setup..."
echo "Assumptions: current nixos system with partitions and a file system"

# Create projects directory if it doesn't exist
mkdir -p "$HOME/projects"

# Clone or update the repository
if [ -d "$REPO_DIR" ]; then
    echo "📁 Repository already exists, updating..."
    cd "$REPO_DIR"
    git pull
else
    echo "📥 Cloning system configuration repository..."
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

source_dir="$REPO_DIR"
destination_dir="/etc/nixos"

# Generate hardware configuration
echo "🔧 Generating hardware configuration..."
sudo nixos-generate-config
cp /etc/nixos/hardware-configuration.nix "$source_dir/"
echo "✅ Hardware configuration generated and copied to repo"
echo "⚠️  You may need to move it to hardwareConfigs/ and modify flake.nix as appropriate"

# Create symlinks to /etc/nixos
echo "🔗 Creating symlinks to /etc/nixos..."
sudo ln -sf "$source_dir/secrets.yaml" /etc/nixos/secrets.yaml
sudo ln -sf "$source_dir/flake.nix" /etc/nixos/flake.nix
sudo ln -sf "$source_dir/home.nix" /etc/nixos/home.nix
echo "✅ NixOS configuration symlinks created"

# Create user configuration directories and symlinks
echo "🏠 Setting up user configuration..."
mkdir -p "$HOME/.config/xmonad"
mkdir -p "$HOME/.config/home-manager"

ln -fs "$source_dir/xmonad.hs" "$HOME/.config/xmonad/xmonad.hs"
ln -fs "$source_dir/home.nix" "$HOME/.config/home-manager/home.nix"
echo "✅ User configuration symlinks created"

# Set up authentication and Spacemacs
echo "🔐 Setting up authentication and Spacemacs..."
if [ -f "$source_dir/.authinfo.gpg" ]; then
    chmod 600 "$source_dir/.authinfo.gpg"
    ln -fs "$source_dir/.authinfo.gpg" "$HOME/.authinfo.gpg"
    chmod 600 "$HOME/.authinfo.gpg"
    echo "✅ Authentication file linked"
else
    echo "⚠️  .authinfo.gpg not found, skipping authentication setup"
fi

# Set up Spacemacs
ln -fs "$source_dir/.spacemacs" "$HOME/"
if [ ! -d "$HOME/.emacs.d" ]; then
    echo "📦 Cloning Spacemacs..."
    git clone https://github.com/syl20bnr/spacemacs "$HOME/.emacs.d"
else
    echo "✅ Spacemacs already installed"
fi

# Set up org-ai private layer
mkdir -p "$HOME/.emacs.d/private"
if [ -d "$source_dir/emacs.d/private" ]; then
    ln -sf "$source_dir/emacs.d/private/" "$HOME/.emacs.d/private/org-ai"
    echo "✅ Org-AI private layer linked"
fi


# Set up Node.js environment (optional, only if Node.js is available)
echo "📦 Setting up Node.js environment..."
if command -v npm &> /dev/null; then
    mkdir -p "$HOME/global_mutable_node_modules"
    
    if [ -f "$source_dir/.npmrc" ]; then
        cp "$source_dir/.npmrc" "$HOME/"
    fi
    
    # Install global packages if npm is available
    npm install -g pnpm eslint \
        eslint-plugin-jsx-a11y \
        eslint-config-airbnb \
        eslint-plugin-import \
        babel-eslint \
        eslint-plugin-react \
        ajv-cli \
        es-beautifier \
        tern 2>/dev/null || echo "⚠️  Some npm packages failed to install"
    echo "✅ Node.js environment configured"
else
    echo "⚠️  Node.js not found, skipping npm setup"
fi

# Configure Git
echo "🔧 Configuring Git..."
git config --global user.email "darklordvadermort@gmail.com"
git config --global user.name "Zach Abel"
echo "✅ Git configured"

# GTD Org Mode Setup
echo "📝 Setting up GTD Org Mode structure..."
mkdir -p "$HOME/org"

# Create GTD org files with basic structure
# Create GTD org files only if they don't exist
for file in inbox projects tasks someday waiting tickler gcal ai-queries; do
    if [ ! -f "$HOME/org/${file}.org" ]; then
        case $file in
            inbox)
                cat > "$HOME/org/inbox.org" << 'EOF'
* Inbox
** TODO [Captured tasks will go here]
EOF
                ;;
            projects)
                cat > "$HOME/org/projects.org" << 'EOF'
* Projects
** Example Project Alpha
*** TODO Define requirements  
*** TODO Draft design document  
*** TODO Review with team  
EOF
                ;;
            tasks)
                cat > "$HOME/org/tasks.org" << 'EOF'
* Tasks
** TODO Example: Buy groceries  
** TODO Example: Call the plumber  
** TODO Example: Renew car registration  
EOF
                ;;
            someday)
                cat > "$HOME/org/someday.org" << 'EOF'
* Someday/Maybe
** TODO Example: Learn a new language
** TODO Example: Plan vacation to Japan
EOF
                ;;
            waiting)
                cat > "$HOME/org/waiting.org" << 'EOF'
* Waiting For
** WAITING Example: Bob to send the report
EOF
                ;;
            tickler)
                cat > "$HOME/org/tickler.org" << 'EOF'
* Tickler/Future
** TODO Example: Review quarterly goals
   SCHEDULED: <2025-10-01 Wed>
EOF
                ;;
            gcal)
                cat > "$HOME/org/gcal.org" << 'EOF'
* Google Calendar Events
EOF
                ;;
            ai-queries)
                cat > "$HOME/org/ai-queries.org" << 'EOF'
* AI Queries
EOF
                ;;
        esac
    fi
done

echo "✅ GTD Org files created in ~/org/"
echo "📖 Remember to configure your .spacemacs with the GTD settings from gtd.org"

# Import GPG key if available
echo "🔑 Setting up GPG..."
if [ -f "$source_dir/public_key.gpg" ]; then
    gpg --import "$source_dir/public_key.gpg"
    echo "✅ GPG key imported"
else
    echo "⚠️  public_key.gpg not found, skipping GPG import"
fi

# Apply NixOS configuration
echo "🔄 Applying NixOS configuration..."
echo "⚠️  You may need to modify the hostname in the flake command below"
echo "Available configurations:"
nix flake show "$source_dir" 2>/dev/null | grep nixosConfigurations || echo "Could not detect configurations"

# Detect hostname and try to apply configuration
HOSTNAME=$(hostname)
echo "🏷️  Detected hostname: $HOSTNAME"

if nix flake show "$source_dir" 2>/dev/null | grep -q "nixosConfigurations.$HOSTNAME"; then
    echo "🎯 Found configuration for $HOSTNAME, applying..."
    sudo nixos-rebuild switch --flake "$source_dir#$HOSTNAME"
else
    echo "⚠️  No configuration found for hostname '$HOSTNAME'"
    echo "🔄 Trying default configuration 'zMothership2'..."
    sudo nixos-rebuild switch --flake "$source_dir#zMothership2"
fi

echo "✨ Setup complete!"
echo "🔄 You may need to restart your shell or log out/in for all changes to take effect"
echo "📁 Configuration is located at: $REPO_DIR"
echo "🛠️  To customize for your system:"
echo "   1. Move hardware-configuration.nix to hardwareConfigs/${HOSTNAME}-hardware.nix"
echo "   2. Create hosts/${HOSTNAME}.nix based on existing host configs"
echo "   3. Update flake.nix to include your hostname"
echo "   4. Run: sudo nixos-rebuild switch --flake $REPO_DIR#$HOSTNAME"
