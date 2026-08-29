---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '5a25c3bf-04b6-42b1-8dc9-169e2071bb0a'
  PropagateID: '5a25c3bf-04b6-42b1-8dc9-169e2071bb0a'
  ReservedCode1: '826d5b19-9d59-4b83-936e-e63681fdeedb'
  ReservedCode2: '826d5b19-9d59-4b83-936e-e63681fdeedb'
---

# RE-SP-01B 固件网络配置修复说明

## 问题描述

用户反馈刷入固件后出现以下问题：
1. 网页显示"网络未连接"、"设备未找到"
2. 路由器绿灯常亮
3. 无法访问 LuCI 管理后台 (`192.168.12.1/cgi-bin/luci/`)

## 问题分析

### 第一次尝试（固件 9.69MB）
- **症状**: `ERR_CONNECTION_REFUSED`（无 HTTP 服务器）
- **根因**: 固件缺少 uhttpd 和 LuCI 管理模块
- **修复**: 添加 `CONFIG_PACKAGE_uhttpd=y` 和 `CONFIG_PACKAGE_luci-mod-admin-full=y`

### 第二次尝试（固件 9.75MB）
- **症状**: `502 Bad Gateway`（uhttpd 运行但 CGI 失败）
- **根因**: uhttpd 配置不正确，缺少 UCI 默认配置
- **修复**: 添加 uhttpd 的 UCI 配置脚本

### 第三次尝试（当前固件）
- **症状**: 刷机后显示"网络未连接"、"设备未找到"、绿灯常亮
- **根因**: DTS 文件配置不完整，缺少以太网接口定义
- **修复**: 
  1. 添加 `&gmac0` 和 `&gmac1` 节点定义
  2. 添加 PCIE WiFi 节点别名
  3. 完善网络设备配置

## 本次修复内容

### 1. DTS 文件更新 (`mt7621_jdcloud_re-sp-01b.dts`)

```dts
// 添加以太网接口别名
aliases {
    ethernet0 = &gmac0;
    ethernet1 = &gmac1;
    wlan0 = &pcie0_wifi0;
    wlan1 = &pcie1_wifi0;
};

// 添加 gmac0（LAN 口）
&gmac0 {
    status = "okay";
    label = "lan0";
};

// 添加 gmac1（WAN 口）
&gmac1 {
    status = "okay";
    label = "wan";
};

// 启用 switch
&switch0 {
    status = "okay";
};

// 添加 PCIE WiFi 节点
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
```

### 2. 设备定义更新 (`mt7621.mk`)

```makefile
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
```

### 3. 配置文件更新 (`jdcloud-re-sp-01b.config`)

添加了必要的网络相关包：
- `CONFIG_PACKAGE_luci-proto-ppp=y`
- `CONFIG_PACKAGE_luci-proto-ipv6=y`

## 编译状态

- **最新提交**: `93d2b47`
- **分支**: `main`
- **GitHub Actions**: 自动触发编译

## 测试步骤

### 方法一：通过 Breed 刷入（推荐）

1. 进入 Breed 恢复模式
   - 断电状态下按住 Reset 按钮
   - 接通电源，等待 5 秒后松开
   - 电脑设置静态 IP: `192.168.1.2`
   - 访问 `http://192.168.1.1`

2. 先刷 initramfs-kernel.bin 测试
   - 使用 Breed 的"常规固件"选项
   - 选择 `istoreos-ramips-mt7621-jdcloud_re-sp-01b-initramfs-kernel.bin`
   - 不勾选"保存当前配置"
   - 刷入后路由器会自动重启

3. 测试网络是否正常
   - 电脑设置静态 IP: `192.168.12.100`
   - 网关: `192.168.12.1`
   - 尝试访问 `http://192.168.12.1/cgi-bin/luci/`

4. 如果测试成功，再刷 sysupgrade.bin
   - 通过 LuCI 的"备份/升级"页面上传固件
   - 勾选"保留配置"（可选）

### 方法二：通过 LuCI 升级

1. 登录当前 LuCI 界面
2. 进入"系统" → "备份/升级"
3. 上传 `istoreos-ramips-mt7621-jdcloud_re-sp-01b-squashfs-sysupgrade.bin`
4. 等待固件刷入并重启

## 预期结果

刷入新固件后：
1. 路由器正常启动，绿灯闪烁
2. 网络端口正确识别（LAN1, LAN2, WAN）
3. 可以访问 `http://192.168.12.1/cgi-bin/luci/`
4. 首次登录时设置 root 密码
5. WiFi 正常工作（2.4GHz 和 5GHz）

## 故障排查

### 问题：仍然无法访问 LuCI

1. 检查电脑 IP 设置是否正确
2. 尝试使用 `ping 192.168.12.1` 测试连通性
3. 查看路由器指示灯状态
4. 尝试重置路由器（长按 Reset 10 秒）

### 问题：网络端口不识别

1. 检查 DTS 文件中的端口配置
2. 查看系统日志：`logread | grep switch`
3. 确认 MAC 地址是否正确读取

## 相关文件

- DTS 文件: `target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts`
- 设备定义: `target/linux/ramips/image/mt7621.mk`
- 网络配置: `target/linux/ramips/mt7621/base-files/etc/board.d/02_network`
- WiFi MAC 修复: `target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac`

## 参考资料

- OpenWrt 官方 PR #17409: https://github.com/openwrt/openwrt/pull/17409
- MT7621 网络配置指南: https://openwrt.org/docs/guide-user/network/ethernet

> AI生成