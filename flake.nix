{
  description = "Development environment for VM testing with QEMU";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # QEMU for VM creation and management
            qemu
            qemu_kvm
            
            # Additional useful tools for VM testing
            wget
            curl
            openssh
            
            # Development tools
            git
            bash
          ];

          shellHook = ''
            echo "🚀 VM Testing Environment Ready!"
            echo "Available tools:"
            echo "  - qemu-system-x86_64: Main QEMU emulator"
            echo "  - qemu-img: Disk image management"
            echo "  - qemu-kvm: KVM acceleration support"
            echo "  - wget/curl: For downloading ISOs"
            echo "  - ssh: For connecting to VMs"
            echo ""
            echo "💡 Usage:"
            echo "  ./createTestVM.sh    # Create and setup test VM"
            echo "  cd test-vm && ./start-vm.sh --install  # Start VM for installation"
            echo "  cd test-vm && ./start-vm.sh            # Start installed VM"
            echo ""
            
            # Check if KVM is available
            if [ -e /dev/kvm ]; then
              echo "✅ KVM acceleration available"
            else
              echo "⚠️  KVM acceleration not available (VMs will be slower)"
            fi
          '';
        };
      });
}
