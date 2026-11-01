#!/bin/bash
# Generate a "pure" HG5382A configuration on top of the prepared .config.
# Keeps PON core + base system + common utilities (USB, filesystems, cron,
# UPnP, wireguard, flow offload); removes other-device-specific components.
# Note: this tree has no scripts/config helper (scripts/config is a directory),
# so symbols are toggled directly with sed/grep.
set -e

disable_sym() {
	local sym="$1"
	if grep -q "^${sym}=" .config; then
		sed -i "s|^${sym}=.*|# ${sym} is not set|" .config
	elif ! grep -q "^# ${sym} is not set" .config; then
		printf '# %s is not set\n' "$sym" >> .config
	fi
}

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

disable_pkg() {
	disable_sym "CONFIG_MODULE_DEFAULT_$1"
	disable_sym "CONFIG_DEFAULT_$1"
	disable_sym "CONFIG_PACKAGE_$1"
}

# 1. Keep only the HG5382A device: comment out every enabled device, then enable the target
sed -i -E 's|^(CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_.*)=y$|# \1 is not set|' .config
enable_sym CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_fiberhome_hg5382a

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
