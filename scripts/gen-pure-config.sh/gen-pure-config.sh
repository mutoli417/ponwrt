#!/bin/bash
# Generate a "pure" HG5382A configuration on top of the prepared .config.
# Keeps PON core + base system + common utilities (USB, filesystems, cron,
# UPnP, wireguard, flow offload); removes other-device-specific components.
set -e
CFG=./scripts/config

# 1. Keep only the HG5382A device: comment out every enabled device, then enable the target
sed -i -E 's|^(CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_.*)=y$|# \1 is not set|' .config
$CFG --enable CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_fiberhome_hg5382a

# Helper: disable both the target-default marker and the actual package symbol
disable_pkg() {
	$CFG --disable "CONFIG_MODULE_DEFAULT_$1" 2>/dev/null || true
	$CFG --disable "CONFIG_DEFAULT_$1" 2>/dev/null || true
	$CFG --disable "CONFIG_PACKAGE_$1"
}

# 2. Other-device-specific Wi-Fi firmware / EEPROM
for p in kmod-mt7915e kmod-mt7916-firmware znxt-zn515-mt7916-eeprom rtl826x-firmware; do
	disable_pkg "$p"
done

# 3. External / SFP PHY drivers (HG5382A uses the internal PON)
for p in kmod-phy-airoha-en8811h kmod-phy-maxlinear kmod-phy-realtek; do
	disable_pkg "$p"
done

# 4. IPTV plugin
disable_pkg luci-app-iptv
disable_pkg luci-i18n-iptv-zh-cn

echo "Pure HG5382A configuration pruned."
