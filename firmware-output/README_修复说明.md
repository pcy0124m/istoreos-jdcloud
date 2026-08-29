---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '965359e9-3e06-42c7-8bd3-34644a725b8f'
  PropagateID: '965359e9-3e06-42c7-8bd3-34644a725b8f'
  ReservedCode1: 'a6f3fd03-dd82-48ab-9b3a-bd6c1395428a'
  ReservedCode2: 'a6f3fd03-dd82-48ab-9b3a-bd6c1395428a'
---

# iStoreOS RE-SP-01B 固件 - 修复 502 Bad Gateway

## 问题描述
访问 `http://192.168.12.1/cgi-bin/luci/` 时显示 502 Bad Gateway 错误

## 已应用的修复

### 1. 添加 uhttpd 管理包
- 在配置文件 `config/jdcloud-re-sp-01b.config` 中添加：
  ```
  CONFIG_PACKAGE_luci-app-uhttpd=y
  ```

### 2. 添加 uhttpd UCI 默认配置
- 修改 `depends/diy-part1.sh`，在首次启动时自动配置 uhttpd：
  ```sh
  # 配置 uhttpd HTTP 服务器
  uci set uhttpd.main.index_page='/www/index.html'
  uci set uhttpd.main.home='/www'
  uci set uhttpd.main.cgi_timeout='30'
  uci set uhttpd.main.lua_prefix='/luci'
  uci set uhttpd.main.lua_handler='/luci Dispatcher'
  uci add_list uhttpd.main.cgi_bridge='/cgi-bin'
  uci set uhttpd.main.redirect_https='0'
  uci set uhttpd.main.list_http='0.0.0.0:80'
  uci set uhttpd.main.list_https='0.0.0.0:443'
  uci set uhttpd.main.script_aliases='/cgi-bin/luci=/usr/bin/luci-redirect'
  uci commit uhttpd
  
  # 启用 uhttpd 服务
  /etc/init.d/uhttpd enable
  ```

## 新固件信息

| 文件 | 大小 |
|------|------|
| initramfs-kernel.bin | 9.37 MB |
| squashfs-sysupgrade.bin | 9.75 MB |

**编译时间**: 2026-08-29 15:07:37  
**GitHub Actions Run**: https://github.com/pcy0124m/istoreos-jdcloud/actions/runs/33243300236

## 刷入步骤

### 方法一：通过 Breed 刷入（推荐）

1. **进入 Breed 恢复模式**
   - 路由器断电
   - 按住 Reset 按钮不放
   - 通电，继续按住 5 秒
   - PC 设置静态 IP: `192.168.1.2`
   - 访问 `http://192.168.1.1`

2. **先刷 initramfs 测试**
   - 上传 `initramfs-kernel.bin`
   - 等待启动完成
   - 访问 `http://192.168.12.1/cgi-bin/luci/` 测试

3. **确认正常后刷 sysupgrade**
   - 通过 LuCI 上传 `sysupgrade.bin`
   - 或再次进入 Breed 刷入 `sysupgrade.bin`

### 方法二：通过 LuCI 网页刷入

1. 如果能进入旧版 LuCI
2. 系统 → 备份/升级 → 上传 `sysupgrade.bin`

## 测试步骤

刷入后：
1. 等待 3-5 分钟让 LuCI 初始化
2. 浏览器访问 `http://192.168.12.1/`
3. 如仍显示 502，执行：
   ```bash
   # SSH 登录路由器（密码为空或您设置的密码）
   /etc/init.d/uhttpd restart
   logread | grep uhttpd
   ```

## 网络配置

- 路由器 LAN IP: `192.168.12.1`
- 电脑 IP: `192.168.12.x` (x 为 2-254)
- 子网掩码: `255.255.255.0`

> AI生成