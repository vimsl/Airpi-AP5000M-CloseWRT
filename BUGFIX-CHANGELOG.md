---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 565790b44d7aba67beaf6ed2a84b6dbf_ede22c8672c211f1986d525400d9a7a1
    ReservedCode1: vjzMjopqUmllmpQMnBImjUpGN37yRuXQ05m2rz1wYErR34SHAyckGQNAQ92XFDVcZnPJD9hHCMAk3xw6kWeax7JnXnVbYDAxTS4isogwAXIamaIBiDRnVM2I38o36Seyeqq0Ix7LBpMJHUDsMbtffZIPQmjCmtEJ3n0xlpew2wfJYzbvTcrbK294F/8=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 565790b44d7aba67beaf6ed2a84b6dbf_ede22c8672c211f1986d525400d9a7a1
    ReservedCode2: vjzMjopqUmllmpQMnBImjUpGN37yRuXQ05m2rz1wYErR34SHAyckGQNAQ92XFDVcZnPJD9hHCMAk3xw6kWeax7JnXnVbYDAxTS4isogwAXIamaIBiDRnVM2I38o36Seyeqq0Ix7LBpMJHUDsMbtffZIPQmjCmtEJ3n0xlpew2wfJYzbvTcrbK294F/8=
---

# Airpi-AP5000M-CloseWRT 已修复 Bug 清单

> 时间跨度：2026-06-27 ~ 2026-06-28
> 目标：确保下个固件版本不重现

---

## 1. HNAT 补丁依赖链断裂导致 CI 编译失败

**发现时间**：2026-06-28
**影响范围**：H5000M 全量编译 (CWRT-ALL / WRT-CORE)
**严重程度**：高（编译阻断）

### 根因

padavanonly 仓库下发的 4 个无保护 HNAT 补丁存在依赖链，仅删除其中 2 个会导致其余补丁因上下文缺失而 quilt apply 失败：

| 补丁 | 问题 |
|------|------|
| `9996-ext-hnat.patch` | 定义 `sent_ppd` 变量，缺少 `#ifdef CONFIG_NET_MEDIATEK_HNAT` 保护 |
| `9998-dsa.patch` | 依赖 9996 定义的 `sent_ppd`，修改其逻辑并引入 `ppd_dev` |
| `9999-reset.patch` | 直接操作 HNAT 符号，缺少保护 |
| `99999-hnat-extdevice-fix-fdberr.patch` | 依赖 9998 引入的 `if(sent_ppd && ppd_dev){}` 代码块 |

**依赖链**：`9996(sent_ppd) → 9998(ppd_dev) → 99999(skb标记)`

### 修复方案 (cd2fde0 / 97ce2bd)

1. Clone 后删除全部 4 个无保护 HNAT 补丁（`target/linux/mediatek/patches-6.6/`）
2. 从 9998-dsa.patch 后半部分提取 FM170 TDTECH USB ID 段为独立补丁 `Scripts/9998-tdtech-usb.patch`，在清理后注入
3. 999-2745 已有条件编译保护，保留不动

### 验证方式
- 已通过 GitHub API 手动触发 CI 编译 (run #28314529694)
- CloseWRT 配置本身 `hnat_disable=1` 且 `# CONFIG_PACKAGE_kmod-mediatek_hnat is not set`，不会启用 HNAT

---

## 2. SINR 显示垃圾值（1782630566 dB）

**发现时间**：2026-06-28
**影响范围**：LuCI "5G AI 信号优化" 面板
**严重程度**：中（UI 异常，非功能阻断）

### 根因

`luci-app-aiqos/src/sinr_injector.sh` 的 `get_sinr_qmodem()` 函数对 `qmodem signal` 返回数据没有任何范围校验。当 qmodem 返回非预期数据（如内存地址/句柄值 `1782630566`）时，该值穿透到 `/tmp/aiqos_sinr_coeff` → Lua 控制器 → 前端 JS → 显示 "1782630566 dB"。

```
qmodem signal → awk '{print $NF}' → 无校验 → echo → SINR_FILE → GUI
                                                    ↑
                                              get_sinr_uqmi() 有校验但未覆盖此路径
```

### 修复方案 (288b9d9)

两处拦截：

1. **`get_sinr_qmodem()`** — 提取 SINR 后增加 -30~40 dB 范围校验，越界 `return 1` 并记录 WARNING 日志
2. **`main()` 写入前** — 增加最终阀值门，脏数据 `sinr_dirty=true` 时跳过文件写入，面板显示 `--` 而非垃圾值

### 文件
`luci-app-aiqos/src/sinr_injector.sh`

---

## 3. CBI 配置无法保存（ucode 调度器兼容）

**发现时间**：2026-06-28
**影响范围**：LuCI "5G AI 信号优化" 设置页
**严重程度**：高（配置完全不可用）

### 根因

ImmortalWrt 24.10 使用 ucode 调度器替代传统 Lua CBI 调度器。ucode 模式下 `SimpleForm` 的提交按钮名称变更为 `cbi.submit`（传统模式为 `submit`）。

`luci-app-aiqos/luci/model/cbi/aiqos.lua` 中 `on_parse` 回调首行：

```lua
local btn = luci.http.formvalue("submit")
if not btn then return end
```

在 ucode 下 `formvalue("submit")` 永远返回 nil，回调直接 return，所有 UCI 写入逻辑均未执行。用户点击"保存并应用"后：
- 配置未写入 `/etc/config/aiqos`
- `aiqosd` 未重启
- 没有任何错误提示

### 修复方案 (aa367f2)

```lua
local btn = luci.http.formvalue("cbi.submit") or luci.http.formvalue("submit")
```

同时兼容 ucode 和传统 Lua 调度器。

### 文件
`luci-app-aiqos/luci/model/cbi/aiqos.lua`

---

## 4. BusyBox 环境下 uqmi timeout 缺失（早期）

**发现时间**：2026-06-27（之前）
**影响范围**：sinr_injector.sh uqmi 调用
**严重程度**：高（uqmi 挂起导致守护进程阻塞）

### 根因

BusyBox 的 shell 环境不包含 GNU `timeout` 命令。`sinr_injector.sh` 中 `get_sinr_uqmi()` 调用 `uqmi --get-signal-info` 可能因 modem 繁忙而永久挂起。

### 修复方案 (3165dfc / de55037 / 61e29ad)

用纯 shell 实现超时保护（后台进程 + kill -9 硬超时），替代 `timeout 2 uqmi ...` 调用。

---

## 5. 固件版本与补丁状态不一致（defconfig 恢复）

**发现时间**：2026-06-28
**影响范围**：WRT-CORE CI 构建
**严重程度**：中（设备符号丢失导致功能异常）

### 根因

HNAT 补丁清理过程中，部分设备级 defconfig 符号被意外移除，需要恢复以确保 `CONFIG_TARGET_DEVICE_*` 等符号正确。

### 修复方案 (97ce2bd)

在 WRT-CORE.yml 中添加 defconfig 恢复步骤。

---

## 下个版本检查清单

| # | 检查项 | 验证方法 |
|---|--------|---------|
| 1 | HNAT 补丁：9996/9998/9999/99999 是否已不存在于 patches-6.6 | `ls target/linux/mediatek/patches-6.6/999*` |
| 2 | TDTECH USB ID 补丁是否存在 | `grep 0x3466 Scripts/9998-tdtech-usb.patch` |
| 3 | 5G AI 优化面板 SINR 不再出现超大正数 | 进入 LuCI → 服务 → 5G AI 信号优化，观察信号质量卡片 |
| 4 | CBI 配置能正常保存 | 修改预设/开关 → 保存 → 刷新页面确认值保持 |
| 5 | uqmi 调用不阻塞守护进程 | `logread | grep sinr_injector` 无连续 "timeout" 警告 |
| 6 | defconfig 设备符号完整 | 编译后 `grep CONFIG_TARGET_DEVICE .config` |
*（内容由AI生成，仅供参考）*
