#!/bin/bash

# sign_update Helper Script
# Checks for sign_update tool, downloads if needed, returns path to sign_update
# Usage: source ./scripts/sign_update.sh

SPARKLE_VERSION="2.8.1"
SPARKLE_DOWNLOAD_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/../secrets"
SPARKLE_CACHE_DIR="${SCRIPT_DIR}/sparkle"

mkdir -p "$SPARKLE_CACHE_DIR"

test_sign_update() {
    local path="$1"
    if [ ! -f "$path" ] || [ ! -x "$path" ]; then
        return 1
    fi
    if [ ! -f "${SECRETS_DIR}/sparkle_private_key.txt" ]; then
        return 1
    fi
    local test_file="/tmp/sign_update_test_$$"
    echo "test" > "$test_file"
    if "$path" -f "${SECRETS_DIR}/sparkle_private_key.txt" "$test_file" > /dev/null 2>&1; then
        rm -f "$test_file"
        return 0
    fi
    rm -f "$test_file"
    return 1
}

find_sign_update() {
    local paths=(
        "/usr/local/bin/sign_update"
        "/opt/homebrew/bin/sign_update"
        "$HOME/.local/bin/sign_update"
        "${SPARKLE_CACHE_DIR}/bin/sign_update"
    )

    for path in "${paths[@]}"; do
        if test_sign_update "$path"; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

download_sparkle() {
    local sparkle_archive="${SPARKLE_CACHE_DIR}/Sparkle-${SPARKLE_VERSION}.tar.xz"

    if [ ! -f "$sparkle_archive" ]; then
        curl -L --retry 3 -o "$sparkle_archive" "$SPARKLE_DOWNLOAD_URL" 2>/dev/null
    fi

    if [ ! -f "$sparkle_archive" ]; then
        return 1
    fi

    tar -xf "$sparkle_archive" -C "$SPARKLE_CACHE_DIR" 2>/dev/null

    local sign_update_path="${SPARKLE_CACHE_DIR}/bin/sign_update"
    if test_sign_update "$sign_update_path"; then
        echo "$sign_update_path"
        return 0
    fi

    return 1
}

get_sign_update() {
    if SIGN_UPDATE=$(find_sign_update); then
        echo "$SIGN_UPDATE"
        return 0
    fi

    if SIGN_UPDATE=$(download_sparkle); then
        echo "$SIGN_UPDATE"
        return 0
    fi

    echo "ERROR: sign_update tool not found and could not be downloaded" >&2
    return 1
}

get_sign_update
