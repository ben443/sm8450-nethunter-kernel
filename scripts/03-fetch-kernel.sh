#!/usr/bin/env bash
# 03-fetch-kernel.sh — clone the gts8wifi kernel source
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_SOURCE="$ROOT/kernel_source"
mkdir -p "$KERNEL_SOURCE"

echo "[*] Fetching gts8wifi kernel source (ben443/gts8-sm8450-kernel-platform) ..."
if [ ! -d "$KERNEL_SOURCE/gts8wifi" ]; then
    git clone --depth=1 -b main \
        https://github.com/ben443/gts8-sm8450-kernel-platform \
        "$KERNEL_SOURCE/gts8wifi"
    echo "[*] Kernel source cloned successfully."
else
    echo "[*] Kernel source already present at $KERNEL_SOURCE/gts8wifi, skipping."
fi

echo "[*] Verifying kernel_platform/msm-kernel exists ..."
if [ -d "$KERNEL_SOURCE/gts8wifi/kernel_platform/msm-kernel" ]; then
    echo "[✓] Kernel source ready at $KERNEL_SOURCE/gts8wifi/kernel_platform/msm-kernel"
else
    echo "[!] kernel_platform/msm-kernel not found after clone"
    echo "    Contents of $KERNEL_SOURCE/gts8wifi/:"
    ls -la "$KERNEL_SOURCE/gts8wifi/" || true
    exit 1
fi

echo "[*] Done."
