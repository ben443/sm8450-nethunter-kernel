#!/usr/bin/env bash
# 04-apply-kernelsu.sh — drop KernelSU into the kernel tree
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="$ROOT/kernel_source/gts8wifi/kernel_platform/msm-kernel"

if [ ! -d "$KERNEL_DIR" ]; then
    echo "[!] Kernel source not found at $KERNEL_DIR"
    exit 1
fi

cd "$KERNEL_DIR"

echo "[*] Bootstrapping KernelSU (main branch) ..."
curl -LSs https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh | bash -s main

echo "[*] Adding KernelSU configs to diff config ..."
CFG_ROOT="$KERNEL_DIR/arch/arm64/configs"
DIFF="$(find "$CFG_ROOT" -type f \( -iname '*gts8wifi*defconfig' -o -iname '*gts8wifi*diff*.config' \) | sort | head -1 || true)"
if [ -z "${DIFF:-}" ]; then
    DIFF="$CFG_ROOT/vendor/waipio_sec_defconfig"
fi
if [ ! -f "$DIFF" ]; then
    echo "[!] Could not find a writable defconfig fragment (looked for gts8wifi first)."
    exit 1
fi
echo "    target: ${DIFF#$KERNEL_DIR/}"

if ! grep -q "CONFIG_KSU=y" "$DIFF"; then
cat >> "$DIFF" <<'MARKER'

# === KernelSU ===
CONFIG_KSU=y
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS_XATTR=y
CONFIG_TMPFS_POSIX_ACL=y
MARKER
echo "  added."
else
echo "  already present, skipping."
fi

echo "[*] Verifying KernelSU integration ..."
ls -la KernelSU 2>/dev/null && echo "  KernelSU dir/symlink present"
grep -r "drivers/kernelsu" Makefile drivers/Makefile 2>/dev/null | head -3 || true

echo "[*] Done."
