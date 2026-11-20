#!/usr/bin/env bash
# =============================================================
# patch-ssrplus-decouple.sh —— ssr-plus 与系统转发/DNS 解耦（层 A：钩子降级）
#
#   背景：线上 HG5382A 断网根因是 WAN(pppoe) ifup 时，hotplug 钩子
#     /etc/hotplug.d/iface/99-ssrplus-pppoe 在 sleep 10 后调用
#     /etc/init.d/shadowsocksr restart，整服务重启期间：
#       - 杀掉 v2ray/xray、dns2tcp、ssr-switch、ssr-monitor、ssr-rules；
#       - 两次 restart dnsmasq；
#       - flush/restore nft 规则；
#     形成约十数秒的转发 + DNS 空窗。
#
#   层 A（本脚本，低风险，线上已运行态验证）：
#     钩子不再整重启服务，改为只从持久化文件恢复 nft 规则：
#       /usr/bin/ssr-rules -R
#     不杀核心进程、不碰 dnsmasq；WAN ifup 后转发/DNS 不断。
#     保留 ifup / wan / pppoe 判断、锁文件与 sleep 10（等 WAN 规则就绪）。
#
#   待办（层 B/C/E，暂不改动，待方案确认后再补）：
#     - 层 B：ssr-monitor 五处整重启（redir tcp/udp、server、local、builtin dns）
#       改局部补拉；当前维持现状。
#     - 层 C：start/stop 内两处 dnsmasq restart 是手动启停/切节点后让注入
#       生效所必需，不删除；日常 ifup 已不再走 start/stop。
#     - 层 E：check_server 节点类型异常的自愈 restart 保留。
#
#   幂等：重复执行不会二次改动；钩子缺失只警告不阻断。
#   用法: bash patch-ssrplus-decouple.sh [openwrt_dir]
# =============================================================

set -u

OW="${1:-$PWD}"
cd "$OW" || { echo "::error::无法进入 $OW"; exit 1; }

HOOK="package/feeds/helloworld/luci-app-ssr-plus/root/etc/hotplug.d/iface/99-ssrplus-pppoe"

if [ ! -f "$HOOK" ]; then
  echo "::warning::$HOOK 不存在，跳过 ssr-plus 钩子解耦"
  exit 0
fi

if grep -q "ssr-rules -R" "$HOOK"; then
  echo "ssr-plus 钩子已降级为规则恢复（ssr-rules -R），跳过"
  exit 0
fi

if ! grep -q "/etc/init.d/shadowsocksr restart" "$HOOK"; then
  echo "::warning::$HOOK 未匹配到 shadowsocksr restart 调用，保持原样"
  exit 0
fi

BEFORE=$(md5sum "$HOOK" | cut -d' ' -f1)

# 只把钩子里的整重启命令换成规则恢复；保留行内重定向 >/dev/null 2>&1
sed -i 's#/etc/init.d/shadowsocksr restart#/usr/bin/ssr-rules -R#' "$HOOK"

AFTER=$(md5sum "$HOOK" | cut -d' ' -f1)

if [ "$BEFORE" != "$AFTER" ]; then
  if sh -n "$HOOK" 2>/dev/null; then
    echo "✅ 已将 ssr-plus pppoe 钩子由整重启降级为规则恢复（ssr-rules -R）"
  else
    echo "::error::$HOOK 语法校验未通过，回滚本次改动"
    sed -i 's#/usr/bin/ssr-rules -R#/etc/init.d/shadowsocksr restart#' "$HOOK"
    exit 1
  fi
  if grep -n "shadowsocksr restart" "$HOOK"; then
    echo "::warning::钩子内仍有 shadowsocksr restart 残留，见上方行号"
  else
    echo "  复核：钩子已无整重启调用"
  fi
else
  echo "::warning::未匹配到 restart 内容，$HOOK 保持原样"
fi

exit 0
