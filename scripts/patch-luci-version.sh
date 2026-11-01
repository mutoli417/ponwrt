#!/bin/bash
# After `scripts/feeds install`, force the LuCI version suffix from "~<hash>"
# to " mutoli" so the UI shows e.g. "LuCI Master 26.302.04020 mutoli".
# The findrev() function in feeds/luci/luci.mk prints:
#   printf '%s.%05d~%s' "$yday" "$secs" "$hash"
# We drop the "~<hash>" tail and append " mutoli" instead.
set -e

LUCI_MK=feeds/luci/luci.mk

if [ ! -f "$LUCI_MK" ]; then
	echo "ERROR: $LUCI_MK not found - run ./scripts/feeds install first" >&2
	exit 1
fi

sed -i "s|'%s.%05d~%s'|'%s.%05d mutoli'|" "$LUCI_MK"

if grep -q "'%s.%05d mutoli'" "$LUCI_MK"; then
	echo "LuCI version suffix patched -> ' mutoli'"
else
	echo "ERROR: LuCI version pattern not found in $LUCI_MK" >&2
	exit 1
fi
