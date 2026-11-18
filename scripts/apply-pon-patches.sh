#!/usr/bin/env bash
# ==============================================================================
# apply-pon-patches.sh
# 仅把本地 patches/ 目录下的 PON 驱动 / 用户态补丁套到对应 feed 快照上。
# 必须在 `./scripts/feeds update -a` 与 `./scripts/feeds install -a` 之后执行
# （feeds/pon_drivers、feeds/pon_userspace 目录由 feeds install 建立）。
# 补丁基线与 feeds.conf.default 锁定的 commit SHA 对应；--check 通过才套用，
# 任一补丁失败不阻断构建（|| true），日志在 CI 步骤输出里可查。
# ==============================================================================
set -uo pipefail

TOP_DIR="$(pwd)"
PATCH_DIR="$TOP_DIR/patches"

apply_patch() {
    local feed="$1"
    local patch="$2"
    local desc="$3"

    if [ ! -d "./feeds/$feed" ]; then
        echo "[skip] feed ./feeds/$feed 不存在，未应用 $patch"
        return 0
    fi
    if [ ! -f "$PATCH_DIR/$patch" ]; then
        echo "[skip] 补丁 $PATCH_DIR/$patch 不存在"
        return 0
    fi

    echo "--> Applying $desc to $feed ..."
    if (cd "./feeds/$feed" && git apply --check "$PATCH_DIR/$patch" 2>/dev/null); then
        (cd "./feeds/$feed" && git apply "$PATCH_DIR/$patch") \
            && echo "    [OK] $patch applied" \
            || echo "    [WARN] $patch apply 失败，保留原样"
        ./scripts/feeds install -p "$feed" -f || true
    else
        echo "    [WARN] $patch --check 未通过（上下文不匹配），未套用"
    fi
}

apply_patch pon_drivers 01-pon-drivers-epon-laser-recovery.patch \
    "EN7572 EPON burst laser latch recovery"
apply_patch pon_userspace 02-pon-userspace-loid-padding-wire-view.patch \
    "LOID padding & wire byte preview"
apply_patch pon_userspace 03-pon-userspace-iptv-bridge-mac-fix.patch \
    "IPTV bridge MAC flipping root-fix"

echo "=== PON 补丁阶段完成 ==="
