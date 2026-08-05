# Copilot / AI-Agent Prompt — Build NetHunter Kernel for Nubia NX709S

Paste the prompt below into GitHub Copilot Chat, ChatGPT, Claude, or any agentic coding assistant in your repository. The agent will execute scripts under `scripts/` and produce `boot-new.img`.

---

## System prompt

> You are a Linux build engineer. You are working in a fresh Ubuntu 22.04 / Debian 12 environment with sudo access. Your job is to build a custom Android NetHunter + KernelSU kernel for the **ZTE/Nubia NX709S** smartphone (Snapdragon 8+ Gen 1 / Cape, GKI 5.10 android12). The full source tree, configs, and helper scripts are already present in this repository under `nubia/`. Build artifacts must end up in `nubia/out/`.

## User prompt (the task)

> Read `nubia/docs/README.md`, `nubia/docs/DEVICE_INFO.md`, and `nubia/docs/BUILD_GUIDE.md`. Then:
>
> 1. Run `nubia/scripts/01-install-deps.sh` (use sudo).
> 2. Run `nubia/scripts/02-fetch-toolchain.sh` to grab AOSP clang and mkbootimg.
> 3. Skip `03-extract-bootimg.sh` for now (no phone connected); use the dumped boot images placed in `nubia/boot_image/` if present, otherwise create a no-ramdisk build target.
> 4. Run `nubia/scripts/04-apply-kernelsu.sh` to integrate KernelSU into `nubia/kernel_source/gts8wifi/kernel_platform/msm-kernel/`.
> 5. Run `nubia/scripts/05-apply-nethunter.sh` to apply NetHunter kernel patches and append the NetHunter defconfig fragment to the existing `arch/arm64/configs/vendor/NX709S-perf_diff.config`.
> 6. Run `nubia/scripts/06-build-kernel.sh` (this executes `nubia/kernel_source/gts8wifi/build_kernel_gki.sh`).
> 7. Run `nubia/scripts/07-pack-bootimg.sh` to produce a flashable `boot-new.img`.
>
> If any step fails, read its log under `nubia/out/log/`, identify the failure, fix it (commit the fix to the branch), and retry only the failed step. Do **not** delete the source tree or re-clone unnecessarily; the kernel checkout is 1.5 GB.
>
> Report at the end:
> - SHA256 of `boot-new.img`
> - kernel `Image` size
> - whether modules were built and how many
> - any defconfig warnings (CONFIG_X is not set)

## Hints for the agent

- The build target file is `kernel_platform/msm-kernel/build.config.nubia.nx709s`.
- The active variant must be `gki` (production), not `consolidate` (debug).
- The base defconfig the wrapper expects is `vendor/waipio-NX709S-gki_defconfig` — this is **generated** at build time by `merge_nubia_diffconfig` from `gki_defconfig` + `vendor/NX709S-perf_diff.config`. Do not hand-edit the `waipio-NX709S-gki_defconfig` file directly; modify the diff file instead.
- The kernel source declares itself version 5.10.101 in `Makefile`; the running phone is 5.10.168. Don't try to bump unless asked.
- `CONFIG_KALLSYMS_ALL`, `CONFIG_KPROBES`, `CONFIG_OVERLAY_FS` are already `=y` in stock — KernelSU only needs `CONFIG_KSU=y`.
- For NetHunter the must-have configs are listed in `BUILD_GUIDE.md` Phase 5.
- Use `ccache` with `CCACHE_DIR=$HOME/.ccache CCACHE_MAXSIZE=20G`.
- Use `LTO=thin` to keep memory below 12 GB during link.

## Recovery prompts

If the build fails with **"clang version mismatch"**, run:
> Use the newest clang directory under `toolchains/clang-aosp/`, prefer `clang-r475365b` or later. Add `KCFLAGS=-Wno-error` if there are new warnings.

If the build fails with **"merge_nubia_diffconfig: vendor/waipio-NX709S-gki_defconfig not found"**:
> Pre-generate it manually:
> ```
> KERNEL_DIR=msm-kernel
> ARCH=arm64 scripts/kconfig/merge_config.sh -m -O arch/arm64/configs/vendor/ \
>     arch/arm64/configs/gki_defconfig \
>     arch/arm64/configs/vendor/waipio_GKI.config \
>     arch/arm64/configs/vendor/NX709S-perf_diff.config
> mv arch/arm64/configs/vendor/.config arch/arm64/configs/vendor/waipio-NX709S-gki_defconfig
> ```

If the build wrapper is missing:
> Verify `nubia/kernel_source/gts8wifi/build_kernel_gki.sh` exists and re-run `nubia/scripts/03-fetch-kernel.sh`.

## Acceptance criteria

- `nubia/out/dist/Image` exists and is > 30 MB
- `nubia/out/dist/dtbo.img` exists
- `nubia/boot-new.img` exists and `unpack_bootimg.py` confirms `cmdline=` is non-empty
- `boot-new.img` SHA256 matches a fresh re-build (reproducibility check)
