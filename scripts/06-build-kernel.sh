#!/usr/bin/env bash
# 06-build-kernel.sh — run the kernel's root build_kernel_gki.sh wrapper
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_ROOT="$ROOT/kernel_source/gts8wifi"
BUILD_SCRIPT="$KERNEL_ROOT/build_kernel_gki.sh"

OUT="$ROOT/out"
DIST="$OUT/dist"
LOG="$OUT/log"
mkdir -p "$DIST" "$LOG"

if [ ! -d "$KERNEL_ROOT" ]; then
    echo "[!] Kernel source missing at $KERNEL_ROOT"
    echo "    bash scripts/03-fetch-kernel.sh"
    exit 1
fi

if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "[!] Expected build script not found: $BUILD_SCRIPT"
    exit 1
fi

echo "[*] Building gts8wifi kernel via root script:"
echo "    $BUILD_SCRIPT"

cd "$KERNEL_ROOT"
set -o pipefail
bash "$BUILD_SCRIPT" 2>&1 | tee "$LOG/build_kernel_gki.log"

echo "[*] Locating build outputs ..."
IMAGE_PATH="$(find "$KERNEL_ROOT" -type f -path '*/dist/Image' | sort | head -1 || true)"
if [ -z "${IMAGE_PATH:-}" ] || [ ! -f "$IMAGE_PATH" ]; then
    echo "[!] No built Image found under kernel source dist directories."
    echo "    Check: $LOG/build_kernel_gki.log"
    exit 1
fi

cp -f "$IMAGE_PATH" "$DIST/Image"
echo "[*] Copied Image to $DIST/Image"

DTBO_PATH="$(find "$KERNEL_ROOT" -type f -path '*/dist/dtbo.img' | sort | head -1 || true)"
if [ -n "${DTBO_PATH:-}" ] && [ -f "$DTBO_PATH" ]; then
    cp -f "$DTBO_PATH" "$DIST/dtbo.img"
    echo "[*] Copied dtbo.img to $DIST/dtbo.img"
fi

echo
echo "=========================================="
echo "[*] Build complete."
echo "    Image:     $DIST/Image  ($(du -h "$DIST/Image" | cut -f1))"
[ -f "$DIST/dtbo.img" ] && echo "    dtbo.img:  $DIST/dtbo.img  ($(du -h "$DIST/dtbo.img" | cut -f1))"
echo "    Build log: $LOG/build_kernel_gki.log"
echo "=========================================="
ls -la "$DIST"
