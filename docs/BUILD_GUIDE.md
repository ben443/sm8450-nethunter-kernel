# Build Guide — Nubia NX709S NetHunter Kernel

Step-by-step recipe. Designed to be run by a human, by Copilot in a Codespace, or by any AI agent in a Linux VM.

## Phase 0 — Host requirements

Use Linux x86_64 (Ubuntu 22.04 / Debian 12 / Kali). 30 GB+ free disk, 8 GB+ RAM. arm64 hosts also work but Google's prebuilt clang is for linux-x86_64 only.

## Phase 1 — Install build dependencies

```bash
sudo apt update
sudo apt install -y \
    git build-essential bc bison flex \
    libssl-dev libelf-dev kmod cpio rsync \
    python3 python3-venv perl ccache \
    curl wget unzip tar xz-utils \
    libncurses-dev pkg-config zip \
    device-tree-compiler dwarves \
    gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
    binutils-aarch64-linux-gnu
```

(Or run `scripts/01-install-deps.sh`)

## Phase 2 — Fetch the AOSP / Google prebuilt clang

The kernel was originally built with `Android Clang 12.0.5 (r416183b)`. For a matching build:

```bash
mkdir -p toolchains && cd toolchains
git clone --depth=1 -b master \
    https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 clang-aosp
# ABI-matching version directory (use newer if r416183b not present)
ls clang-aosp/  # look for clang-r416183b1 or later (r450784e, r475365b...)
```

Newer clang versions (r450+) compile this kernel cleanly. If you hit warnings-as-errors, append `KCFLAGS=-Wno-error` to the `make` line.

Build tools (mkbootimg, avbtool):

```bash
git clone --depth=1 https://android.googlesource.com/platform/system/tools/mkbootimg
git clone --depth=1 https://android.googlesource.com/platform/external/avb
```

## Phase 3 — Dump current boot images from your device

On the phone (rooted shell or via fastboot):

```bash
# adb shell, root
su
SLOT=$(getprop ro.boot.slot_suffix)        # e.g. "_a"
dd if=/dev/block/by-name/boot$SLOT       of=/sdcard/boot.img
dd if=/dev/block/by-name/dtbo$SLOT       of=/sdcard/dtbo.img
dd if=/dev/block/by-name/vendor_boot$SLOT of=/sdcard/vendor_boot.img
dd if=/dev/block/by-name/vbmeta$SLOT     of=/sdcard/vbmeta.img
exit; exit
adb pull /sdcard/boot.img       boot_image/
adb pull /sdcard/dtbo.img       boot_image/
adb pull /sdcard/vendor_boot.img boot_image/
adb pull /sdcard/vbmeta.img     boot_image/
```

Block device map for NX709S (already discovered):

```
boot_a       -> /dev/block/sde13
boot_b       -> /dev/block/sde41
vendor_boot_a-> /dev/block/sde24
vendor_boot_b-> /dev/block/sde52
dtbo_a       -> /dev/block/sde17
dtbo_b       -> /dev/block/sde45
```

Split boot.img to get the original ramdisk:

```bash
mkbootimg/unpack_bootimg.py --boot_img boot_image/boot.img --out boot_image/unpack/
# Yields: kernel, ramdisk, dtb (sometimes), boot_args
```

## Phase 4 — Integrate KernelSU

```bash
cd kernel_source/gts8wifi/kernel_platform/msm-kernel
curl -LSs https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh | bash -s main
```

This drops a `KernelSU/` symlinked directory and patches the kernel `Makefile`. It also auto-enables in `Kconfig`. Verify with:

```bash
grep -r "drivers/kernelsu" Makefile drivers/Makefile  # should show after patch
```

Add to defconfig diff (recommended): create
`kernel_platform/msm-kernel/arch/arm64/configs/vendor/NX709S-kernelsu.config`

```
CONFIG_KSU=y
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS_XATTR=y
```

Then merge into the vendor diff:

```bash
cat NX709S-kernelsu.config >> arch/arm64/configs/vendor/NX709S-perf_diff.config
```

## Phase 5 — Apply NetHunter kernel patches

NetHunter requires:
- HID gadget driver (BadUSB)
- 802.11 monitor mode + injection (already in mac80211)
- RTL8812AU/RTL8814AU drivers (external WiFi adapters)
- USB OTG, OTG host
- Magisk overlayfs compatibility

```bash
# Clone NetHunter kernel patches
git clone --depth=1 https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project.git nethunter

# Generic Android-12 5.10 patches:
PATCH_DIR=nethunter/nethunter-fs/utils/kernel-builder/patches/android-5.10
for p in $PATCH_DIR/*.patch; do
    patch -p1 -d kernel_source/gts8wifi/kernel_platform/msm-kernel < "$p"
done
```

NetHunter defconfig additions — append to `vendor/NX709S-perf_diff.config`:

```
# === NetHunter additions ===
CONFIG_HID=y
CONFIG_USB_HID=y
CONFIG_USB_HIDDEV=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_F_HID=y
CONFIG_USB_CONFIGFS_RNDIS=y
CONFIG_USB_CONFIGFS_F_FS=y
CONFIG_USB_CONFIGFS_F_MASS_STORAGE=y

# WiFi monitor + injection for external dongles
CONFIG_CFG80211=y
CONFIG_MAC80211=y
CONFIG_RTL8812AU=m
CONFIG_RTL8814AU=m
CONFIG_RTL88XXAU_MONITOR_MODE=y

# DriveDroid / mass storage
CONFIG_BLK_DEV_LOOP=y
CONFIG_USB_F_MASS_STORAGE=y

# CIFS / SMB for share access
CONFIG_CIFS=m
CONFIG_NLS_UTF8=y
```

## Phase 6 — Build the kernel

```bash
bash scripts/06-build-kernel.sh
```

`scripts/06-build-kernel.sh` executes `kernel_source/gts8wifi/build_kernel_gki.sh`.

Output goes to `out/msm-kernel/dist/`:
- `Image` — the kernel binary
- `dtbo.img` — device tree overlay
- `vendor_boot.img` (sometimes) — packed vendor ramdisk
- `boot.img` — packed boot image (with empty ramdisk by default)

Manual fallback (if the root build script fails):

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=$PWD/../../../toolchains/clang-aosp/clang-r450784e/bin/clang
make O=out vendor/waipio-NX709S-gki_defconfig
make O=out -j$(nproc) Image dtbo.img modules
```

## Phase 7 — Repack boot.img with new kernel

```bash
# Replace the kernel inside the original boot.img while keeping the stock ramdisk
mkbootimg/mkbootimg.py \
    --kernel out/msm-kernel/dist/Image \
    --ramdisk boot_image/unpack/ramdisk \
    --header_version 4 \
    --base 0x80000000 \
    --pagesize 4096 \
    --cmdline "$(cat boot_image/unpack/boot_args)" \
    --os_version 12.0.0 \
    --os_patch_level 2026-04 \
    --output boot-new.img
```

## Phase 8 — Flash

Recovery / fastboot only — never flash a kernel from a running OS.

```bash
adb reboot bootloader

# (one-time per session) disable AVB to avoid red-state boot warning
fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
fastboot --disable-verity --disable-verification flash vbmeta_b vbmeta.img

# flash to inactive slot first for safety
fastboot --slot=other flash boot boot-new.img
fastboot --slot=other flash dtbo dtbo-new.img
fastboot set_active other
fastboot reboot
```

If it bootloops, hold power+volume-down to enter EDL or fastboot, then restore stock with the original `boot.img` you backed up.

## Phase 9 — Install NetHunter userland

After the device boots into the new kernel:

```bash
# On phone (Magisk/KernelSU rooted):
# 1. Install KernelSU manager APK from github.com/tiann/KernelSU/releases
# 2. Install NetHunter app from store.nethunter.com
# 3. From NetHunter app -> "Kali Chroot Manager" -> Install
# 4. From NetHunter Store -> Install Kali NetHunter Terminal, HID, etc.
```

## Common errors

| Error | Fix |
|---|---|
| `cannot find vmlinux.h` | run `make headers_install` first |
| `BTFIDS error: vmlinux.h type not found` | install `dwarves` (pahole) |
| `defconfig is missing` | run with `merge_config.sh` or use `vendor/waipio-NX709S-gki_defconfig` after first sync |
| `clang: error: unknown argument` | clang version mismatch — use a Google prebuilt clang from same era |
| Boot loops with red AVB | flash zeroed vbmeta with `--disable-verity --disable-verification` |
| `module signature does not match` | rebuild with `CONFIG_MODULE_SIG=n` or re-sign vendor modules |
