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

# ===== 添加 board.d 网络配置 (官方: lan1 lan2 + wan) =====
BOARD_NETWORK_FILE="target/linux/ramips/mt7621/base-files/etc/board.d/02_network"
if [ -f "$BOARD_NETWORK_FILE" ]; then
    echo "注入 RE-SP-01B 到 02_network..."
    sed -i '/jdcloud,re-sp-01b/d' "$BOARD_NETWORK_FILE" 2>/dev/null || true
    python3 - << 'PY'
from pathlib import Path
p = Path("target/linux/ramips/mt7621/base-files/etc/board.d/02_network")
text = p.read_text()
iface = """\tjdcloud,re-sp-01b)
\t\tucidef_set_interface_lan "lan1 lan2 wan"
\t\t;;
"""
mac = """\tjdcloud,re-sp-01b)
\t\tlan_mac=$(mtd_get_mac_ascii config mac)
\t\twan_mac=$lan_mac
\t\tlabel_mac=$lan_mac
\t\t;;
"""
# 在 ramips_setup_interfaces 的 case 后插入接口定义
marker = "ramips_setup_interfaces()"
idx = text.find(marker)
if idx >= 0:
    case_idx = text.find("case $board in", idx)
    if case_idx >= 0:
        insert_at = text.find("\n", case_idx) + 1
        text = text[:insert_at] + iface + text[insert_at:]
# 在 ramips_setup_macs 的 case 后插入 MAC 定义
marker = "ramips_setup_macs()"
idx = text.find(marker)
if idx >= 0:
    case_idx = text.find("case $board in", idx)
    if case_idx >= 0:
        insert_at = text.find("\n", case_idx) + 1
        text = text[:insert_at] + mac + text[insert_at:]
p.write_text(text)
print("02_network 注入完成")
print("--- 校验 ---")
for line in text.splitlines():
    if "jdcloud,re-sp-01b" in line or ("lan1 lan2" in line and "wan" in line):
        print(line)
PY
fi

# ===== 添加 WiFi MAC 修复 =====
WIFI_MAC_FILE="target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac"
if [ -f "$WIFI_MAC_FILE" ]; then
    echo "添加 RE-SP-01B WiFi MAC 修复..."
    python3 - << 'PY'
from pathlib import Path
p = Path("target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac")
text = p.read_text()
block = """\tjdcloud,re-sp-01b)
\t\thw_mac_addr=$(mtd_get_mac_ascii config mac)
\t\t[ "$PHYNBR" = "0" ] && echo $hw_mac_addr > /sys${DEVPATH}/macaddress
\t\t[ "$PHYNBR" = "1" ] && macaddr_add $hw_mac_addr 0x800000 > /sys${DEVPATH}/macaddress
\t\t;;
"""
if "jdcloud,re-sp-01b)" not in text:
    idx = text.find("case $board in")
    if idx >= 0:
        insert_at = text.find("\n", idx) + 1
        text = text[:insert_at] + block + text[insert_at:]
        p.write_text(text)
        print("WiFi MAC 注入完成")
    else:
        print("[WARN] 未找到 case $board in，跳过 WiFi MAC 注入")
else:
    print("WiFi MAC 已存在，跳过")
PY
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

# ===== 把默认 LAN IP 写进 config_generate（不依赖 uci-defaults）=====
echo "修改 config_generate 默认 LAN IP 为 192.168.12.1..."
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.12.1/g' package/base-files/files/bin/config_generate
    sed -i 's/192.168.100.1/192.168.12.1/g' package/base-files/files/bin/config_generate
fi
if [ -d package/istoreos-files ]; then
    grep -rl '192.168.100.1' package/istoreos-files 2>/dev/null | while read -r f; do
        sed -i 's/192.168.100.1/192.168.12.1/g' "$f"
    done
fi

# ===== 预设路由器 IP + 每次开机强制 LAN =====
echo "预设路由器网络配置..."
UCI_DEFAULTS_DIR="package/base-files/files/etc/uci-defaults"
mkdir -p "$UCI_DEFAULTS_DIR"

cat > "$UCI_DEFAULTS_DIR/99-custom-network" << 'UCIEOF'
#!/bin/sh
/etc/init.d/force-lan enable 2>/dev/null
uci -q set network.lan.ipaddr='192.168.12.1'
uci -q set network.lan.netmask='255.255.255.0'
uci -q set network.lan.proto='static'
uci -q set network.lan.device='br-lan'
uci -q delete network.wan
uci -q delete network.wan6
uci -q commit network
uci -q set dhcp.lan.start='100'
uci -q set dhcp.lan.limit='150'
uci -q set dhcp.lan.leasetime='12h'
uci -q set dhcp.lan.ignore='0'
uci -q commit dhcp
exit 0
UCIEOF
chmod +x "$UCI_DEFAULTS_DIR/99-custom-network"

mkdir -p package/base-files/files/etc/init.d
cat > package/base-files/files/etc/init.d/force-lan << 'INITEOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    n=0
    while [ "$n" -lt 15 ]; do
        [ -d /sys/class/net/lan1 ] || [ -d /sys/class/net/wan ] && break
        sleep 1
        n=$((n+1))
    done

    PORTS=""
    for iface in lan1 lan2 wan eth0 eth1; do
        [ -d "/sys/class/net/$iface" ] || continue
        PORTS="$PORTS $iface"
    done
    PORTS=$(echo $PORTS)
    [ -n "$PORTS" ] || return 0

    uci -q delete network.wan
    uci -q delete network.wan6
    idx=0
    while uci -q delete network.@device[0]; do
        idx=$((idx+1))
        [ "$idx" -gt 12 ] && break
    done

    uci -q set network.lan=interface
    uci -q set network.lan.proto='static'
    uci -q set network.lan.device='br-lan'
    uci -q set network.lan.ipaddr='192.168.12.1'
    uci -q set network.lan.netmask='255.255.255.0'
    uci -q delete network.lan.ifname
    uci -q delete network.lan.type

    uci -q add network device
    uci -q set network.@device[-1].name='br-lan'
    uci -q set network.@device[-1].type='bridge'
    for p in $PORTS; do
        uci -q add_list network.@device[-1].ports="$p"
    done
    uci -q commit network

    uci -q set dhcp.lan=dhcp
    uci -q set dhcp.lan.interface='lan'
    uci -q set dhcp.lan.start='100'
    uci -q set dhcp.lan.limit='150'
    uci -q set dhcp.lan.leasetime='12h'
    uci -q set dhcp.lan.ignore='0'
    uci -q commit dhcp

    if command -v ubus >/dev/null 2>&1; then
        ubus call network reload >/dev/null 2>&1 || /etc/init.d/network reload >/dev/null 2>&1 || true
    fi
    sleep 1

    ip link add name br-lan type bridge 2>/dev/null || true
    for p in $PORTS; do
        ip link set "$p" up 2>/dev/null || true
        ip link set "$p" master br-lan 2>/dev/null || true
    done
    ip link set br-lan up 2>/dev/null || true
    ip addr add 192.168.12.1/24 dev br-lan 2>/dev/null || true
    ip addr add 192.168.100.1/24 dev br-lan 2>/dev/null || true

    /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd enable >/dev/null 2>&1 || true
    /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}
INITEOF
chmod +x package/base-files/files/etc/init.d/force-lan

mkdir -p package/base-files/files/etc/rc.d
ln -sf ../init.d/force-lan package/base-files/files/etc/rc.d/S99force-lan

mkdir -p package/base-files/files/etc/hotplug.d/net
cat > package/base-files/files/etc/hotplug.d/net/99-jdcloud-lan << 'HOTEOF'
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
case "$DEVICENAME" in
    lan1|lan2|wan|eth0|eth1|br-lan) ;;
    *) exit 0 ;;
esac
ip link add name br-lan type bridge 2>/dev/null
ip link set "$DEVICENAME" up 2>/dev/null
[ "$DEVICENAME" = "br-lan" ] || ip link set "$DEVICENAME" master br-lan 2>/dev/null
ip link set br-lan up 2>/dev/null
ip addr add 192.168.12.1/24 dev br-lan 2>/dev/null
ip addr add 192.168.100.1/24 dev br-lan 2>/dev/null
HOTEOF
chmod +x package/base-files/files/etc/hotplug.d/net/99-jdcloud-lan

echo "已添加开机强制 LAN：rc.d 启用 + hotplug 兜底，IP 192.168.12.1 / 192.168.100.1"

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
