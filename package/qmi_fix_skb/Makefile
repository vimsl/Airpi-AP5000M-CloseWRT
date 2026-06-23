include $(TOPDIR)/rules.mk

PKG_NAME:=qmi-fix-skb
PKG_RELEASE:=1

include $(INCLUDE_DIR)/kernel.mk

define KernelPackage/qmi-fix-skb
  SUBMENU:=Other modules
  TITLE:=QMI WWAN SKB Tailroom Fix via Kprobe
  DEPENDS:=+kmod-usb-net-qmi-wwan
  FILES:=$(PKG_BUILD_DIR)/qmi_fix_skb.ko
  AUTOLOAD:=$(call AutoLoad,30,qmi_fix_skb)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		M="$(PKG_BUILD_DIR)" \
		modules
endef

$(eval $(call KernelPackage,qmi-fix-skb))
