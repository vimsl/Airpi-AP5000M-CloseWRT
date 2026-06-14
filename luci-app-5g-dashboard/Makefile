include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-5g-dashboard
PKG_VERSION:=1.0.0
PKG_RELEASE:=3

PKG_MAINTAINER:=5G Dashboard
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-5g-dashboard
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=5G Cellular Network Dashboard
  PKGARCH:=all
endef

define Package/luci-app-5g-dashboard/description
  A modern 5G cellular network dashboard for OpenWrt.
endef

define Package/luci-app-5g-dashboard/install
	$(INSTALL_DIR) $(1)/www/5g-dashboard
	$(INSTALL_DATA) ./root/www/5g-dashboard/index.html $(1)/www/5g-dashboard/
	$(INSTALL_DATA) ./root/www/5g-dashboard/style.css $(1)/www/5g-dashboard/
	$(INSTALL_DATA) ./root/www/5g-dashboard/main.js $(1)/www/5g-dashboard/
endef

$(eval $(call BuildPackage,luci-app-5g-dashboard))
