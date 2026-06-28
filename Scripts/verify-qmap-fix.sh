#!/bin/sh
# 验证关闭QMAP聚合模式是否解决skb_tailroom问题
# 在路由器TTYD上执行此脚本

echo "=== 5G断流Bug验证脚本 ==="
echo ""

# 1. 检查当前QMAP模式
echo "1. 当前QMAP模式:"
cat /sys/module/qmi_wwan_f/parameters/qmap_mode 2>/dev/null || echo "qmi_wwan_f模块未加载"
echo ""

# 2. 关闭QMAP聚合模式
echo "2. 关闭QMAP聚合模式..."
echo 0 > /sys/module/qmi_wwan_f/parameters/qmap_mode 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   成功: QMAP已关闭"
else
    echo "   失败: 无法修改QMAP模式（可能需要root权限）"
fi
echo ""

# 3. 清空内核日志
echo "3. 清空内核日志..."
dmesg -c > /dev/null 2>&1
echo "   已清空"
echo ""

# 4. 显示当前状态
echo "4. 当前网络接口状态:"
ifconfig wwan0 2>/dev/null | head -5 || echo "wwan0接口不存在"
echo ""

echo "=== 验证完成 ==="
echo "请等待5-10分钟，然后执行以下命令检查结果:"
echo "  dmesg | grep tailroom"
echo ""
echo "如果输出为空，说明QMAP关闭有效，skb_tailroom问题已解决"
echo "如果仍有输出，说明问题来自其他路径"
