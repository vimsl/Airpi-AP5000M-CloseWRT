#!/bin/bash
# 修复HNAT绑定wwan接口导致skb_tailroom冲突
# 移除DTS中hnat节点的ext-devices-prefix属性

WRT_DIR="${WRT_DIR:-./wrt}"
HNAT_DTS=$(find "$WRT_DIR/target/linux/mediatek" -name "*.dts" -o -name "*.dtsi" | head -20)

echo "=== Patching HNAT DTS to remove wwan binding ==="

for dts_file in $HNAT_DTS; do
    if grep -q "ext-devices-prefix" "$dts_file" 2>/dev/null; then
        echo "Found ext-devices-prefix in: $dts_file"
        # 移除包含ext-devices-prefix的行
        sed -i '/ext-devices-prefix/d' "$dts_file"
        echo "Patched: removed ext-devices-prefix"
    fi
done

echo "=== HNAT DTS patch complete ==="
