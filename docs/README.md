# Nubia NX709S — NetHunter Kernel Build Workspace

Everything required to build a custom NetHunter + KernelSU kernel for ZTE / Nubia NX709S on top of the official ZTE GPL release.

## What's in this folder

```
nubia/
├── device-info/        # Live phone properties, partitions, modules, cmdline
│   ├── DEVICE_PROFILE.md
│   ├── proc_version.txt, proc_cmdline.txt, proc_cpuinfo.txt
│   ├── proc_meminfo.txt, proc_modules.txt
│   ├── partitions.txt   <-- block device map for boot/dtbo/vendor_boot
│   ├── _system_build.prop
│   └── devicetree/      <-- live qcom,cape model identifier
├── configs/            # Kernel configs
│   ├── running_kernel.config       # snapshot of /proc/config.gz from THIS phone
│   ├── proc_config.gz              # raw gzip
│   ├── gki_defconfig               # upstream Google GKI defconfig
│   ├── build.config.nubia.nx709s   # ZTE per-device build config
│   ├── NX709S-perf_diff.config     # GKI variant diff (matches stock)
│   └── NX709S_diff.config          # consolidate variant diff (debug)
├── kernel_source/
│   └── gts8wifi/                   # cloned ben443/gts8-sm8450-kernel-platform
│       └── kernel_platform/
│           └── msm-kernel/         # the actual kernel tree (5.10.101)
├── boot_image/         # place your dumped boot.img / vendor_boot.img here
├── patches/            # KernelSU + NetHunter patch series go here
├── scripts/            # Automation scripts (run in order 01..07)
│   ├── 01-install-deps.sh
│   ├── 02-fetch-toolchain.sh
│   ├── 03-extract-bootimg.sh
│   ├── 04-apply-kernelsu.sh
│   ├── 05-apply-nethunter.sh
│   ├── 06-build-kernel.sh
│   └── 07-pack-bootimg.sh
└── docs/
    ├── README.md            (this file)
    ├── DEVICE_INFO.md       (full spec sheet)
    ├── BUILD_GUIDE.md       (step-by-step recipe)
    └── COPILOT_PROMPT.md    (paste into Copilot / AI agent)
```

## Target

| Aspect | Value |
|---|---|
| Device | ZTE / Nubia NX709S-UN |
| SoC | Qualcomm SM8475 / Snapdragon 8+ Gen 1 (codename Cape, msm-waipio config) |
| Kernel base | GKI 5.10 (android12-5.10), source rev 5.10.101 |
| Goal | NetHunter + KernelSU + performance tweaks |
| Build flavor | `VARIANT=gki` (matches stock GKI ABI) |

## Quick start (on a build machine — Linux x86_64 recommended)

```bash
git clone <your-github-fork-of-this-folder> nubia
cd nubia
bash scripts/01-install-deps.sh        # toolchain & build deps
bash scripts/02-fetch-toolchain.sh     # AOSP clang prebuilt
# ---- on the phone (adb shell, root) ----
# dd if=/dev/block/by-name/boot of=/sdcard/boot_a.img
# adb pull /sdcard/boot_a.img boot_image/
bash scripts/03-extract-bootimg.sh     # split boot.img -> kernel + ramdisk
bash scripts/04-apply-kernelsu.sh      # add KernelSU driver to source tree
bash scripts/05-apply-nethunter.sh     # apply NetHunter patches (HID, monitor mode, etc)
bash scripts/06-build-kernel.sh        # ~30-90 min depending on host
bash scripts/07-pack-bootimg.sh        # produce boot-new.img + dtbo-new.img
# Flash:
# fastboot flash boot boot-new.img
# fastboot flash dtbo dtbo-new.img
```

## Important notes

1. **Source kernel version is 5.10.101 but device runs 5.10.168.** ZTE has not pushed updated GPL source. To match stock ABI, port the source to 5.10.168 by overlaying `common-android12-5.10` patches from `https://android.googlesource.com/kernel/common`.

2. **GKI architecture.** Only the kernel `Image` is rebuilt; vendor modules (camera, display, audio, modem) come pre-built from stock `vendor_boot.img`. Module signing must match: keep `CONFIG_MODULE_SIG=n` to avoid signature mismatch, OR re-sign all modules.

3. **Bootloader unlock required.** ZTE/Nubia has its own unlock portal at `https://opensource.ztedevices.com` / NX-specific tools. Wrong-key flash → bricks.

4. **A/B slot phone.** Always flash to the inactive slot first and test before switching. `fastboot --slot=other flash boot boot-new.img` then `fastboot set_active other`.

5. **AVB / vbmeta** must be disabled or zeroed when flashing custom kernels: `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`.
