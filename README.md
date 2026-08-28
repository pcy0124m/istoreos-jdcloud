---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '526a0776-3c8b-4328-95be-c2e860b94132'
  PropagateID: '526a0776-3c8b-4328-95be-c2e860b94132'
  ReservedCode1: 'a5fa34e0-9703-48bd-829a-b19a92a6c78a'
  ReservedCode2: 'a5fa34e0-9703-48bd-829a-b19a92a6c78a'
---

# iStoreOS 固件 - 京东云 RE-SP-01B (MT7621) 云编译

基于 [iStoreOS](https://github.com/istoreos/istoreos) 官方源码（istoreos-24.10 分支），使用 GitHub Actions 云编译，专为 **京东云无线宝第一代 RE-SP-01B** 定制。

**主题：Argon** | **精简版固件 < 22MB**

## 设备硬件信息

| 项目 | 参数 |
|------|------|
| 设备型号 | JDCloud RE-SP-01B |
| SoC | MediaTek MT7621AT (双核 880MHz) |
| 内存 | 512MB DDR3 |
| 闪存 | 32MB SPI NOR Flash |
| 2.4GHz WiFi | MediaTek MT7603EN |
| 5GHz WiFi | MediaTek MT7615N |
| 网口 | 3 x 千兆 |
| USB | 1 x USB 2.0 |
| 目标平台 | ramips / mt7621 |
| 设备 ID | jdcloud,re-sp-01-b |

## 固件特点

- **Argon 主题**：内置 Argon 主题及设置页面，支持自定义配色、背景、明暗模式
- **精简系统**：移除大量非必要组件，固件体积控制在 22MB 以内
- **保留核心功能**：iStore 软件中心、快速向导、Samba 文件共享、磁盘管理、USB 存储支持
- **网络加速**：硬件 NAT 加速、TurboAcc 网络加速
- **WiFi 完整**：MT7603 (2.4G) + MT7615 (5G) 驱动完整，支持 WPA3

### 精简详情

| 组件 | 状态 | 说明 |
|------|------|------|
| Argon 主题 | 包含 | 替代默认主题 |
| iStore 软件中心 | 包含 | 可在线安装插件 |
| Samba4 文件共享 | 包含 | NAS 基础 |
| 磁盘管理 | 包含 | USB/eMMC 挂载 |
| TurboAcc 加速 | 包含 | 硬件 NAT |
| WPA3 (wolfssl) | 包含 | WiFi 安全 |
| IPv6 | 包含 | 完整支持 |
| ~~netdata 监控~~ | 移除 | 节省 ~2MB |
| ~~collectd 统计~~ | 移除 | 节省 ~1.5MB |
| ~~homebox 测速~~ | 移除 | 节省空间 |
| ~~ddnsto 穿透~~ | 移除 | 节省空间 |
| ~~bash/curl/wget~~ | 移除 | 用默认 sh |
| ~~cron 定时~~ | 移除 | 节省空间 |
| ~~iStoreOS 默认主题~~ | 移除 | 用 Argon 替代 |

## 使用方法

### 1. Fork 本仓库

点击页面右上角的 **Fork** 按钮，将本仓库 Fork 到你的 GitHub 账号下。

### 2. 启用 GitHub Actions

进入你 Fork 后的仓库页面，点击 **Actions** 标签页，如果提示需要启用，点击 **I understand my workflows, go ahead and enable them**。

### 3. 触发编译

有两种触发方式：

- **手动触发**：进入 Actions 页面 -> 选择 **Build iStoreOS for JDCloud RE-SP-01B** -> 点击 **Run workflow** -> 选择分支 main -> 点击绿色 **Run workflow** 按钮
- **定时触发**：北京时间每天凌晨 2:00 自动执行

### 4. 下载固件

编译完成后（通常需要 1.5~3 小时）：
- 进入 Actions 页面，找到最近一次成功的运行
- 在运行详情页底部的 **Artifacts** 区域下载固件包
- 解压后获得 `sysupgrade.bin` 格式的固件文件
- 编译日志中会显示固件体积检查结果

### 5. 刷入设备

**通过 Breed 恢复控制台刷入（推荐）**

1. 断电，用牙签按住 Reset 键不放，接通电源
2. 等待指示灯蓝色闪烁后松开
3. 电脑设置 IP 为 `192.168.1.2/24`，浏览器访问 `192.168.1.1`
4. 在"固件更新"中选择下载的 `sysupgrade.bin`
5. 取消勾选"自动重启"和"EEPROM"，点击上传并刷入

## 默认配置

| 项目 | 值 |
|------|------|
| 管理后台 | http://192.168.100.1 或 http://iStoreOS.lan |
| 用户名 | root |
| 密码 | password |
| 主题 | Argon |
| WAN 口 | 第一个网口 |
| LAN 口 | 其余网口 |

## 自定义修改

- **修改插件列表**：编辑 `config/jdcloud-re-sp-01b.config`
- **修改 DIY 脚本**：编辑 `depends/diy-part1.sh` 和 `depends/diy-part2.sh`
- **修改默认主题/设置**：编辑 `depends/diy-part1.sh` 中的 UCI defaults 部分
- **修改编译参数**：编辑 `.github/workflows/build-istoreos.yml`

## 重要说明

1. **SPI NOR Flash 版本**：本固件适用于 32MB SPI NOR Flash 版本的 RE-SP-01B。64GB eMMC 版本刷入后需手动挂载 eMMC 分区。
2. **固件体积控制**：已精简到 22MB 以内。如果编译后发现超限，请进一步移除 `config/jdcloud-re-sp-01b.config` 中的软件包。
3. **Argon 主题源**：从 `jerrykuku/luci-theme-argon` 官方仓库和 `kenzok8/small-package` 社区源获取。
4. **刷机有风险**，请务必先备份原厂固件和 EEPROM 数据。

## 鸣谢

- [iStoreOS](https://github.com/istoreos/istoreos) - 易有云团队开发的路由+NAS系统
- [OpenWrt](https://github.com/openwrt/openwrt) - 开源路由器操作系统
- [Argon 主题](https://github.com/jerrykuku/luci-theme-argon) - 由 jerrykuku 开发的 LuCI 主题
- [draco-china/istoreos-actions](https://github.com/draco-china/istoreos-actions) - Actions 云编译框架参考

> AI生成