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
  DEVICE_PACKAGES := kmod-mt7603 kmod-mt7615-firmware kmod-mmc-mtk kmod-usb3
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

		port@3 {
			status = "okay";
			label = "lan3";
		};

		port@4 {
			status = "okay";
			label = "lan4";
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
	};
};

 &pcie1 {
	wifi@0,0 {
		compatible = "mediatek,mt76";
		reg = <0x0000 0 0 0 0>;
		nvmem-cells = <&eeprom_factory_8000>;
		nvmem-cell-names = "eeprom";
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
    # 移除已有的 jdcloud,re-sp-01b 定义（避免重复）
    sed -i '/jdcloud,re-sp-01b/d' "$BOARD_NETWORK_FILE" 2>/dev/null || true
    # 在 jdcloud,re-cp-02 的接口定义行后添加 RE-SP-01B
    if grep -q "jdcloud,re-cp-02|" "$BOARD_NETWORK_FILE" 2>/dev/null; then
        sed -i '/jdcloud,re-cp-02|\\/a\\
	jdcloud,re-sp-01b|\\' "$BOARD_NETWORK_FILE" 2>/dev/null || true
    fi
    # 移除已有的 MAC 地址定义（避免重复）
    sed -i '/jdcloud,re-sp-01b)/,/;;/d' "$BOARD_NETWORK_FILE" 2>/dev/null || true
    # 在 jdcloud,re-cp-02 的 MAC 定义块后添加 RE-SP-01B
    if grep -q "jdcloud,re-cp-02)" "$BOARD_NETWORK_FILE" 2>/dev/null; then
        sed -i '/jdcloud,re-cp-02)/,/;;/ {
            /;;/ a\
\tjdcloud,re-sp-01b)\\n\t\tlan_mac=$(mtd_get_mac_ascii config mac)\\n\t\twan_mac=$lan_mac\\n\t\tlabel_mac=$lan_mac\\n\t\t;;
        }' "$BOARD_NETWORK_FILE" 2>/dev/null || true
    fi
    echo "已添加 RE-SP-01B 网络配置到 02_network"
fi

# ===== 添加 WiFi MAC 修复 (来自 OpenWrt 官方 PR #17409) =====
WIFI_MAC_FILE="target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac"
if [ -f "$WIFI_MAC_FILE" ]; then
    echo "添加 RE-SP-01B WiFi MAC 修复..."
    # 移除已有的定义（避免重复）
    sed -i '/jdcloud,re-sp-01b)/,/;;/d' "$WIFI_MAC_FILE" 2>/dev/null || true
    # 在 jdcloud,re-cp-02 的 case 块之后添加
    sed -i '/jdcloud,re-cp-02)/,/;;/ {
        /;;/ a\
\tjdcloud,re-sp-01b)\\n\t\thw_mac_addr=$(mtd_get_mac_ascii config mac)\\n\t\t[ "$PHYNBR" = "0" ] \&\& echo $hw_mac_addr > /sys${DEVPATH}/macaddress\\n\t\t[ "$PHYNBR" = "1" ] \&\& macaddr_add $hw_mac_addr 0x800000 > /sys${DEVPATH}/macaddress\\n\t\t;;
    }' "$WIFI_MAC_FILE" 2>/dev/null || true
    echo "已添加 RE-SP-01B WiFi MAC 修复"
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

    # 注意: LuCI 核心模块的强制写入已移至 workflow 的 make defconfig 后处理
    # 在 diy-part2.sh 中写入会被随后的 make defconfig 过滤掉
fi

# ===== 预设路由器 IP 和网络配置 =====
echo "预设路由器网络配置..."

UCI_DEFAULTS_DIR="package/base-files/files/etc/uci-defaults"
mkdir -p "$UCI_DEFAULTS_DIR"

# ===== 直接内置 /etc/config/network 作为最终兜底 =====
# 如果 uci-defaults 脚本失败, OpenWrt 启动时会使用此文件
mkdir -p package/base-files/files/etc/config
cat > package/base-files/files/etc/config/network << 'NETCFG'
config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.12.1'
    option netmask '255.255.255.0'

config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'lan1'
    list ports 'lan2'
    list ports 'lan3'
    list ports 'lan4'
    list ports 'wan'
NETCFG
echo "已内置 /etc/config/network (桥接所有网口, IP: 192.168.12.1)"

# 内置 DHCP 配置
cat > package/base-files/files/etc/config/dhcp << 'DHCPCFG'
config dnsmasq
    option domainneeded '1'
    option localise_queries '1'
    option rebind_protection '1'
    option local '/lan/'
    option domain 'lan'
    option expandhosts '1'
    option leasefile '/tmp/dhcp.leases'
    option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'

config dhcp 'lan'
    option interface 'lan'
    option start '100'
    option limit '150'
    option leasetime '12h'
    option dhcpv4 'server'
    option dhcpv6 'server'
    option ra 'server'
DHCPCFG
echo "已内置 /etc/config/dhcp (DHCP 服务器)"

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

# ===== 网口配置兜底: 强制所有网口加入 LAN 桥 =====
# 无论 02_network 注入是否成功, 都确保任意网口插入即可访问 192.168.12.1
# 此脚本用低编号 (10) 确保在早期执行
cat > "$UCI_DEFAULTS_DIR/10-fix-network-bridge" << 'NETEOF'
#!/bin/sh
# 网口兜底配置 - 所有网口加入 LAN 桥, 任意口可访问

LOG="/tmp/fix-network.log"
echo "===== 网口兜底配置启动 =====" >> "$LOG"
echo "当前时间: $(date)" >> "$LOG"

# 列出所有可用的网口
echo "所有可用网口:" >> "$LOG"
ip link show >> "$LOG" 2>&1

# 等待网口出现 (最长 120 秒)
FOUND=0
for i in $(seq 1 40); do
    PORTS=""
    # 遍历所有可能的网口名
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        # 跳过 lo 和 br-lan
        case "$iface" in
            lo|br-lan) continue ;;
            *) PORTS="$PORTS $iface" ;;
        esac
    done
    PORTS=$(echo "$PORTS" | xargs)
    if [ -n "$PORTS" ]; then
        FOUND=1
        echo "  [$i] 检测到网口: $PORTS" >> "$LOG"
        break
    fi
    sleep 3
done

if [ "$FOUND" = "0" ]; then
    echo "  错误: 未找到任何网口!" >> "$LOG"
    # 最后尝试: 使用 eth0
    PORTS="eth0"
    echo "  尝试使用: $PORTS" >> "$LOG"
fi

echo "  桥接端口: $PORTS" >> "$LOG"

# 重置网络配置
uci -q batch << 'UCISCRIPT'
delete network.lan
delete network.wan
delete network.wan6
UCISCRIPT

# 删除所有 device 段
for idx in $(seq 0 10); do
    uci -q delete network.@device[0]
done

# 创建桥接设备
uci add network device
uci set network.@device[-1].name='br-lan'
uci set network.@device[-1].type='bridge'

# 逐个添加网口到桥
for port in $PORTS; do
    uci add_list network.@device[-1].ports="$port"
done

# 创建 LAN 接口
uci set network.lan=interface
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.12.1'
uci set network.lan.netmask='255.255.255.0'

# DHCP 服务
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

uci commit network
uci commit dhcp

echo "网口配置完成, br-lan 包含: $PORTS" >> "$LOG"

# 重启网络
/etc/init.d/network restart >> "$LOG" 2>&1
sleep 5

# 验证网络状态
echo "网络重启后状态:" >> "$LOG"
ip addr show >> "$LOG" 2>&1
brctl show >> "$LOG" 2>&1 || bridge link show >> "$LOG" 2>&1

# 确保 uhttpd 运行
/etc/init.d/uhttpd enable >> "$LOG" 2>&1
/etc/init.d/uhttpd start >> "$LOG" 2>&1

echo "===== 网口兜底配置完成 =====" >> "$LOG"
exit 0
NETEOF
chmod +x "$UCI_DEFAULTS_DIR/10-fix-network-bridge"
echo "已添加网口兜底配置 (所有网口加入 LAN 桥)"

# ===== 热插拔网口兜底: 网口出现时自动加入 LAN 桥 =====
# 当 DSA 驱动创建网口后, 热插拔脚本自动将其加入 br-lan
mkdir -p package/base-files/files/etc/hotplug.d/iface
cat > package/base-files/files/etc/hotplug.d/iface/10-fix-bridge << 'HOTPLUG'
#!/bin/sh
# 热插拔: 检测到新网口时, 自动加入 br-lan 桥

[ "$ACTION" = "ifup" ] || [ "$ACTION" = "add" ] || exit 0

case "$INTERFACE" in
    lan[0-9]*|wan|eth[0-9]*|br-lan|lo) ;;
    *) exit 0 ;;
esac
# 跳过 lo 和 br-lan 自身
[ "$INTERFACE" = "lo" ] || [ "$INTERFACE" = "br-lan" ] && exit 0
# 等待 br-lan 出现
for i in $(seq 1 10); do
    [ -d /sys/class/net/br-lan ] && break
    sleep 1
done
# 使用 ip link set master 将网口加入桥
if [ -d /sys/class/net/br-lan ] && [ -d /sys/class/net/$INTERFACE ]; then
    ip link set dev "$INTERFACE" master br-lan 2>/dev/null && logger "[hotplug] Added $INTERFACE to br-lan"
fi
exit 0
HOTPLUG
chmod +x package/base-files/files/etc/hotplug.d/iface/10-fix-bridge
echo "已添加热插拔网口兜底脚本"

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
