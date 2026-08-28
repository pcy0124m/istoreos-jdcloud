#!/bin/bash
#================================================================
# DIY Part 2 - 鍦?make defconfig 涔嬪墠鎵ц
# 鐢ㄤ簬纭繚璁惧鏀寔銆丄rgon 涓婚鍔犺浇銆佺簿绠€閰嶇疆
#================================================================
set -e

echo "===== DIY Part 2 寮€濮?====="

# ===== 纭 Argon 涓婚宸茶 feeds 鍔犺浇 =====
echo "妫€鏌?Argon 涓婚鏄惁宸插姞杞?.."

if [ -d "feeds/kenzok8/luci-theme-argon" ] || [ -d "feeds/argon_theme" ]; then
    echo "Argon 涓婚 feed 宸插姞杞?
else
    echo "璀﹀憡: Argon 涓婚 feed 鏈壘鍒帮紝灏濊瘯浠庢簮鐮佷腑鏌ユ壘..."
    find package/ -name "*argon*" -type d 2>/dev/null || true
    find feeds/ -name "*argon*" -type d 2>/dev/null || true

    # 濡傛灉 feed 鍔犺浇澶辫触锛屽皾璇曠洿鎺ュ厠闅?Argon 涓婚鍒?package 鐩綍
    if [ ! -d "package/luci/themes/luci-theme-argon" ]; then
        echo "鐩存帴鍏嬮殕 Argon 涓婚鍒?package 鐩綍..."
        git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git \
            package/luci/themes/luci-theme-argon 2>/dev/null || true
    fi
    if [ ! -d "package/luci/applications/luci-app-argon-config" ]; then
        echo "鐩存帴鍏嬮殕 Argon Config 鍒?package 鐩綍..."
        git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git \
            package/luci/applications/luci-app-argon-config 2>/dev/null || true
    fi
fi

# ===== 纭鐩爣璁惧鏄惁鍦ㄦ簮鐮佷腑瀛樺湪 =====
echo "妫€鏌?RE-SP-01B 璁惧鏀寔..."

DTS_FILE="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01-b.dts"
if [ -f "$DTS_FILE" ]; then
    echo "鎵惧埌 RE-SP-01B DTS 鏂囦欢: $DTS_FILE"
else
    echo "璀﹀憡: 鏈壘鍒?$DTS_FILE"
    echo "璇ヨ澶囧彲鑳藉湪褰撳墠 iStoreOS 鍒嗘敮涓皻鏈悓姝?
fi

# 妫€鏌?mt7621.mk 涓槸鍚︽湁璇ヨ澶囩殑瀹氫箟
MK_FILE="target/linux/ramips/image/mt7621.mk"
if [ -f "$MK_FILE" ]; then
    if grep -q "re-sp-01" "$MK_FILE" || grep -q "jdcloud_re" "$MK_FILE"; then
        echo "鍦?mt7621.mk 涓壘鍒?RE-SP-01B 璁惧瀹氫箟"
    else
        echo "璀﹀憡: 鍦?$MK_FILE 涓湭鎵惧埌 RE-SP-01B 璁惧瀹氫箟"
    fi
fi

# 濡傛灉璁惧涓嶅瓨鍦紝鑷姩娣诲姞璁惧瀹氫箟
if [ -f "$MK_FILE" ] && ! grep -q "jdcloud_re-sp-01b\|jdcloud_re_sp_01b\|re-sp-01-b" "$MK_FILE" 2>/dev/null; then
    echo "灏濊瘯娣诲姞 RE-SP-01B 璁惧瀹氫箟鍒?mt7621.mk ..."

    if ! grep -q "jdcloud_re-sp-01b" "$MK_FILE" 2>/dev/null; then
        cat >> "$MK_FILE" << 'MKEOF'

# JDCloud RE-SP-01B (浜笢浜戞棤绾垮疂绗竴浠?
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
        echo "宸叉坊鍔?RE-SP-01B 璁惧瀹氫箟鍒?mt7621.mk"
    fi
fi

# 纭繚 DTS 鏂囦欢瀛樺湪
if [ ! -f "$DTS_FILE" ] && [ -d "target/linux/ramips/dts" ]; then
    echo "鍒涘缓 RE-SP-01B DTS 鏂囦欢..."
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
        echo "宸插垱寤?RE-SP-01B DTS 鏂囦欢"
fi

# ===== 纭繚鍏抽敭閰嶇疆琚啓鍏?.config =====
echo "纭繚鍏抽敭閰嶇疆椤?.."
if [ -f .config ]; then
    # 纭繚鐩爣骞冲彴姝ｇ‘
    if ! grep -q "CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-sp-01b=y" .config; then
        echo "CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-sp-01b=y" >> .config
    fi
    # 纭繚 Argon 涓婚琚€変腑
    if ! grep -q "CONFIG_PACKAGE_luci-theme-argon=y" .config; then
        echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config
    fi
    # 纭繚 Argon Config 琚€変腑
    if ! grep -q "CONFIG_PACKAGE_luci-app-argon-config=y" .config; then
        echo "CONFIG_PACKAGE_luci-app-argon-config=y" >> .config
    fi
    # 纭繚涓嶉€?iStoreOS 榛樿涓婚
    sed -i '/CONFIG_PACKAGE_luci-theme-istoreui/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_luci-theme-istoreui-dark/d' .config 2>/dev/null || true
fi

# ===== 鏄剧ず鏈€缁堥厤缃憳瑕?=====
echo "===== 閰嶇疆鎽樿 ====="
echo "鐩爣骞冲彴: ramips/mt7621"
echo "鐩爣璁惧: jdcloud_re-sp-01b (JDCloud RE-SP-01B)"
echo "婧愮爜鍒嗘敮: $ISTOREOS_BRANCH"
echo "涓婚: Argon"
echo "鍥轰欢鐩爣: < 22MB (绮剧畝鐗?"

echo "===== DIY Part 2 瀹屾垚 ====="
