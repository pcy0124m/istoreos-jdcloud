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

DTS_FILE="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01-b.dts"
if [ -f "$DTS_FILE" ]; then
    echo "找到 RE-SP-01B DTS 文件: $DTS_FILE"
else
    echo "警告: 未找到 $DTS_FILE"
    echo "该设备可能在当前 iStoreOS 分支中尚未同步"
fi

# 检查 mt7621.mk 中是否有该设备的定义
MK_FILE="target/linux/ramips/image/mt7621.mk"
if [ -f "$MK_FILE" ]; then
    if grep -q "re-sp-01" "$MK_FILE" || grep -q "jdcloud_re" "$MK_FILE"; then
        echo "在 mt7621.mk 中找到 RE-SP-01B 设备定义"
    else
        echo "警告: 在 $MK_FILE 中未找到 RE-SP-01B 设备定义"
    fi
fi

# 如果设备不存在，自动添加设备定义
if [ -f "$MK_FILE" ] && ! grep -q "jdcloud_re-sp-01b\|jdcloud_re_sp_01b\|re-sp-01-b" "$MK_FILE" 2>/dev/null; then
    echo "尝试添加 RE-SP-01B 设备定义到 mt7621.mk ..."

    if ! grep -q "jdcloud_re-sp-01b" "$MK_FILE" 2>/dev/null; then
        cat >> "$MK_FILE" << 'MKEOF'

# JDCloud RE-SP-01B (京东云无线宝第一代)
define Device/jdcloud_re-sp-01b
  $(Device/dsa-mt7621)
  DEVICE_VENDOR := JDCloud
  DEVICE_MODEL := RE-SP-01B
  DEVICE_PACKAGES := kmod-mt7603 kmod-mt7615e kmod-mt7615-firmware kmod-usb3 \
    kmod-usb2 kmod-usb-storage kmod-scsi-core block-mount
  SUPPORTED_DEVICES := jdcloud,re-sp-01-b
endef
TARGET_DEVICES += jdcloud_re-sp-01b

MKEOF
        echo "已添加 RE-SP-01B 设备定义到 mt7621.mk"
    fi
fi

# 确保 DTS 文件存在
if [ ! -f "$DTS_FILE" ] && [ -d "target/linux/ramips/dts" ]; then
    echo "创建 RE-SP-01B DTS 文件..."
    cat > "$DTS_FILE" << 'DTSEOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT

/dts-v1/;

#include "mt7621.dtsi"

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>

/ {
	compatible = "jdcloud,re-sp-01-b", "mediatek,mt7621-soc";
	model = "JDCloud RE-SP-01B";

	aliases {
		led-boot = &led_power;
		led-failsafe = &led_power;
		led-running = &led_power;
		led-upgrade = &led_power;
	};

	chosen {
		bootargs = "console=ttyS0,115200";
	};

	gpio-leds {
		compatible = "gpio-leds";

		led_power: power {
			label = "jdcloud:blue:power";
			gpios = <&gpio 15 GPIO_ACTIVE_LOW>;
		};

		sys {
			label = "jdcloud:blue:sys";
			gpios = <&gpio 14 GPIO_ACTIVE_LOW>;
		};

		internet {
			label = "jdcloud:blue:internet";
			gpios = <&gpio 13 GPIO_ACTIVE_LOW>;
		};
	};

	gpio-keys {
		compatible = "gpio-keys";

		reset {
			label = "reset";
			gpios = <&gpio 18 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_RESTART>;
		};
	};
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
				label = "u-boot-env";
				reg = <0x30000 0x10000>;
				read-only;
			};

			factory: partition@40000 {
				label = "factory";
				reg = <0x40000 0x10000>;
				read-only;
			};

			partition@50000 {
				compatible = "denx,uimage";
				label = "firmware";
				reg = <0x50000 0x1fb0000>;
			};
		};
	};
};

&pcie {
	status = "okay";
};

&pcie0 {
	wifi@0,0 {
		compatible = "mediatek,mt7615e";
		reg = <0x0000 0 0 0 0>;
		mediatek,mtd-eeprom = <&factory 0x5000>;
		ieee80211-freq-limit = <5000000 6000000>;
	};
};

&pcie1 {
	wifi@0,0 {
		compatible = "mediatek,mt7603e";
		reg = <0x0000 0 0 0 0>;
		mediatek,mtd-eeprom = <&factory 0x0000>;
	};
};

&gmac0 {
	nvmem-cells = <&macaddr_factory_e000>;
	nvmem-cell-names = "mac-address";
};

&switch0 {
	ports {
		port@0 {
			status = "disabled";
		};
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
			label = "wan";
		};
	};
};

&factory {
	compatible = "nvmem-cells";
	#address-cells = <1>;
	#size-cells = <1>;

	macaddr_factory_e000: macaddr@e000 {
		reg = <0xe000 0x6>;
	};
};
DTSEOF
        echo "已创建 RE-SP-01B DTS 文件"
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
fi

# ===== 显示最终配置摘要 =====
echo "===== 配置摘要 ====="
echo "目标平台: ramips/mt7621"
echo "目标设备: jdcloud_re-sp-01b (JDCloud RE-SP-01B)"
echo "源码分支: $ISTOREOS_BRANCH"
echo "主题: Argon"
echo "固件目标: < 22MB (精简版)"

echo "===== DIY Part 2 完成 ====="
