#!/usr/bin/env bash
# =============================================================
# patch-ssrplus-kcptun.sh —— 摘除 ssr-plus 失效的 Kcptun 选项
#
#   背景：fw876/helloworld 锁定快照里 luci-app-ssr-plus 的 Makefile 仍声明
#     +PACKAGE_..._INCLUDE_Kcptun:kcptun-client 条件依赖，但三个已安装 feed
#     （packages / routing / helloworld）都不再提供 kcptun-client 包
#     （packages 里的 xkcptun 是另一个包，不是它）。defconfig 解析 Makefile
#     时发现被依赖包不存在，报：
#       WARNING: Makefile '.../luci-app-ssr-plus/Makefile' has a dependency
#                on 'kcptun-client', which does not exist
#   Kcptun 选项默认 n，上游也已无对应二进制包，属失效残留；这里连依赖行、
#   PKG_CONFIG_DEPENDS 条目和 config 配置块一起删掉。
#   幂等：重复执行不会二次改动；Makefile 缺失只警告不阻断。
#   用法: bash patch-ssrplus-kcptun.sh [openwrt_dir]
# =============================================================

set -u

OW="${1:-$PWD}"
cd "$OW" || { echo "::error::无法进入 $OW"; exit 1; }

MK="package/feeds/helloworld/luci-app-ssr-plus/Makefile"

if [ ! -f "$MK" ]; then
  echo "::warning::$MK 不存在，跳过 ssr-plus Kcptun 清理"
  exit 0
fi

if ! grep -q "INCLUDE_Kcptun" "$MK"; then
  echo "ssr-plus Makefile 已无 Kcptun 引用，跳过"
  exit 0
fi

BEFORE=$(md5sum "$MK" | cut -d' ' -f1)

# 1) DEPENDS 条件依赖行：+PACKAGE_..._INCLUDE_Kcptun:kcptun-client
# 2) PKG_CONFIG_DEPENDS 条目：CONFIG_PACKAGE_..._INCLUDE_Kcptun \
# 3) config 配置块：config 头已被本行 next 跳过，skip=3 再吃掉
#    紧随的 bool / default n / 空行（注意不是 4：头行不计入 skip）
awk '
  /INCLUDE_Kcptun:kcptun-client/ { next }
  /^[[:space:]]*CONFIG_PACKAGE_\$\(PKG_NAME\)_INCLUDE_Kcptun[[:space:]]*\\/ { next }
  /^config PACKAGE_\$\(PKG_NAME\)_INCLUDE_Kcptun[[:space:]]*$/ { skip=3; next }
  skip>0 { skip--; next }
  { print }
' "$MK" > "$MK.tmp" && mv "$MK.tmp" "$MK"

AFTER=$(md5sum "$MK" | cut -d' ' -f1)

if [ "$BEFORE" != "$AFTER" ]; then
  echo "✅ 已摘除 ssr-plus 失效的 Kcptun 选项（依赖行 / 配置条目 / 配置块）"
  if grep -n "Kcptun\|kcptun" "$MK"; then
    echo "::warning::仍有 Kcptun 残留，见上方行号"
  else
    echo "  复核：Makefile 已无 Kcptun/kcptun 残留"
  fi
else
  echo "::warning::未匹配到 Kcptun 内容，$MK 保持原样"
fi

exit 0
