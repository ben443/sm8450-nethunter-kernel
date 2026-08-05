#!/usr/bin/env bash
# 04b-fix-zte-quirks.sh — patch the ZTE GPL drop to actually compile/link
#
# The published source has unconditional calls in fork.c and binder.c to
# functions provided by =m (module) drivers under drivers/nubia/. vmlinux
# cannot reference module symbols, so ld.lld fails with:
#   undefined symbol: f_monitor_send_uevent
#   undefined symbol: isTargetPid
#
# The running stock kernel does NOT contain these calls (no NUBIA_* configs
# in /proc/config.gz). The published source is a debug branch. We wrap
# both call sites in #if IS_BUILTIN() so the build matches stock.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K="$ROOT/kernel_source/gts8wifi/kernel_platform/msm-kernel"

if [ ! -f "$K/kernel/fork.c" ]; then
    echo "[!] kernel source missing"
    exit 1
fi

echo "[*] Patch 1/2: kernel/fork.c — guard f_monitor_send_uevent()"
if grep -q "IS_BUILTIN(CONFIG_NUBIA_FORK_MONITOR_CTL)" "$K/kernel/fork.c"; then
    echo "    already patched, skipping"
else
    # 1. Wrap the extern declaration
    sed -i 's|^extern void f_monitor_send_uevent(int pid, int tid);|#if IS_BUILTIN(CONFIG_NUBIA_FORK_MONITOR_CTL)\nextern void f_monitor_send_uevent(int pid, int tid);\n#endif|' "$K/kernel/fork.c"
    # 2. Wrap the call site
    sed -i 's|^\([[:space:]]*\)f_monitor_send_uevent(p->tgid, p->pid);|#if IS_BUILTIN(CONFIG_NUBIA_FORK_MONITOR_CTL)\n\1f_monitor_send_uevent(p->tgid, p->pid);\n#endif|' "$K/kernel/fork.c"
    echo "    done"
fi

echo "[*] Patch 2/2: drivers/android/binder.c — guard isTargetPid()"
if grep -q "IS_BUILTIN(CONFIG_NUBIA_SCHED_CTL)" "$K/drivers/android/binder.c"; then
    echo "    already patched, skipping"
else
    sed -i 's|^extern int isTargetPid(int pid);|#if IS_BUILTIN(CONFIG_NUBIA_SCHED_CTL)\nextern int isTargetPid(int pid);\n#endif|' "$K/drivers/android/binder.c"
    # The call site uses 4-space indent, no leading tabs
    sed -i 's|^\([[:space:]]*\)if(isTargetPid(current->tgid)) {|#if IS_BUILTIN(CONFIG_NUBIA_SCHED_CTL)\n\1if(isTargetPid(current->tgid)) {|' "$K/drivers/android/binder.c"
    # close the #if AFTER the closing brace + blank line of the small block
    # the original block is:
    #   if(isTargetPid(current->tgid)) {
    #       has_cap_nice = true;
    #   }
    # we'll insert "#endif" after the matching "}"
    awk '
      /if\(isTargetPid\(current->tgid\)\) \{/ {flag=1; print; next}
      flag && /^[[:space:]]*\}/ {print; print "#endif"; flag=0; next}
      {print}
    ' "$K/drivers/android/binder.c" > "$K/drivers/android/binder.c.new"
    mv "$K/drivers/android/binder.c.new" "$K/drivers/android/binder.c"
    echo "    done"
fi

echo
echo "[*] Verification:"
echo "fork.c:"
grep -n "f_monitor_send_uevent\|IS_BUILTIN(CONFIG_NUBIA_FORK_MONITOR_CTL)" "$K/kernel/fork.c" | head
echo "binder.c:"
grep -n "isTargetPid\|IS_BUILTIN(CONFIG_NUBIA_SCHED_CTL)" "$K/drivers/android/binder.c" | head

echo
echo "[*] Done. Now run scripts/06-build-kernel.sh"
