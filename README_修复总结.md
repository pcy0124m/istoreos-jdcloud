# RE-SP-01B 固件网络配置修复总结

## 任务目标

修复 iStoreOS RE-SP-01B 固件的网络配置问题，解决用户无法访问 LuCI 管理后台和"网络未连接"的问题。

## 问题分析

### 问题历程

1. **第一次尝试** (Run ID: 33224981768)
   - 症状: `ERR_CONNECTION_REFUSED`
   - 根因: 缺少 uhttpd HTTP 服务器
   - 解决: 添加 `CONFIG_PACKAGE_uhttpd=y`

2. **第二次尝试** (Run ID: 33243300236)
   - 症状: `502 Bad Gateway`
   - 根因: uhttpd 配置不完整
   - 解决: 添加 UCI 默认配置脚本

3. **第三次尝试** (当前修复)
   - 症状: "网络未连接"、"设备未找到"、绿灯常亮
   - 根因: DTS 文件网络接口定义不完整
   - 解决: 完善以太网接口和 PCIE WiFi 配置

## 已完成的修复

### 1. DTS 文件更新

**文件**: `target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts`

**主要变更**:
```diff
+ aliases {
+     ethernet0 = &gmac0;
+     ethernet1 = &gmac1;
+     wlan0 = &pcie0_wifi0;
+     wlan1 = &pcie1_wifi0;
+ };

+ &gmac0 {
+     status = "okay";
+     label = "lan0";
+ };

  &gmac1 {
      status = "okay";
      label = "wan";
  };

+ &switch0 {
+     status = "okay";
+ };

  &pcie0 {
      wifi@0,0 {
          compatible = "mediatek,mt76";
          reg = <0x0000 0 0 0 0>;
          nvmem-cells = <&eeprom_factory_0>;
          nvmem-cell-names = "eeprom";
+         mediatek,mtd-eeprom = <&eeprom_factory_0>;
      };
  };

  &pcie1 {
      wifi@0,0 {
          compatible = "mediatek,mt76";
          reg = <0x0000 0 0 0 0>;
          nvmem-cells = <&eeprom_factory_8000>;
          nvmem-cell-names = "eeprom";
+         mediatek,mtd-eeprom = <&eeprom_factory_8000>;
          ieee80211-freq-limit = <5000000 6000000>;
      };
  };
```

### 2. 设备定义更新

**文件**: `target/linux/ramips/image/mt7621.mk`

**主要变更**:
```diff
  define Device/jdcloud_re-sp-01b
    $(Device/dsa-migration)
    IMAGE_SIZE := 27328k
    DEVICE_VENDOR := JDCloud
    DEVICE_MODEL := RE-SP-01B
    DEVICE_PACKAGES := kmod-mt7603 kmod-mt7615-firmware \
      kmod-mmc-mtk kmod-usb3
+   NETWORKING := wan:lan
+   LAN_PORTS := 0 1
+   WAN_PORT := 5
  endef
```

### 3. 配置文件更新

**文件**: `config/jdcloud-re-sp-01b.config`

**主要变更**:
- 确保 `CONFIG_PACKAGE_luci-proto-ppp=y`
- 确保 `CONFIG_PACKAGE_luci-proto-ipv6=y`
- 保留 uhttpd 和 LuCI 核心模块

### 4. 网络配置脚本

**文件**: `depends/diy-part1.sh`

已包含 uhttpd 的完整 UCI 配置脚本，确保首次启动时正确配置 HTTP 服务器。

## 提交记录

| Commit | 说明 | 时间 |
|--------|------|------|
| `f54ea6c` | 添加固件修复说明文档 | 2026-08-29 |
| `93d2b47` | 修复 RE-SP-01B 固件网络配置问题 | 2026-08-29 |
| `020d93f` | fix: add uhttpd config to uci-defaults script | 2026-08-29 |
| `accd77b` | fix: add luci-app-uhttpd for proper uhttpd configuration | 2026-08-29 |

## GitHub Actions 状态

**仓库**: https://github.com/pcy0124m/istoreos-jdcloud

工作流配置：
- 触发方式: 手动触发 + 定时任务（每天 UTC 18:00）
- 源码分支: `istoreos-24.10`
- 目标平台: `ramips/mt7621`
- 目标设备: `jdcloud_re-sp-01b`

最近运行记录：
- Run #20: 手动触发（43m 22s）
- Run #19: 手动触发（1h 3m 53s）
- Run #18: 手动触发（43m 45s）
- Run #16: 手动触发（38m 35s）

## 下一步操作

### 1. 等待编译完成

新固件正在 GitHub Actions 中编译，预计需要 40-60 分钟。

### 2. 下载固件

编译完成后，从 Actions Artifacts 下载：
- `istoreos-ramips-mt7621-jdcloud_re-sp-01b-initramfs-kernel.bin` (用于测试)
- `istoreos-ramips-mt7621-jdcloud_re-sp-01b-squashfs-sysupgrade.bin` (用于永久刷入)

### 3. 测试步骤

1. **使用 Breed 刷入 initramfs-kernel.bin 进行测试**
   - 进入 Breed 恢复模式
   - 上传 initramfs 固件
   - 测试网络是否正常

2. **访问 LuCI 管理界面**
   - 电脑设置静态 IP: `192.168.12.100`
   - 访问: `http://192.168.12.1/cgi-bin/luci/`

3. **确认网络端口识别**
   - 检查 LuCI 中的"网络" → "接口"
   - 确认 LAN 和 WAN 端口正确识别

4. **刷入 sysupgrade.bin 永久使用**
   - 通过 LuCI 上传 sysupgrade 固件
   - 勾选"保留配置"（可选）

## 预期结果

新固件应该能够：
1. ✅ 正常启动，绿灯闪烁
2. ✅ 正确识别网络端口（LAN1, LAN2, WAN）
3. ✅ 可以访问 LuCI 管理界面
4. ✅ WiFi 正常工作（2.4GHz 和 5GHz）
5. ✅ DHCP 服务正常运行
6. ✅ 防火墙和网络设置可用

## 相关文件位置

```
S:\AI智能体\teleagent\istoreos-jdcloud\istoreos-jdcloud-re-sp-01b\
├── config\
│   └── jdcloud-re-sp-01b.config          ← 已更新
├── depends\
│   ├── diy-part1.sh                      ← 已更新（uhttpd 配置）
│   └── diy-part2.sh                      ← 已更新（DTS 和网络配置）
├── .github\workflows\
│   └── build-istoreos.yml                ← 编译工作流
├── README_固件修复说明.md                ← 详细修复说明
└── firmware-output\                      ← 固件输出目录
```

## 注意事项

1. **首次启动可能需要 2-3 分钟**：系统会执行 uci-defaults 脚本进行首次配置
2. **如果无法访问**：尝试重置路由器（长按 Reset 10 秒）
3. **MAC 地址**：从 config 分区的 `mac` 字段读取，确保与标签一致
4. **固件大小**：sysupgrade 固件约 9.75MB，在 27328kB 限制内

## 参考资料

- OpenWrt 官方 PR #17409: https://github.com/openwrt/openwrt/pull/17409
- MT7621 网络设备配置: https://openwrt.org/docs/guide-user/network/ethernet
- iStoreOS 项目: https://github.com/istoreos/istoreos
