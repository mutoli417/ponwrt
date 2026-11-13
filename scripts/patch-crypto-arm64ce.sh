#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# =============================================================
# patch-crypto-arm64ce.sh —— 把 ARM64 汇编加密实现写进 target 内核 config
#
#   背景：workflow 的 opt_arm64ce 只把 WANT_ARM64CE 写进环境，此前没有
#   任何一步改 target/linux/airoha/<soc>/config-*，Validate 读不到
#   CONFIG_CRYPTO_AES_ARM64 必然报"未生效"。本脚本按 SoC 拆分写入：
#     an7583 有 aes/pmull/sha1/sha2 → Crypto Extensions (CE)
#     an7581 无 AES 指令          → NEON 位切片 (bitsliced NEON)
#
#   用法: bash scripts/patch-crypto-arm64ce.sh [openwrt_dir]
#   环境: SOC, WANT_ARM64CE（或 OPT_CRYPTO_ARM64CE 兜底）
#   语义: 软失败 —— 找不到内核 config / 开关未开只 warning，不中断构建。
# =============================================================

set -uo pipefail

OW="${1:-$PWD}"
cd "$OW" || { echo "::error::无法进入 $OW"; exit 1; }

WANT="${WANT_ARM64CE:-${OPT_CRYPTO_ARM64CE:-0}}"
SOC="${SOC:-}"

warn() { echo "::warning::$1"; }

if [ "$WANT" != "1" ]; then
  echo "ARM64CE 未开启（WANT_ARM64CE=$WANT），跳过内核符号注入"
  exit 0
fi

# 定位 target 内核 config：先精确子目标，再退回 an7581/an7583/generic
KCFG=""
base="target/linux/airoha"
if [ -d "$base" ]; then
  for d in "$base/$SOC" "$base/an7581" "$base/an7583" "$base/generic"; do
    [ -d "$d" ] || continue
    f="$(ls "$d"/config-* 2>/dev/null | head -1)"
    if [ -n "$f" ]; then KCFG="$f"; break; fi
  done
fi

if [ -z "$KCFG" ] || [ ! -f "$KCFG" ]; then
  warn "ARM64CE=1 但未定位到 target/linux/airoha/*/config-*，跳过内核符号写入"
  exit 0
fi
echo "ARM64CE 内核 config: $KCFG (SOC=${SOC:-未知})"

set_kcfg() {
  local file="$1"; shift
  local kv k
  for kv in "$@"; do
    k="${kv%%=*}"
    sed -i "/^${k}=/d; /^# ${k} is not set\$/d" "$file"
    printf '%s\n' "$kv" >> "$file"
  done
}

COMMON_KCFG="
CONFIG_ARM64_CRYPTO=y
CONFIG_CRYPTO_SIMD=y
CONFIG_CRYPTO_CRYPTD=y
CONFIG_CRYPTO_AES_ARM64=y
CONFIG_CRYPTO_SHA256_ARM64=y
CONFIG_CRYPTO_SHA512_ARM64=y"

if [ "$SOC" = "an7583" ]; then
  # AN7583: /proc/cpuinfo 有 aes pmull sha1 sha2，走 Crypto Extensions
  SOC_KCFG="
CONFIG_CRYPTO_AES_ARM64_CE=y
CONFIG_CRYPTO_AES_ARM64_CE_BLK=y
CONFIG_CRYPTO_AES_ARM64_CE_CCM=y
CONFIG_CRYPTO_GHASH_ARM64_CE=y
CONFIG_CRYPTO_SHA1_ARM64_CE=y
CONFIG_CRYPTO_SHA2_ARM64_CE=y
CONFIG_CRYPTO_SHA512_ARM64_CE=y"
else
  # an7581（SOC 缺失时兜底同此路径）：NEON 位切片
  SOC_KCFG="
CONFIG_CRYPTO_AES_ARM64_BS=y
CONFIG_CRYPTO_AES_ARM64_NEON_BLK=y"
fi

# 不加引号：按行把两组符号展开成位置参数；符号名/值均不含空格
# shellcheck disable=SC2086
set_kcfg "$KCFG" $COMMON_KCFG $SOC_KCFG

echo "✅ ARM64CE 内核符号已写入 $KCFG"
exit 0
