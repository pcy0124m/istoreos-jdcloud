#!/bin/bash
#================================================================
# DIY Part 2 - 在 make defconfig 之前执行
# 用于确保设备支持、Argon 主题加载、精简配置
#================================================================
set -e

echo "===== DIY Part 2 开始 ====="

# ===== 确认 Argon 主题已被 feeds 加载 =====
echo "检查 Argon 主题是否已加载..."

if [ -d "feeds/kenzok8/luci-theme-argon" ] || [ -d "feeds/argon_theme" ]; then
    echo "Argon 主题 feed 已加载"
else
    echo "警告: Argon 主题 feed 未找到，尝试从源码中查找..."
    find package/ -name "*argon*" -type d 2>/dev/null || true
    find feeds/ -name "*argon*" -type d 2>/dev/null || true

    # 如果 feed 加载失败，尝试直接克隆 Argon 主题到 package 目录
    if [ ! -d "package/luci/themes/luci-theme-argon" ]; then
        echo "直接克隆 Argon 主题到 package 目录..."
        git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git \
            package/luci/themes/luci-theme-argon 2>/dev/null || true
    fi
    if [ ! -d "package/luci/applications/luci-app-argon-config" ]; then
        echo "直接克隆 Argon Config 到 package 目录..."
        git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git \
            package/luci/applications/luci-app-argon-config 2>/dev/null || true
    fi
fi

# ===== 确认目标设备是否在源码中存在 =====
echo "检查 RE-SP-01B 设备支持..."

DTS_FILE="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts"
if [ -f "$DTS_FILE" ]; then
    echo "找到 RE-SP-01B DTS 文件: $DTS_FILE"
else
    echo "警告: 未找到 $DTS_FILE"
    echo "该设备可能在当前 iStoreOS 分支中尚未同步"
fi

# 检查 mt7621.mk 中是否有该设备的定义
MK_FILE="target/linux/ramips/image/mt7621.mk"
DEVICE_FOUND="no"
if [ -f "$MK_FILE" ]; then
    if grep -q "jdcloud_re-sp-01b\|jdcloud_re_sp_01b\|jdcloud,re-sp-01" "$MK_FILE" 2>/dev/null; then
        echo "在 mt7621.mk 中找到 RE-SP-01B 设备定义"
        DEVICE_FOUND="yes"
    else
        echo "警告: 在 $MK_FILE 中未找到 RE-SP-01B 设备定义"
    fi
fi

# 移除源码中可能已存在的旧定义（避免冲突），然后添加正确的官方定义
if [ -f "$MK_FILE" ]; then
    # 移除已有的 jdcloud_re-sp-01b 定义块
    sed -i '/define Device\/jdcloud_re-sp-01b/,/TARGET_DEVICES += jdcloud_re-sp-01b/d' "$MK_FILE" 2>/dev/null || true
    # 移除可能残留的空行
    sed -i '/^$/{ N; /^\n$/D; }' "$MK_FILE" 2>/dev/null || true

    echo "添加 RE-SP-01B 设备定义到 mt7621.mk (来自 OpenWrt 官方 PR #17409)..."
    cat >> "$MK_FILE" << 'MKEOF'

# JDCloud RE-SP-01B (京东云无线宝第一代) - 来自 OpenWrt 官方 PR #17409
define Device/jdcloud_re-sp-01b
  $(Device/dsa-migration)
  IMAGE_SIZE := 27328k
  DEVICE_VENDOR := JDCloud
  DEVICE_MODEL := RE-SP-01B
   DEVICE_PACKAGES := kmod-mt7603 kmod-mt7615-firmware \
     kmod-mmc-mtk kmod-usb3
   NETWORKING := wan:lan
   LAN_PORTS := 0 1
   WAN_PORT := 5
 endef
 TARGET_DEVICES += jdcloud_re-sp-01b

MKEOF
    echo "已添加 RE-SP-01B 设备定义到 mt7621.mk"
fi

# 始终写入正确的 DTS 文件（覆盖旧版本），参考 OpenWrt 官方 PR #17409
if [ -d "target/linux/ramips/dts" ]; then
    echo "写入 RE-SP-01B DTS 文件 (参考 OpenWrt 官方 PR #17409)..."
    cat > "$DTS_FILE" << 'DTSEOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT

#include "mt7621.dtsi"

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>

/ {
	compatible = "jdcloud,re-sp-01b", "mediatek,mt7621-soc";
	model = "JDCloud RE-SP-01B";

	aliases {
		led-boot = &led_status_red;
		led-failsafe = &led_status_red;
		led-running = &led_status_green;
		led-upgrade = &led_status_blue;
		ethernet0 = &gmac0;
		ethernet1 = &gmac1;
	};

	chosen {
		bootargs = "console=ttyS0,115200";
	};

	keys {
		compatible = "gpio-keys";

		reset {
			label = "reset";
			gpios = <&gpio 18 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_RESTART>;
		};
	};

	leds {
		compatible = "gpio-leds";

		led_status_red: led-red {
			function = LED_FUNCTION_STATUS;
			color = <LED_COLOR_ID_RED>;
			gpios = <&gpio 6 GPIO_ACTIVE_LOW>;
		};

		led_status_green: led-green {
			function = LED_FUNCTION_STATUS;
			color = <LED_COLOR_ID_GREEN>;
			gpios = <&gpio 8 GPIO_ACTIVE_LOW>;
		};

		led_status_blue: led-blue {
			function = LED_FUNCTION_STATUS;
			color = <LED_COLOR_ID_BLUE>;
			gpios = <&gpio 12 GPIO_ACTIVE_LOW>;
		};
	};
};

&sdhci {
	status = "okay";
};

&spi0 {
	status = "okay";

	flash@0 {
		compatible = "jedec,spi-nor";
		reg = <0>;
		spi-max-frequency = <50000000>;

		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;

			partition@0 {
				label = "u-boot";
				reg = <0x0 0x30000>;
				read-only;
			};

			partition@30000 {
				label = "config";
				reg = <0x30000 0x10000>;
				read-only;
			};

			partition@40000 {
				label = "factory";
				reg = <0x40000 0x10000>;
				read-only;

				nvmem-layout {
					compatible = "fixed-layout";
					#address-cells = <1>;
					#size-cells = <1>;

					eeprom_factory_0: eeprom@0 {
						reg = <0x0 0x400>;
					};

					eeprom_factory_8000: eeprom@8000 {
						reg = <0x8000 0x4da8>;
					};
				};
			};

			partition@50000 {
				compatible = "denx,uimage";
				label = "firmware";
				reg = <0x50000 0x1ab0000>;
			};

			partition@1b00000 {
				label = "mini";
				reg = <0x1b00000 0x400000>;
				read-only;
			};

			partition@1f00000 {
				label = "oem";
				reg = <0x1f00000 0x100000>;
				read-only;
			};
		};
	};
};

 &gmac1 {
	status = "okay";
	label = "wan";
	phy-handle = <&ethphy0>;
};

&ethphy0 {
	/delete-property/ interrupts;
};

&switch0 {
	ports {
		port@1 {
			status = "okay";
			label = "lan1";
		};

		port@2 {
			status = "okay";
			label = "lan2";
		};
	};
};

&pcie {
	status = "okay";
};

&pcie0 {
	wifi@0,0 {
		compatible = "mediatek,mt76";
		reg = <0x0000 0 0 0 0>;
		nvmem-cells = <&eeprom_factory_0>;
		nvmem-cell-names = "eeprom";
		mediatek,mtd-eeprom = <&eeprom_factory_0>;
	};
};

&pcie1 {
	wifi@0,0 {
		compatible = "mediatek,mt76";
		reg = <0x0000 0 0 0 0>;
		nvmem-cells = <&eeprom_factory_8000>;
		nvmem-cell-names = "eeprom";
		mediatek,mtd-eeprom = <&eeprom_factory_8000>;
		ieee80211-freq-limit = <5000000 6000000>;
	};
};

&state_default {
	gpio {
		groups = "uart2", "uart3", "wdt";
		function = "gpio";
	};
};
DTSEOF
    echo "已写入 RE-SP-01B DTS 文件"
fi

# ===== 添加 board.d 网络配置 (来自 OpenWrt 官方 PR #17409) =====
BOARD_NETWORK_FILE="target/linux/ramips/mt7621/base-files/etc/board.d/02_network"
if [ -f "$BOARD_NETWORK_FILE" ]; then
    echo "添加 RE-SP-01B 网络配置到 02_network..."
    # 在 ramips_setup_interfaces 函数中添加 RE-SP-01B
    if ! grep -q "jdcloud,re-sp-01b" "$BOARD_NETWORK_FILE" 2>/dev/null; then
        # 添加到 jdcloud 设备列表
        sed -i '/jdcloud,re-cp-02/a\	jdcloud,re-sp-01b|\\' "$BOARD_NETWORK_FILE" 2>/dev/null || true
        # 添加 MAC 地址配置
        if ! grep -q "jdcloud,re-sp-01b)" "$BOARD_NETWORK_FILE" 2>/dev/null; then
            sed -i '/jdcloud,re-cp-02)/,/;;/ {
                /;;/ a\
\tjdcloud,re-sp-01b)\\n\t\tlan_mac=$(mtd_get_mac_ascii config mac)\\n\t\twan_mac=$lan_mac\\n\t\tlabel_mac=$lan_mac\\n\t\t;;
            }' "$BOARD_NETWORK_FILE" 2>/dev/null || true
        fi
        echo "已添加 RE-SP-01B 网络配置到 02_network"
    fi
fi

# ===== 添加 WiFi MAC 修复 (来自 OpenWrt 官方 PR #17409) =====
WIFI_MAC_FILE="target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac"
if [ -f "$WIFI_MAC_FILE" ]; then
    echo "添加 RE-SP-01B WiFi MAC 修复..."
    if ! grep -q "jdcloud,re-sp-01b" "$WIFI_MAC_FILE" 2>/dev/null; then
        # 在 jdcloud,re-cp-02 的 case 块之后添加
        sed -i '/jdcloud,re-cp-02)/,/;;/ {
            /;;/ a\
\tjdcloud,re-sp-01b)\\n\t\thw_mac_addr=$(mtd_get_mac_ascii config mac)\\n\t\t[ "$PHYNBR" = "0" ] \&\& echo $hw_mac_addr > /sys${DEVPATH}/macaddress\\n\t\t[ "$PHYNBR" = "1" ] \&\& macaddr_add $hw_mac_addr 0x800000 > /sys${DEVPATH}/macaddress\\n\t\t;;
        }' "$WIFI_MAC_FILE" 2>/dev/null || true
        echo "已添加 RE-SP-01B WiFi MAC 修复"
    fi
fi

# ===== 确保关键配置被写入 .config =====
echo "确保关键配置项..."
if [ -f .config ]; then
    # 确保目标平台正确
    if ! grep -q "CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-sp-01b=y" .config; then
        echo "CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-sp-01b=y" >> .config
    fi
    # 确保 Argon 主题被选中
    if ! grep -q "CONFIG_PACKAGE_luci-theme-argon=y" .config; then
        echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config
    fi
    # 确保 Argon Config 被选中
    if ! grep -q "CONFIG_PACKAGE_luci-app-argon-config=y" .config; then
        echo "CONFIG_PACKAGE_luci-app-argon-config=y" >> .config
    fi
    # 确保不选 iStoreOS 默认主题
    sed -i '/CONFIG_PACKAGE_luci-theme-istoreui/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-theme-istoreui-dark/d' .config 2>/dev/null || true

    # ===== 强制确保 LuCI 核心模块被选中 =====
    # make defconfig 可能会过滤掉这些包，必须强制写入
    echo "强制写入 LuCI 核心模块配置..."
    sed -i '/CONFIG_PACKAGE_luci-mod-admin-full/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-mod-system/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-mod-network/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-mod-status/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-app-uhttpd/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-proto-ppp/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-proto-ipv6/d' .config 2>/dev/null || true

    echo "CONFIG_PACKAGE_luci-mod-admin-full=y" >> .config
    echo "CONFIG_PACKAGE_luci-mod-system=y" >> .config
    echo "CONFIG_PACKAGE_luci-mod-network=y" >> .config
    echo "CONFIG_PACKAGE_luci-mod-status=y" >> .config
    echo "CONFIG_PACKAGE_luci-app-uhttpd=y" >> .config
    echo "CONFIG_PACKAGE_luci-proto-ppp=y" >> .config
    echo "CONFIG_PACKAGE_luci-proto-ipv6=y" >> .config
    echo "已强制写入 LuCI 核心模块配置"
fi

# ===== 预设路由器 IP 和网络配置 =====
echo "预设路由器网络配置..."

# 创建 UCI 默认配置文件，刷机后首次启动自动执行
# 设置 LAN IP 为 192.168.12.1，不预设密码（首次登录时自行设置）
UCI_DEFAULTS_DIR="package/base-files/files/etc/uci-defaults"
mkdir -p "$UCI_DEFAULTS_DIR"

cat > "$UCI_DEFAULTS_DIR/99-custom-network" << 'UCIEOF'
#!/bin/sh

# 设置 LAN IP 为 192.168.12.1
uci set network.lan.ipaddr='192.168.12.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.proto='static'
uci commit network

# 设置 DHCP 服务范围（192.168.12.100 - 192.168.12.250）
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci commit dhcp

# 不预设 root 密码，首次登录时由用户自行设置
# OpenWrt/iStoreOS 默认无密码，首次访问 LuCI 会提示设置密码

exit 0
UCIEOF
chmod +x "$UCI_DEFAULTS_DIR/99-custom-network"
echo "已预设路由器 LAN IP: 192.168.12.1 (无预设密码)"

# ===== 显示最终配置摘要 =====
echo "===== 配置摘要 ====="
echo "目标平台: ramips/mt7621"
echo "目标设备: jdcloud_re-sp-01b (JDCloud RE-SP-01B)"
echo "源码分支: $ISTOREOS_BRANCH"
echo "主题: Argon"
echo "路由器 IP: 192.168.12.1"
echo "管理员密码: 无预设 (首次登录自行设置)"
echo "固件目标: < 22MB (精简版)"

echo "===== DIY Part 2 完成 ====="
