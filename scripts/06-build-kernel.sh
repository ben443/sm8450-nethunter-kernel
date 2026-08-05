#!/usr/bin/env bash
# 06-build-kernel.sh — direct make-based GKI kernel build (no build.sh dependency)
# Modern kernel/build no longer ships build.sh. We invoke make directly with
# a manually-merged defconfig to mirror device diffconfig composition.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="$ROOT/kernel_source/gts8wifi/kernel_platform/msm-kernel"
TC="$ROOT/toolchains"

if [ ! -d "$KERNEL_DIR" ]; then
    echo "[!] Kernel source missing at $KERNEL_DIR"
    echo "    bash scripts/03-fetch-kernel.sh"
    exit 1
fi

# ---- Toolchain discovery ----
CLANG_DIR=$(ls -1d "$TC/clang-aosp/clang-r"* 2>/dev/null | sort -V | tail -1 || true)
if [ -z "$CLANG_DIR" ]; then
    echo "[!] No clang found under $TC/clang-aosp. Run 02-fetch-toolchain.sh first."
    exit 1
fi
export PATH="$CLANG_DIR/bin:$PATH"
echo "[*] Using clang: $CLANG_DIR"
clang --version | head -1

# ccache
export USE_CCACHE=1
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"
export CCACHE_COMPRESS=1
export CCACHE_COMPRESSLEVEL=4
mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE" 2>/dev/null || true

# ---- Output dirs ----
OUT="$ROOT/out"
DIST="$OUT/dist"
LOG="$OUT/log"
mkdir -p "$OUT" "$DIST" "$LOG"

cd "$KERNEL_DIR"

# ---- Create techpack/stub/ if required by the vendor tree ----
TECHPACK_STUB="$KERNEL_DIR/techpack/stub"
if [ -d "$KERNEL_DIR/techpack" ]; then
    mkdir -p "$TECHPACK_STUB"
    if [ ! -f "$TECHPACK_STUB/Makefile" ]; then
        echo "[*] Creating empty techpack/stub/Makefile to satisfy Makefile expectations ..."
        cat > "$TECHPACK_STUB/Makefile" <<'EOF'
# Empty stub Makefile — required by techpack/Kbuild
EOF
    fi
    if [ ! -f "$TECHPACK_STUB/Kbuild" ]; then
        echo "[*] Creating empty techpack/stub/Kbuild to satisfy Makefile expectations ..."
        cat > "$TECHPACK_STUB/Kbuild" <<'EOF'
# SPDX-License-Identifier: GPL-2.0-only
# Empty stub Kbuild to keep the parent Makefile happy when techpack/stub is absent.
EOF
    fi
fi

# ---- Merge defconfig (gki_defconfig + vendor base + device fragment) ----

export ARCH=arm64
JOBS="$(nproc)"

CFG_DIR="$KERNEL_DIR/arch/arm64/configs"
MERGE_OUT="$KERNEL_DIR/out"
mkdir -p "$MERGE_OUT"

echo "[*] Merging defconfig fragments ..."
BASE_VENDOR_CFG="$CFG_DIR/vendor/waipio_GKI.config"
DEVICE_CFG="$CFG_DIR/gts8wifi-waipio_defconfig"
if [ ! -f "$DEVICE_CFG" ]; then
    DEVICE_CFG="$(find "$CFG_DIR" -type f \( -iname '*gts8wifi*perf*config' -o -iname '*gts8wifi*diff*.config' -o -iname '*gts8wifi*defconfig' -o -iname '*x700*perf*config' -o -iname '*x700*diff*.config' -o -iname 'waipio_sec_defconfig' \) | sort | head -1 || true)"
fi
if [ ! -f "$DEVICE_CFG" ]; then
    echo "[!] Could not find a gts8wifi defconfig/diff fragment to merge."
    exit 1
fi

MERGE_FILES=("$CFG_DIR/gki_defconfig")
BASE_DESC="gki_defconfig"
if [ -f "$BASE_VENDOR_CFG" ]; then
    MERGE_FILES+=("$BASE_VENDOR_CFG")
    BASE_DESC+=" + vendor/waipio_GKI.config"
fi
MERGE_FILES+=("$DEVICE_CFG")

echo "    base:  $BASE_DESC"
echo "    diff:  ${DEVICE_CFG#$KERNEL_DIR/}"

ARCH=arm64 bash "$KERNEL_DIR/scripts/kconfig/merge_config.sh" -m -O "$MERGE_OUT" \
    "${MERGE_FILES[@]}" 2>&1 | tail -10

if [ ! -f "$MERGE_OUT/.config" ]; then
    echo "[!] merge_config did not produce .config — check fragment paths"
    exit 1
fi
echo "[*] Merged .config size: $(wc -l < "$MERGE_OUT/.config") lines"

# ---- Job count: cap at 2 on small CI runners (OOM-prone during link) ----
TOTAL_MEM_GB=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 8)
if [ "${KBUILD_JOBS:-}" != "" ]; then
    JOBS="$KBUILD_JOBS"
elif [ "$TOTAL_MEM_GB" -lt 12 ]; then
    JOBS=2
    echo "[*] Memory ${TOTAL_MEM_GB} GB < 12 GB -> capping JOBS=2 to avoid OOM"
fi
echo "[*] Build jobs: $JOBS  (mem: ${TOTAL_MEM_GB} GB, cpus: $(nproc))"

# ---- Common make args ----
MAKE_ARGS=(
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC="ccache clang"
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    READELF=llvm-readelf
    HOSTCC="ccache clang"
    HOSTCXX="ccache clang++"
    HOSTLD=ld.lld
    CROSS_COMPILE=aarch64-linux-gnu-
    O="$MERGE_OUT"
    -j"$JOBS"
)

# ---- Resolve final config (olddefconfig in case of new symbols) ----
echo "[*] Running olddefconfig ..."
make "${MAKE_ARGS[@]}" KCONFIG_ALLCONFIG="$MERGE_OUT/.config" olddefconfig 2>&1 | \
    tee "$LOG/olddefconfig.log" | tail -20

# ---- Build Image + dtbo ----
echo "[*] Building Image ..."
set -o pipefail
make "${MAKE_ARGS[@]}" KCFLAGS="-Wno-error" Image 2>&1 | tee "$LOG/build.log" | \
    grep -E "^\s+(CC|LD|AR|AS|GEN|UPD|HOSTCC|CALL|CHK|OBJCOPY|TARGET) " | tail -50 || true

if [ ! -f "$MERGE_OUT/arch/arm64/boot/Image" ]; then
    echo "[!] Image not produced. See $LOG/build.log"
    tail -60 "$LOG/build.log"
    exit 1
fi

cp "$MERGE_OUT/arch/arm64/boot/Image" "$DIST/Image"
echo "[*] Image: $(ls -la "$DIST/Image")"
echo "[*] Image size: $(du -h "$DIST/Image" | cut -f1)"

# DTBs (best-effort)
echo "[*] Building DTBs ..."
make "${MAKE_ARGS[@]}" KCFLAGS="-Wno-error" dtbs 2>&1 | tail -20 | tee -a "$LOG/build.log" || true

# Pack dtbo using mkdtimg if available
DTBO_OUT="$MERGE_OUT/arch/arm64/boot/dtbo.img"
if command -v mkdtimg >/dev/null 2>&1; then
    DTBO_DIR="$MERGE_OUT/arch/arm64/boot/dts/vendor/qcom"
    if ls "$DTBO_DIR"/*.dtbo >/dev/null 2>&1; then
        mkdtimg create "$DTBO_OUT" --page_size=4096 "$DTBO_DIR"/*.dtbo 2>/dev/null || true
    fi
fi
[ -f "$DTBO_OUT" ] && cp "$DTBO_OUT" "$DIST/dtbo.img" && echo "[*] dtbo.img copied"

# Modules (optional, only if needed)
if grep -q "^CONFIG_MODULES=y" "$MERGE_OUT/.config" 2>/dev/null; then
    echo "[*] Building modules ..."
    make "${MAKE_ARGS[@]}" KCFLAGS="-Wno-error" modules 2>&1 | tail -10 | tee -a "$LOG/build.log" || true
fi

# ---- Summary ----
echo
echo "=========================================="
echo "[*] Build complete."
echo "    Image:        $DIST/Image  ($(du -h "$DIST/Image" 2>/dev/null | cut -f1))"
[ -f "$DIST/dtbo.img" ] && echo "    dtbo.img:     $DIST/dtbo.img  ($(du -h "$DIST/dtbo.img" | cut -f1))"
echo "    Build log:    $LOG/build.log"
echo "    Module count: $(find "$MERGE_OUT" -name "*.ko" 2>/dev/null | wc -l)"
echo "=========================================="
ls -la "$DIST" 2>/dev/null
