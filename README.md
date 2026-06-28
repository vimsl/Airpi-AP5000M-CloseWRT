# CloseWRT-CI
云编译 Airpi H5000M CloseWRT 固件 | 5G 优化 + 硬件加速 + AI QoS 整合版

PADAVANONLY-24.10源码：
https://github.com/padavanonly/immortalwrt-mt798x-6.6

# 特性

- **5G 优化**: qmi_fix_skb 内核模块 (kprobe 热修复 skb tailroom) + 5G 信号看板
- **硬件加速**: HNAT DTS 自动适配 (usb0 白名单 + wwan 前缀)
- **AI QoS**: CAKE qdisc + cake-autorate + SINR 信号注入 + 条件检测
- **编译鲁棒性**: 自动清理无保护的 HNAT 内核补丁 + defconfig 设备符号恢复

# 注意：

本项目仅支持编译带有defconfig目录的MTK SDK闭源项目。

# 固件简要说明：

固件每天早上4点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

MEDIATEK系列，配套的UBOOT：
https://github.com/VIKINGYFY/UBOOT-CI/releases

# 目录简要说明：

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置

#
[![Stargazers over time](https://starchart.cc/VIKINGYFY/CloseWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/CloseWRT-CI)

<!-- ci-trigger: kmod-sched-cake + cake-autorate + hnat-robustness + defconfig-recovery -->
