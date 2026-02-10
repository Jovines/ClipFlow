#!/bin/bash

# Install Release Tools Script
# Installs create-dmg and sign_update (Sparkle EdDSA signing tool)
# Usage: ./scripts/install_release_tools.sh

set -e

SPARKLE_VERSION="2.8.1"

echo "=========================================="
echo "ClipFlow Release Tools Installer"
echo "=========================================="

install_create_dmg() {
    echo ""
    echo "Installing create-dmg..."

    if command -v create-dmg &> /dev/null; then
        echo "create-dmg already installed: $(which create-dmg)"
        return 0
    fi

    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not installed. Please install Homebrew first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi

    brew install create-dmg
    echo "create-dmg installed successfully"
}

install_sign_update() {
    echo ""
    echo "Installing sign_update (Sparkle EdDSA tool)..."

    test_sign_update() {
        local path="$1"
        if [ ! -f "$path" ] || [ ! -x "$path" ]; then
            return 1
        fi
        if [ ! -f "secrets/sparkle_private_key.txt" ]; then
            return 1
        fi
        local test_file=$(mktemp)
        echo "test" > "$test_file"
        if "$path" -f secrets/sparkle_private_key.txt "$test_file" > /dev/null 2>&1; then
            rm -f "$test_file"
            return 0
        fi
        rm -f "$test_file"
        return 2
    }

    local sign_update_paths=(
        "/usr/local/bin/sign_update"
        "/opt/homebrew/bin/sign_update"
        "$HOME/.local/bin/sign_update"
        "./scripts/sparkle/bin/sign_update"
    )

    for path in "${sign_update_paths[@]}"; do
        if test_sign_update "$path"; then
            echo "sign_update found and working: $path"
            return 0
        elif [ -f "$path" ]; then
            echo "sign_update exists but not working: $path (will use download fallback)"
        fi
    done

    if command -v brew &> /dev/null; then
        local brew_path="/opt/homebrew/Caskroom/sparkle/${SPARKLE_VERSION}/bin/sign_update"
        if test_sign_update "$brew_path"; then
            echo "sign_update installed via Homebrew: $brew_path"
            return 0
        elif [ -f "$brew_path" ]; then
            echo "Homebrew sign_update not working (will use download fallback)"
        fi
    fi

    echo "sign_update will be downloaded at runtime via sign_update.sh"
}

echo ""
echo "Checking and installing required tools..."
echo ""

install_create_dmg
install_sign_update

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "To verify tools:"
echo "  which create-dmg"
echo "  which sign_update"
echo ""
echo "For release workflow, run:"
echo "  source ./scripts/sign_update.sh"
