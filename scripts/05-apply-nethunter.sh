#!/usr/bin/env bash
# 05-apply-nethunter.sh — clone NetHunter project + append defconfig fragment
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="$ROOT/kernel_source/gts8wifi/kernel_platform/msm-kernel"
NH_DIR="$ROOT/nethunter"

if [ ! -d "$KERNEL_DIR" ]; then
    echo "[!] Kernel source not found at $KERNEL_DIR"
    echo "    Run: bash scripts/03-fetch-kernel.sh"
    exit 1
fi

if [ ! -d "$NH_DIR" ]; then
    echo "[*] Cloning NetHunter project ..."
    git clone --depth=1 \
        https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project.git \
        "$NH_DIR"
fi

CFG_ROOT="$KERNEL_DIR/arch/arm64/configs"
DIFF="$(find "$CFG_ROOT" -type f \( -iname '*gts8wifi*perf*config' -o -iname '*gts8wifi*diff*.config' -o -iname '*gts8wifi*defconfig' \) | sort | head -1 || true)"
if [ -z "${DIFF:-}" ]; then
    DIFF="$CFG_ROOT/vendor/NX709S-perf_diff.config"
fi
if [ ! -f "$DIFF" ]; then
    echo "[!] Could not find a gts8wifi defconfig/diff fragment to patch."
    exit 1
fi
echo "[*] Using kernel config fragment: ${DIFF#$KERNEL_DIR/}"

if ! grep -q "=== NetHunter additions ===" "$DIFF"; then
cat >> "$DIFF" <<'EOF'

# === NetHunter additions ===
# HID gadget (BadUSB / keyboard injection)
CONFIG_HID=y
CONFIG_USB_HID=y
CONFIG_USB_HIDDEV=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_F_HID=y
CONFIG_USB_CONFIGFS_RNDIS=y
CONFIG_USB_CONFIGFS_F_FS=y
CONFIG_USB_CONFIGFS_F_MASS_STORAGE=y
CONFIG_USB_F_MASS_STORAGE=y

# 802.11 monitor + injection (for external USB WiFi adapters)
CONFIG_CFG80211=y
CONFIG_MAC80211=y
CONFIG_NL80211_TESTMODE=y
CONFIG_CFG80211_WEXT=y
CONFIG_PACKET=y
CONFIG_PACKET_DIAG=y

# DriveDroid loop devices
CONFIG_BLK_DEV_LOOP=y
CONFIG_BLK_DEV_LOOP_MIN_COUNT=8

# CIFS/SMB
CONFIG_CIFS=m
CONFIG_NLS_UTF8=y
CONFIG_NLS_CODEPAGE_437=m

# Routing/Tun
CONFIG_TUN=y
CONFIG_PPP=m
CONFIG_PPPOE=m

# Crypto for VPN/wireguard
CONFIG_WIREGUARD=m
EOF
echo "[*] NetHunter defconfig fragment appended to $DIFF"
else
echo "[*] NetHunter fragment already present, skipping."
fi

# Optional: external WiFi driver source trees (RTL8812AU, RTL8814AU)
EXTRA="$KERNEL_DIR/drivers/net/wireless"
if [ ! -d "$EXTRA/rtl8812au" ]; then
    echo "[*] Cloning RTL8812AU ..."
    git clone --depth=1 https://github.com/aircrack-ng/rtl8812au "$EXTRA/rtl8812au" || true
fi

echo "[*] Done. NetHunter prerequisites in place."
echo "    NOTE: NetHunter shipped patch series for android12-5.10 may need to be applied"
echo "    manually; check $NH_DIR/nethunter-fs/utils/kernel-builder/patches/"
