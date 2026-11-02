#!/bin/bash
# Build configuration for FiberHome HG5585F CT:
#   keep the device's stock feature set (Wi-Fi, PON, USB, wpad) and add
#   ShadowsocksR Plus+ (with Simplified Chinese translation) plus PassWall.
# The helloworld feed is appended last in feeds.conf.default so the official
# packages/luci feeds win on duplicate package names; helloworld only supplies
# luci-app-ssr-plus and its unique dependencies (e.g. shadowsocksr-libev).
set -e

enable_sym() {
	local sym="$1"
	if grep -q "^# ${sym} is not set" .config; then
		sed -i "s|^# ${sym} is not set|${sym}=y|" .config
	elif grep -q "^${sym}=" .config; then
		sed -i "s|^${sym}=.*|${sym}=y|" .config
	else
		printf '%s=y\n' "$sym" >> .config
	fi
}

# 1. Keep only the HG5585F CT device: comment out every enabled device, then re-enable the target.
sed -i -E 's|^(CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_.*)=y$|# \1 is not set|' .config
enable_sym CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_fiberhome_hg5585f-ct

# 2. ShadowsocksR Plus+ and its Simplified Chinese translation.
enable_sym CONFIG_PACKAGE_luci-app-ssr-plus
enable_sym CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn

# 3. ShadowsocksR Plus+ cores so it works out of the box:
#    SSR-libev client (the signature core), Xray, and ChinaDNS-NG.
#    The nftables transparent-proxy backend is selected automatically by
#    defconfig because this image uses firewall4.
enable_sym CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Libev_Client
enable_sym CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray
enable_sym CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ChinaDNS_NG

# 4. PassWall and its Simplified Chinese translation.
#    PassWall's own default aarch64 options (Xray, sing-box, smartdns,
#    shadowsocks-rust, simple-obfs, geoview, haproxy) stay enabled via defconfig.
enable_sym CONFIG_PACKAGE_luci-app-passwall
enable_sym CONFIG_PACKAGE_luci-i18n-passwall-zh-cn

echo "HG5585F CT + ShadowsocksR Plus+ + PassWall configuration ready."
