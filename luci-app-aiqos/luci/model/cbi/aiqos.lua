--[[
/usr/lib/lua/luci/model/cbi/aiqos.lua
CBI模型: 七开关 + 预设配置 + 高级设置
]]--

local uci = require("luci.model.uci").cursor()
local sys = require("luci.sys")
local json = require("luci.jsonc")

-- 读取能力探测结果
local function get_capabilities()
    local file = io.open("/tmp/aiqos_capability.json", "r")
    if not file then
        os.execute("/usr/bin/condition_detect.sh json > /dev/null 2>&1")
        file = io.open("/tmp/aiqos_capability.json", "r")
        if not file then
            return {
                wifi_available = false,
                ebpf_available = false,
                modem_available = true
            }
        end
    end
    local content = file:read("*all")
    file:close()
    return json.parse(content) or {
        wifi_available = false,
        ebpf_available = false,
        modem_available = true
    }
end

local caps = get_capabilities()

m = Map("aiqos", translate("5G AI Signal Optimization"),
    translate("AIQoS - Intelligent 5G CPE network optimization via cake-autorate + ModemManager"))

-- ====== 预设选择 ======
s = m:section(TypedSection, "preset", translate("Preset Configuration"))
s.anonymous = true
s.addremove = false

preset = s:option(ListValue, "mode", translate("Optimization Preset"))
preset:value("normal", translate("Normal User") .. " - " .. translate("Daily browsing, anti-bufferbloat only"))
preset:value("gamer", translate("Gamer") .. " - " .. translate("Low latency for gaming/VoIP"))
preset:value("geek", translate("Geek User") .. " - " .. translate("All features enabled (expert mode)"))
preset.default = "normal"
preset.rmempty = false
preset.description = translate("Select a preset to auto-configure switches below. You can still adjust individually.")

-- ====== 七开关面板 ======
s2 = m:section(TypedSection, "switches", translate("Feature Switches"))
s2.anonymous = true
s2.addremove = false

-- 开关1: 基础防膨胀
o1 = s2:option(Flag, "enable_cake", translate("① Basic Anti-Bufferbloat"),
    translate("Enable cake-autorate to dynamically adjust CAKE bandwidth, eliminate bufferbloat"))
o1.default = "1"
o1.rmempty = false

-- 开关2: 信号自适应
o2 = s2:option(Flag, "enable_sinr", translate("② Signal Adaptive"),
    translate("Dynamically adjust bandwidth coefficient based on 5G SINR quality"))
o2.default = "1"
o2.rmempty = false
if not caps.modem_available then
    o2:value("0", translate("Unavailable: ModemManager not running"))
    o2.disabled = true
end

-- 开关3: WiFi优化
o3 = s2:option(Flag, "enable_wifi", translate("③ WiFi Optimization"),
    translate("Enable TriTon auto channel/power optimization"))
o3.default = "0"
o3.rmempty = false
if not caps.wifi_available then
    o3:value("0", translate("Unavailable: No WiFi hardware"))
    o3.disabled = true
end

-- 开关4: 激进ACK
o4 = s2:option(Flag, "enable_ack", translate("④ Aggressive ACK"),
    translate("Enable CAKE ack-filter aggressive mode, reduce uplink redundant ACKs"))
o4.default = "0"
o4.rmempty = false

-- 开关5: 夜间锁频
o5 = s2:option(Flag, "enable_night_lock", translate("⑤ Night Lock"),
    translate("Auto scan and lock best cell at 3:00 AM (3-5s disconnection risk)"))
o5.default = "0"
o5.rmempty = false
if not caps.modem_available then
    o5:value("0", translate("Unavailable: ModemManager not running"))
    o5.disabled = true
end

-- 开关6: eBPF极限丢包
o6 = s2:option(Flag, "enable_ebpf", translate("⑥ eBPF Limit Drop"),
    translate("Intelligently drop low-value bulk packets at XDP layer (expert)"))
o6.default = "0"
o6.rmempty = false
if not caps.ebpf_available then
    o6:value("0", translate("Unavailable: Kernel eBPF not supported"))
    o6.disabled = true
end

-- 开关7: AI预测 (实验性, 默认隐藏)
o7 = s2:option(Flag, "enable_ai", translate("⑦ AI Prediction (Experimental)"),
    translate("Enable CNN-based signal trend prediction for pre-adjustment"))
o7.default = "0"
o7.rmempty = false
o7:depends("show_advanced", "1")

-- ====== 高级设置 ======
s3 = m:section(TypedSection, "advanced", translate("Advanced Settings"))
s3.anonymous = true
s3.addremove = false

a0 = s3:option(Flag, "show_advanced", translate("Show Experimental Features"))
a0.default = "0"
a0.description = translate("When enabled, AI Prediction switch becomes visible and advanced parameters unlocked")

a1 = s3:option(Value, "poll_interval", translate("Signal Poll Interval (seconds)"))
a1.datatype = "uinteger"
a1.default = "2"
a1:depends("show_advanced", "1")

a2 = s3:option(Value, "min_bandwidth", translate("Minimum Bandwidth (Mbps)"))
a2.datatype = "uinteger"
a2.default = "5"
a2:depends("show_advanced", "1")

a3 = s3:option(Value, "lock_freq", translate("Lock Target Frequency"))
a3.datatype = "uinteger"
a3.optional = true
a3:depends("enable_night_lock", "1")
a3.description = translate("e.g. 5078 (n78). Leave empty for auto-scan.")

-- ====== 保存回调 ======
function m.on_after_commit(map)
    sys.call("/etc/init.d/aiqosd restart 2>/dev/null")
    luci.http.redirect(luci.dispatcher.build_url("admin", "services", "aiqos"))
end

return m
