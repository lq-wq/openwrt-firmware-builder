#!/bin/bash

# 设置变量
OPENWRT_DIR="openwrt-NITT"
BACKEND_IP="192.168.6.1"
THEME="argon"
KERNEL_VERSION="6.6"
PARTITION_SIZE="128M"
SIGNATURE="04543473 Build $(TZ=UTC-8 date "+%Y.%m.%d")"
CUSTOM_SOFTWARE="vim htop"
EXCLUDE_FILES=("kmod-usb-storage" "luci-app-ddns")

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
echo "CONFIG_PACKAGE_$CUSTOM_SOFTWARE=y" >> .config

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

# 编译固件
make -j$(nproc)

# 清理不需要的文件
for file in "${EXCLUDE_FILES[@]}"; do
    rm -rf bin/targets/x86/64/$file*
done

echo "固件编译完成，位于 bin/targets/x86/64/ 目录下"
