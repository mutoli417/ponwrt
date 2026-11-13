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
# 与 custom-packages.zip 的关系:
#   仓库根目录的 custom-packages.zip 会在前一步解压到 package/custom/，
#   三个包可能已被预置。因此这里一律先克隆到临时目录再拷贝覆盖；
#   远程克隆失败时保留 zip 预置版本（只警告），两边都缺 Makefile 才报错。
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

# 从临时目录拷贝一个包进 PKG_DIR；源里缺 Makefile 时不动现有目录
install_pkg() { # install_pkg <pkg> <src_dir>
  local p="$1" src="$2"
  if [ ! -f "$src/$p/Makefile" ]; then
    echo "::warning::$src/$p/Makefile 不存在，保留 package/custom 现有版本（如有）"
    return 1
  fi
  rm -rf "$PKG_DIR/$p"
  cp -r "$src/$p" "$PKG_DIR/"
  echo "✅ $p 已就位: package/custom/$p"
}

mkdir -p "$PKG_DIR"

# 1) qwe-qaq/luci-app：luci-app-natmode + luci-app-pon-status（先克隆到临时目录）
if clone "$LUCI_APP_URL" "$TMP/luci-app"; then
  for p in luci-app-natmode luci-app-pon-status; do
    install_pkg "$p" "$TMP/luci-app" || true
  done
else
  echo "::warning::拉取 $LUCI_APP_URL 失败，沿用 custom-packages.zip 预置目录"
fi

# 2) luanmuc/luci-app-airoha-npu：仓库根目录即包目录。
#    不能直接 clone 进 $PKG_DIR/luci-app-airoha-npu —— zip 预置时该目录已
#    存在且非空，git clone 会拒绝克隆非空目标。先克隆到 TMP 再拷贝。
if clone "$NPU_URL" "$TMP/airoha-npu"; then
  rm -rf "$PKG_DIR/luci-app-airoha-npu"
  cp -r "$TMP/airoha-npu" "$PKG_DIR/luci-app-airoha-npu"
  echo "✅ luci-app-airoha-npu 已就位: package/custom/luci-app-airoha-npu"
else
  echo "::warning::拉取 $NPU_URL 失败，沿用 custom-packages.zip 预置目录"
fi

# 3) 执行权限：拷贝/解压不保留 rpcd 后端、/usr/sbin 工具、init.d 脚本可执行位
find "$PKG_DIR" -path "*/libexec/rpcd/*"  -type f -exec chmod 0755 {} \;
find "$PKG_DIR" -path "*/usr/sbin/*"      -type f -exec chmod 0755 {} \;
find "$PKG_DIR" -path "*/etc/init.d/*"     -type f -exec chmod 0755 {} \;

# 4) 完整性复核：三个包都必须有 Makefile（远程克隆或 zip 预置任一来源即可）
MISSING=""
for p in luci-app-airoha-npu luci-app-pon-status luci-app-natmode; do
  if [ ! -f "$PKG_DIR/$p/Makefile" ]; then
    MISSING="$MISSING $p"
  fi
done
if [ -n "$MISSING" ]; then
  echo "::error::状态插件 Makefile 缺失:$MISSING（远程拉取失败且 custom-packages.zip 未预置）"
  exit 1
fi

echo "✅ 状态插件全部就位:"
ls -1 "$PKG_DIR"
