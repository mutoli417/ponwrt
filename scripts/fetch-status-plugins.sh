#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# =============================================================
# fetch-status-plugins.sh —— 拉取三个第三方 LuCI 状态插件到 package/custom
#
# 背景（已核实）：
#   feeds.conf.default 所列 pon_drivers / pon_userspace / helloworld 均不提供
#   下列三个包，它们来自外部仓库：
#     qwe-qaq/luci-app             main → luci-app-natmode
#                                        luci-app-pon-status
#     luanmuc/luci-app-airoha-npu  main → luci-app-airoha-npu
#
# 用法:
#   bash scripts/fetch-status-plugins.sh [openwrt_dir]
#
# 执行时机:
#   必须在 "Update & install feeds" 之前；package/custom 属顶层 package/
#   目录，由 buildroot 自动扫描，无需在 feeds.conf.default 加 src-link。
#
# 失败语义:
#   任一目标包 Makefile 缺失 → ::error:: 并 exit 1，与 Validate 步骤对齐。
# =============================================================

set -uo pipefail

WS="${1:-${GITHUB_WORKSPACE:-.}}"
PKG_DIR="$WS/package/custom"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LUCI_APP_URL="https://github.com/qwe-qaq/luci-app"
NPU_URL="https://github.com/luanmuc/luci-app-airoha-npu"
BRANCH="main"

clone() { # clone <url> <dest> [branch]
  local url="$1" dest="$2" br="${3:-$BRANCH}"
  echo "--- git clone $url ($br) -> $dest"
  git clone --depth 1 -b "$br" "$url" "$dest" 2>&1 | tail -3
}

mkdir -p "$PKG_DIR"

# 1) qwe-qaq/luci-app：luci-app-natmode + luci-app-pon-status
if ! clone "$LUCI_APP_URL" "$TMP/luci-app"; then
  echo "::error::拉取 $LUCI_APP_URL 失败，natmode / pon-status 无法被索引"
  exit 1
fi
for p in luci-app-natmode luci-app-pon-status; do
  if [ ! -f "$TMP/luci-app/$p/Makefile" ]; then
    echo "::error::$TMP/luci-app/$p/Makefile 不存在，包无法被索引"
    exit 1
  fi
  rm -rf "$PKG_DIR/$p"
  cp -r "$TMP/luci-app/$p" "$PKG_DIR/"
  echo "✅ $p 已就位: package/custom/$p"
done

# 2) luanmuc/luci-app-airoha-npu：仓库根目录即包目录
if ! clone "$NPU_URL" "$PKG_DIR/luci-app-airoha-npu"; then
  echo "::error::拉取 $NPU_URL 失败，luci-app-airoha-npu 无法被索引"
  exit 1
fi
if [ ! -f "$PKG_DIR/luci-app-airoha-npu/Makefile" ]; then
  echo "::error::package/custom/luci-app-airoha-npu/Makefile 不存在"
  exit 1
fi
echo "✅ luci-app-airoha-npu 已就位: package/custom/luci-app-airoha-npu"

# 3) 执行权限：拷贝/解压不保留 rpcd 后端、/usr/sbin 工具、init.d 脚本可执行位
find "$PKG_DIR" -path "*/libexec/rpcd/*"  -type f -exec chmod 0755 {} \;
find "$PKG_DIR" -path "*/usr/sbin/*"      -type f -exec chmod 0755 {} \;
find "$PKG_DIR" -path "*/etc/init.d/*"     -type f -exec chmod 0755 {} \;

# 4) 完整性复核：三个包 Makefile 都必须在
for p in luci-app-airoha-npu luci-app-pon-status luci-app-natmode; do
  [ -f "$PKG_DIR/$p/Makefile" ] || { echo "::error::$p Makefile 缺失"; exit 1; }
done

echo "✅ 状态插件全部就位:"
ls -1 "$PKG_DIR"
