#!/usr/bin/env bash
# 03-fetch-kernel.sh — clone the NX709S kernel source
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_SOURCE="$ROOT/kernel_source"
mkdir -p "$KERNEL_SOURCE"

echo "[*] Fetching NX709S kernel source (ztemt/NX709S) ..."
if [ ! -d "$KERNEL_SOURCE/NX709S" ]; then
    git clone --depth=1 -b main \
        https://github.com/ztemt/NX709S \
        "$KERNEL_SOURCE/NX709S"
    echo "[*] Kernel source cloned successfully."
else
    echo "[*] Kernel source already present at $KERNEL_SOURCE/NX709S, skipping."
fi

echo "[*] Verifying kernel_platform/msm-kernel exists ..."
if [ -d "$KERNEL_SOURCE/NX709S/kernel_platform/msm-kernel" ]; then
    echo "[✓] Kernel source ready at $KERNEL_SOURCE/NX709S/kernel_platform/msm-kernel"
else
    echo "[!] kernel_platform/msm-kernel not found after clone"
    echo "    Contents of $KERNEL_SOURCE/NX709S/:"
    ls -la "$KERNEL_SOURCE/NX709S/" || true
    exit 1
fi

echo "[*] Done."
