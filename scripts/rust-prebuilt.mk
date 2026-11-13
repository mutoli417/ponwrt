# SPDX-License-Identifier: MIT
#
# rust-prebuilt.mk —— 预编译 Rust 工具链的 HostBuild 规则片段
#
# 由 prepare-rust.sh 拼进 feeds/packages/lang/rust/ci-prebuilt.mk，
# 并在 $(eval $(call HostBuild)) 之前 include。
# 保留 OpenWrt 正常的 host stamp，但不下载源码、不自举：
#   Host/Prepare、Host/Configure 置空；Host/Compile 只打印版本；
#   Host/Install 只在 staging_dir/host/bin 建三个符号链接，指向
#   CI_RUST_ROOT（runner rustup sysroot）。rustc 的 30~60 分钟自举
#   由此变成几秒。
#
# CI_RUST_ROOT 由 prepare-rust.sh 在本片段之前写入 ci-prebuilt.mk。

PKG_SOURCE:=
PKG_SOURCE_URL:=

define Host/Prepare
endef

define Host/Configure
endef

define Host/Compile
	"$(CI_RUST_ROOT)/bin/rustc" --version
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR)/host/bin
	ln -sfn "$(CI_RUST_ROOT)/bin/cargo"   "$(STAGING_DIR)/host/bin/cargo"
	ln -sfn "$(CI_RUST_ROOT)/bin/rustc"   "$(STAGING_DIR)/host/bin/rustc"
	ln -sfn "$(CI_RUST_ROOT)/bin/rustdoc" "$(STAGING_DIR)/host/bin/rustdoc"
endef

define Host/Uninstall
	rm -f $(addprefix $(STAGING_DIR)/host/bin/,cargo rustc rustdoc)
endef
