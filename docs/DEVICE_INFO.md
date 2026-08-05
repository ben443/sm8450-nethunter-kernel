# Device Information — ZTE / Nubia NX709S

Auto-generated from running phone via Kali chroot.

## Identification

| Field | Value |
|---|---|
| Brand | ZTE / Nubia |
| Model | NX709S-UN (Z50 series, Chinese variant) |
| Codename | nubia / NX709S |
| Locale (stock) | zh-CN |
| Android version | 12 (API 32) |
| Build ABI | arm64-v8a |
| First API level | 32 |

## Chipset

| Field | Value |
|---|---|
| SoC vendor | Qualcomm |
| Marketing name | Snapdragon 8+ Gen 1 (Cape silicon) |
| Internal codename | Cape (re-spin of Waipio = SM8475/SM8450) |
| MSM build target | `msm.waipio` (Cape uses waipio config) |
| Device tree compatible | `qcom,cape-mtp` / `qcom,cape` |
| PMIC | PM8010 |
| ARM CPU parts | 0xd44 / 0xd46 / 0xd47 (X-class + A-class) |
| Cores | 8 (1+3+4 cluster) |

## Kernel (running)

| Field | Value |
|---|---|
| Version | 5.10.168-android12-9 |
| Tag | `5.10.168-android12-9-00001-g61344663df42-ab9937098` |
| Architecture | arm64 |
| GKI branch | common-android12-5.10 |
| Build ID (GKI) | `ab9937098` |
| Compiler | Android Clang 12.0.5 (r416183b), LLD 12.0.5 |
| Build date | Wed Apr 12 07:05:56 UTC 2023 |
| Type | GKI (Generic Kernel Image) — kernel + DLKM modules |

### Loaded vendor modules (representative)

```
qca6490 (WiFi/BT)
machine_dlkm
swr_dmic_dlkm
ipa_clientsm
wcd938x_dlkm
rndisipam
ipanetm
lpass_cdc_wsa2_macro_dlkm
camera (5.7 MB)
lpass_cdc_va_macro_dlkm
```

Full list: `device-info/proc_modules.txt`

### Kernel cmdline (excerpt)

```
stack_depot_disable=on kasan.stacktrace=off kvm-arm.mode=protected
cgroup_disable=pressure cgroup.memory=nokmem,nosocket
console=ttyMSM0,115200n8 loglevel=6 kpti=0 log_buf_len=256K
kernel.panic_on_rcu_stall=1 swiotlb=noforce loop.max_part=7
allow_mismatched_32bit_el0 kasan=off rcupdate.rcu_expedited=1
rcu_nocbs=0-7 cpufreq.default_governor=performance
msm_drm.dsi_display0=qcom,mdss_dsi_rm692e0_1080_2400_amoled_cmd
```

Full: `device-info/proc_cmdline.txt`

## Display

| Field | Value |
|---|---|
| Panel | Raydium rm692e0 |
| Resolution | 1080 x 2400 |
| Type | AMOLED command-mode |
| Driver | msm_drm dsi_display0 |

## Partitions (A/B device)

```
boot_a       -> /dev/block/sde13
boot_b       -> /dev/block/sde41
vendor_boot_a-> /dev/block/sde24
vendor_boot_b-> /dev/block/sde52
dtbo_a       -> /dev/block/sde17
dtbo_b       -> /dev/block/sde45
recovery_a   -> /dev/block/sde27
recovery_b   -> /dev/block/sde54
vbmeta_a     -> /dev/block/sde16
vbmeta_b     -> /dev/block/sde44
```

Full: `device-info/partitions.txt`

## Kernel Source (official)

| Field | Value |
|---|---|
| Repo | https://github.com/ben443/gts8-sm8450-kernel-platform |
| Owner | ben443 |
| Branch | main |
| Description | nubia NX709S android 12 open source |
| Source kernel version | **5.10.101** (older than running 5.10.168) |
| Layout | `kernel_platform/msm-kernel/` |
| Build config (this device) | `build.config.nubia.nx709s` |
| Defconfig recipe (GKI variant) | base `vendor/waipio-NX709S-gki_defconfig` + diff `vendor/NX709S-perf_diff.config` |
| Defconfig recipe (consolidate) | base `vendor/waipio-NX709S-consolidate_defconfig` + diff `vendor/NX709S_diff.config` |
| Device DTS path | `arch/arm64/boot/dts/vendor/nubia/NX709S/` |
| Extra modules (zips at repo root) | `camera-kernel.zip`, `display-drivers.zip` |

## Nubia-specific kernel features (from diff config)

- NFC: `CONFIG_SEC_NFC` (Samsung NFC stack), `CONFIG_SEC_NFC_PRODUCT_N5`
- Fingerprint: `CONFIG_NUBIA_FINGERPRINT`, Goodix `gw9668`
- Cooling fan: `CONFIG_NUBIA_FAN`, `CONFIG_SOC_FAN`
- Gaming keyboard: `CONFIG_NUBIA_KEYBOARD_GAMESWITCH`
- LEDs/RGB: `CONFIG_NUBIA_LED`, `CONFIG_NUBIA_LED_AW22XXX`, breath LEDs

## KernelSU prerequisites in stock config — verified

```
CONFIG_KALLSYMS_ALL=y    ✓
CONFIG_KPROBES=y         ✓
CONFIG_OVERLAY_FS=y      ✓
```

→ KernelSU integration possible without major surgery.
