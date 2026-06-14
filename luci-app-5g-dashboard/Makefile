include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-5g-dashboard
PKG_VERSION:=1.0.0
PKG_RELEASE:=2

PKG_MAINTAINER:=5G Dashboard
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-5g-dashboard
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=5G Cellular Network Dashboard
  DEPENDS:=+jshn
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

	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) ./root/www/cgi-bin/get_5g_info $(1)/www/cgi-bin/
	chmod 0755 $(1)/www/cgi-bin/get_5g_info

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/5g-dashboard $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-5g-dashboard.json $(1)/usr/share/luci/menu.d/
endef

$(eval $(call BuildPackage,luci-app-5g-dashboard))
