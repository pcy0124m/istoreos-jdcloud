#!/bin/bash
#================================================================
# DIY Part 1 - 在 feeds 更新后执行
# 用于添加 Argon 主题源、自定义软件源、默认设置
#================================================================
set -e

echo "===== DIY Part 1 开始 ====="

# ===== 添加 Argon 主题软件源 =====
# Argon 主题来自社区源，需要添加 feed
echo "添加 Argon 主题软件源..."

# 方法1: 从 kenzok8 仓库获取 Argon 主题 (社区常用源)
if ! grep -q "kenzok8" feeds.conf.default 2>/dev/null; then
    echo "src-git kenzok8 https://github.com/kenzok8/small-package.git" >> feeds.conf.default
    echo "已添加 kenzok8 软件源"
fi

# 方法2: 如果 kenzok8 不可用，直接从 Argon 官方仓库获取
# jerrykuku/luci-theme-argon 是 Argon 主题的官方仓库
if ! grep -q "argon" feeds.conf.default 2>/dev/null; then
    echo "src-git argon_theme https://github.com/jerrykuku/luci-theme-argon.git" >> feeds.conf.default
    echo "src-git argon_config https://github.com/jerrykuku/luci-app-argon-config.git" >> feeds.conf.default
    echo "已添加 Argon 主题官方源"
fi

# 确保 iStore feed 存在
if [ -d "feeds/istore" ]; then
    echo "iStore feed 已存在"
else
    echo "提示: iStore feed 不存在，可能需要检查源码分支"
fi

# ===== 修改默认设置 =====

# 设置默认时区为东八区
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate 2>/dev/null || true

# 修改默认主机名
sed -i 's/OpenWrt/iStoreOS/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# ===== 添加 UCI 默认配置脚本 =====
# 首次启动时自动设置: Argon 主题、时区、主机名、密码、uhttpd 配置
cat > package/base-files/files/etc/uci-defaults/99-jdcloud-defaults << 'UCEOF'
#!/bin/sh

# ===== 设置默认主题为 Argon =====
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# ===== 时区 =====
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system

# ===== 主机名 =====
uci set system.@system[0].hostname='iStoreOS'
uci commit system

# ===== 配置 uhttpd HTTP 服务器 =====
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

# ===== 启用 uhttpd 服务 =====
/etc/init.d/uhttpd enable 2>/dev/null || true

exit 0
UCEOF
chmod +x package/base-files/files/etc/uci-defaults/99-jdcloud-defaults 2>/dev/null || true

# ===== 移除不需要的主题以节省空间 =====
# 移除 iStoreOS 默认主题 (用 Argon 替代)
echo "移除 iStoreOS 默认主题以节省空间..."
rm -rf package/luci/themes/luci-theme-istoreui 2>/dev/null || true
rm -rf package/luci/themes/luci-theme-istoreui-dark 2>/dev/null || true

# 移除其他不必要的主题
# Bootstrap 主题是 LuCI 自带的，保留作为 fallback

# ===== 精简: 移除不必要的默认包 =====
echo "精简系统组件..."

# 移除不必要的 LuCI app 以节省空间
# 这些包如果在源码中存在但未在 .config 中选中，不会影响编译
# 但如果 iStoreOS 默认通过 Makefile 强制依赖，可能需要处理

echo "===== DIY Part 1 完成 ====="
