--[[
/usr/lib/lua/luci/model/cbi/aiqos.lua
CBI 模型: 状态仪表盘 + 三档预设 + 七开关 + 高级设置
全中文硬编码，零国际化依赖，兼容 ImmortalWrt 24.10 ucode
]]--

local uci = require("luci.model.uci").cursor()
local sys = require("luci.sys")

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
    local json = require("luci.jsonc")
    return json.parse(content) or {
        wifi_available = false,
        ebpf_available = false,
        modem_available = true
    }
end

local caps = get_capabilities()

m = Map("aiqos", "5G AI 信号优化",
    "AIQoS - 基于 cake-autorate + ModemManager 的智能 5G CPE 网络优化")

-- ====== 状态仪表盘 ======
m.description = [=[
<style>
.aiqos-dashboard{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;margin-bottom:20px}
.aiqos-card{background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:14px 12px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,0.08)}
.aiqos-card .label{font-size:12px;color:#666;margin-bottom:4px}
.aiqos-card .value{font-size:28px;font-weight:700;color:#1a1a1a}
.aiqos-card .sub{font-size:11px;color:#999;margin-top:2px}
.aiqos-card.good .value{color:#2e7d32}
.aiqos-card.warn .value{color:#f57c00}
.aiqos-card.bad .value{color:#c62828}
</style>
<div class="aiqos-dashboard" id="status-cards">
<div class="aiqos-card" id="card-sinr"><div class="label">信号质量</div><div class="value">--</div><div class="sub">SINR dB / RSRP dBm</div></div>
<div class="aiqos-card" id="card-bandwidth"><div class="label">当前带宽</div><div class="value">--</div><div class="sub">CAKE 动态调整</div></div>
<div class="aiqos-card" id="card-latency"><div class="label">网络延迟</div><div class="value">--</div><div class="sub">OWD P99</div></div>
<div class="aiqos-card" id="card-uptime"><div class="label">运行时间</div><div class="value">--</div><div class="sub">aiqosd</div></div>
</div>
<div style="font-size:11px;color:#999;margin-bottom:16px">数据每 2 秒自动刷新</div>
<script>
(function(){
function loadStatus(){
var x=new XMLHttpRequest();
x.open('GET',']=] .. luci.dispatcher.build_url("admin","services","aiqos","status_json") .. [=[');
x.onload=function(){if(x.status===200)try{var d=JSON.parse(x.responseText);
var s=document.getElementById('card-sinr');
var b=document.getElementById('card-bandwidth');
var l=document.getElementById('card-latency');
var u=document.getElementById('card-uptime');
if(d.sinr&&d.sinr!=='N/A'){s.querySelector('.value').textContent=d.sinr+' dB';var v=parseFloat(d.sinr);s.className='aiqos-card '+(v>=15?'good':v>=5?'warn':'bad');s.querySelector('.sub').textContent='SINR '+d.sinr+'dB / 系数='+d.sinr_coeff}else{s.querySelector('.value').textContent='--';s.className='aiqos-card'}
if(d.bandwidth&&d.bandwidth!=='N/A'){b.querySelector('.value').textContent=d.bandwidth}else{b.querySelector('.value').textContent='--'}
if(d.latency&&d.latency!=='N/A'){l.querySelector('.value').textContent=d.latency}else{l.querySelector('.value').textContent='--'}
if(d.uptime&&d.uptime!=='N/A'){u.querySelector('.value').textContent=d.uptime}else{u.querySelector('.value').textContent='--'}
}catch(e){}}
x.send()}
setInterval(loadStatus,2000);
loadStatus()
})();
</script>
]=]

-- ====== 预设配置 ======
s = m:section(TypedSection, "preset", "预设配置")
s.anonymous = true
s.addremove = false

preset = s:option(ListValue, "mode", "优化预设")
preset:value("normal", "普通用户 - 日常浏览，仅防缓冲膨胀")
preset:value("gamer", "游戏玩家 - 低延迟游戏与 VoIP")
preset:value("geek", "极客用户 - 全部功能启用（专家模式）")
preset.default = "normal"
preset.rmempty = false
preset.description = "选择预设将自动配置下方开关，您仍可单独调整。"

-- ====== 功能开关 ======
s2 = m:section(TypedSection, "switches", "功能开关")
s2.anonymous = true
s2.addremove = false

o1 = s2:option(Flag, "enable_cake", "① 基础防缓冲膨胀",
    "启用 cake-autorate 动态调整 CAKE 带宽，消除缓冲膨胀")
o1.default = "1"
o1.rmempty = false

o2 = s2:option(Flag, "enable_sinr", "② 信号自适应",
    "根据 5G SINR 质量动态调整带宽系数")
o2.default = "1"
o2.rmempty = false
if not caps.modem_available then o2.disabled = true end

o3 = s2:option(Flag, "enable_wifi", "③ WiFi 优化",
    "启用 TriTon 自动信道与功率优化")
o3.default = "0"
o3.rmempty = false
if not caps.wifi_available then o3.disabled = true end

o4 = s2:option(Flag, "enable_ack", "④ 激进 ACK",
    "启用 CAKE ack-filter 激进模式，减少上行冗余 ACK")
o4.default = "0"
o4.rmempty = false

o5 = s2:option(Flag, "enable_night_lock", "⑤ 夜间锁频",
    "凌晨 3 点自动扫描并锁定最佳小区（伴有 3-5 秒断连）")
o5.default = "0"
o5.rmempty = false
if not caps.modem_available then o5.disabled = true end

o6 = s2:option(Flag, "enable_ebpf", "⑥ eBPF 极限丢包",
    "在 XDP 层智能丢弃低价值批量数据包（专家功能）")
o6.default = "0"
o6.rmempty = false
if not caps.ebpf_available then o6.disabled = true end

o7 = s2:option(Flag, "enable_ai", "⑦ AI 预测（实验性）",
    "启用基于 CNN 的信号趋势预测以提前调整参数")
o7.default = "0"
o7.rmempty = false
o7:depends("show_advanced", "1")

-- ====== 高级设置 ======
s3 = m:section(TypedSection, "advanced", "高级设置")
s3.anonymous = true
s3.addremove = false

a0 = s3:option(Flag, "show_advanced", "显示实验性功能")
a0.default = "0"
a0.description = "启用后，AI 预测开关将可见，并解锁高级参数调整"

a1 = s3:option(Value, "poll_interval", "信号轮询间隔（秒）")
a1.datatype = "uinteger"
a1.default = "2"
a1:depends("show_advanced", "1")

a2 = s3:option(Value, "min_bandwidth", "最小带宽（Mbps）")
a2.datatype = "uinteger"
a2.default = "5"
a2:depends("show_advanced", "1")

a3 = s3:option(Value, "lock_freq", "锁定目标频点")
a3.datatype = "uinteger"
a3.optional = true
a3:depends("enable_night_lock", "1")
a3.description = "例如 5078（n78）。留空则自动扫描。"

-- ====== 保存回调 ======
function m.on_after_commit(map)
    os.execute("/etc/init.d/aiqosd restart >/dev/null 2>&1 &")
end

return m
