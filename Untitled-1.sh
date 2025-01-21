#!/bin/bash

# 交互式输入编译相关信息
read -p "请输入后台管理IP (默认: 192.168.6.1): " BACKEND_IP
BACKEND_IP=${BACKEND_IP:-192.168.6.1}

read -p "请输入主题 (默认: argon): " THEME
THEME=${THEME:-argon}

read -p "请输入内核版本 (默认: 6.6): " KERNEL_VERSION
KERNEL_VERSION=${KERNEL_VERSION:-6.6}

read -p "请输入系统分区大小 (默认: 2048M): " PARTITION_SIZE
PARTITION_SIZE=${PARTITION_SIZE:-2048M}

read -p "请输入编译作者信息 (默认: 04543473): " AUTHOR
AUTHOR=${AUTHOR:-04543473}

# 设置变量
OPENWRT_DIR="openwrt"
SIGNATURE="Custom Build $(TZ=UTC-8 date "+%Y.%m.%d") by $AUTHOR"
PASSWORD=""

# 更新和安装依赖
sudo apt-get update
sudo apt-get install -y build-essential git-core libncurses5-dev zlib1g-dev gawk flex quilt libssl-dev xsltproc libxml-parser-perl mercurial bzr ecj cvs unzip python3 python3-pip wget

# 克隆OpenWrt源码
git clone https://git.openwrt.org/openwrt/openwrt.git $OPENWRT_DIR
cd $OPENWRT_DIR

# 更新源码
./scripts/feeds update -a
./scripts/feeds install -a

# 修改后台IP地址
sed -i "s/option ipaddr '192.168.1.1'/option ipaddr '$BACKEND_IP'/" package/base-files/files/bin/config_generate

# 修改主题
sed -i "s/luci-theme-bootstrap/luci-theme-$THEME/" feeds/luci/collections/luci/Makefile

# 修改内核版本
sed -i "s/LINUX_VERSION:=.*/LINUX_VERSION:=$KERNEL_VERSION/" target/linux/x86/Makefile

# 修改系统分区大小
sed -i "s/option target '16M'/option target '$PARTITION_SIZE'/" target/linux/x86/image/Makefile

# 增加个性签名
echo "echo '$SIGNATURE' > /etc/openwrt_release" >> package/base-files/files/etc/rc.local

# 增加AdGuardHome插件和核心
git clone https://github.com/kongfl888/luci-app-adguardhome.git package/luci-app-adguardhome

# 增加OpenClash时,把核心下载好
git clone https://github.com/vernesong/OpenClash.git package/OpenClash

# 添加自定义软件源和个别软件
echo "src-git cdny https://github.com/cdny123/openwrt-package1.git" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a
for software in $CUSTOM_SOFTWARE; do
    echo "CONFIG_PACKAGE_$software=y" >> .config
done

# 添加CPU使用率、实时内存使用情况
echo "CONFIG_PACKAGE_luci-app-statistics=y" >> .config
echo "CONFIG_PACKAGE_collectd=y" >> .config
echo "CONFIG_PACKAGE_collectd-mod-cpu=y" >> .config
echo "CONFIG_PACKAGE_collectd-mod-memory=y" >> .config

# 自定义x86.config文件
cp x86.config .config

# 配置编译选项
make defconfig

# 删除不需要的固件或文件
for file in "${EXCLUDE_FILES[@]}"; do
    make target/linux/x86/image/clean
    make package/$file/clean
done

# 设置后台登录密码为空
sed -i 's/option password .*/option password ""/' package/base-files/files/etc/config/system

# 编译固件
make -j$(nproc)

# 清理不必要的文件
make dirclean

# 清理不需要的文件
for file in "${EXCLUDE_FILES[@]}"; do
    rm -rf bin/targets/x86/64/$file*
done

echo "固件编译完成，位于 bin/targets/x86/64/ 目录下"
