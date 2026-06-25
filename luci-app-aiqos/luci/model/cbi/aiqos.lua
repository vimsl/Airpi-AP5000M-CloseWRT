--[[
/usr/lib/lua/luci/model/cbi/aiqos.lua
CBI 妯″瀷: 鐘舵€佷华琛ㄧ洏 + 涓夋。棰勮 + 涓冨紑鍏?+ 楂樼骇璁剧疆
鍏ㄤ腑鏂囩‖缂栫爜锛岄浂鍥介檯鍖栦緷璧栵紝鍏煎 ImmortalWrt 24.10 ucode
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

m = Map("aiqos", "5G AI 淇″彿浼樺寲",
    "AIQoS - 鍩轰簬 cake-autorate + ModemManager 鐨勬櫤鑳?5G CPE 缃戠粶浼樺寲")

-- ====== 鐘舵€佷华琛ㄧ洏 ======
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
<div class="aiqos-card" id="card-sinr"><div class="label">淇″彿璐ㄩ噺</div><div class="value">--</div><div class="sub">SINR dB / RSRP dBm</div></div>
<div class="aiqos-card" id="card-bandwidth"><div class="label">褰撳墠甯﹀</div><div class="value">--</div><div class="sub">CAKE 鍔ㄦ€佽皟鏁?/div></div>
<div class="aiqos-card" id="card-latency"><div class="label">缃戠粶寤惰繜</div><div class="value">--</div><div class="sub">OWD P99</div></div>
<div class="aiqos-card" id="card-uptime"><div class="label">杩愯鏃堕棿</div><div class="value">--</div><div class="sub">aiqosd</div></div>
</div>
<div style="font-size:11px;color:#999;margin-bottom:16px">鏁版嵁姣?2 绉掕嚜鍔ㄥ埛鏂?/div>
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
if(d.sinr&&d.sinr!=='N/A'){s.querySelector('.value').textContent=d.sinr+' dB';var v=parseFloat(d.sinr);s.className='aiqos-card '+(v>=15?'good':v>=5?'warn':'bad');s.querySelector('.sub').textContent='SINR '+d.sinr+'dB / 绯绘暟='+d.sinr_coeff}else{s.querySelector('.value').textContent='--';s.className='aiqos-card'}
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

-- ====== 棰勮閰嶇疆 ======
s = m:section(TypedSection, "preset", "棰勮閰嶇疆")
s.anonymous = true
s.addremove = false

preset = s:option(ListValue, "mode", "浼樺寲棰勮")
preset:value("normal", "鏅€氱敤鎴?- 鏃ュ父娴忚锛屼粎闃茬紦鍐茶啫鑳€")
preset:value("gamer", "娓告垙鐜╁ - 浣庡欢杩熸父鎴忎笌 VoIP")
preset:value("geek", "鏋佸鐢ㄦ埛 - 鍏ㄩ儴鍔熻兘鍚敤锛堜笓瀹舵ā寮忥級")
preset.default = "normal"
preset.rmempty = false
preset.description = "閫夋嫨棰勮灏嗚嚜鍔ㄩ厤缃笅鏂瑰紑鍏筹紝鎮ㄤ粛鍙崟鐙皟鏁淬€?

-- ====== 鍔熻兘寮€鍏?======
s2 = m:section(TypedSection, "switches", "鍔熻兘寮€鍏?)
s2.anonymous = true
s2.addremove = false

o1 = s2:option(Flag, "enable_cake", "鈶?鍩虹闃茬紦鍐茶啫鑳€",
    "鍚敤 cake-autorate 鍔ㄦ€佽皟鏁?CAKE 甯﹀锛屾秷闄ょ紦鍐茶啫鑳€")
o1.default = "1"
o1.rmempty = false

o2 = s2:option(Flag, "enable_sinr", "鈶?淇″彿鑷€傚簲",
    "鏍规嵁 5G SINR 璐ㄩ噺鍔ㄦ€佽皟鏁村甫瀹界郴鏁?)
o2.default = "1"
o2.rmempty = false
if not caps.modem_available then o2.disabled = true end

o3 = s2:option(Flag, "enable_wifi", "鈶?WiFi 浼樺寲",
    "鍚敤 TriTon 鑷姩淇￠亾涓庡姛鐜囦紭鍖?)
o3.default = "0"
o3.rmempty = false
if not caps.wifi_available then o3.disabled = true end

o4 = s2:option(Flag, "enable_ack", "鈶?婵€杩?ACK",
    "鍚敤 CAKE ack-filter 婵€杩涙ā寮忥紝鍑忓皯涓婅鍐椾綑 ACK")
o4.default = "0"
o4.rmempty = false

o5 = s2:option(Flag, "enable_night_lock", "鈶?澶滈棿閿侀",
    "鍑屾櫒 3 鐐硅嚜鍔ㄦ壂鎻忓苟閿佸畾鏈€浣冲皬鍖猴紙浼存湁 3-5 绉掓柇杩烇級")
o5.default = "0"
o5.rmempty = false
if not caps.modem_available then o5.disabled = true end

o6 = s2:option(Flag, "enable_ebpf", "鈶?eBPF 鏋侀檺涓㈠寘",
    "鍦?XDP 灞傛櫤鑳戒涪寮冧綆浠峰€兼壒閲忔暟鎹寘锛堜笓瀹跺姛鑳斤級")
o6.default = "0"
o6.rmempty = false
if not caps.ebpf_available then o6.disabled = true end

o7 = s2:option(Flag, "enable_ai", "鈶?AI 棰勬祴锛堝疄楠屾€э級",
    "鍚敤鍩轰簬 CNN 鐨勪俊鍙疯秼鍔块娴嬩互鎻愬墠璋冩暣鍙傛暟")
o7.default = "0"
o7.rmempty = false
o7:depends("show_advanced", "1")

-- ====== 楂樼骇璁剧疆 ======
s3 = m:section(TypedSection, "advanced", "楂樼骇璁剧疆")
s3.anonymous = true
s3.addremove = false

a0 = s3:option(Flag, "show_advanced", "鏄剧ず瀹為獙鎬у姛鑳?)
a0.default = "0"
a0.description = "鍚敤鍚庯紝AI 棰勬祴寮€鍏冲皢鍙锛屽苟瑙ｉ攣楂樼骇鍙傛暟璋冩暣"

a1 = s3:option(Value, "poll_interval", "淇″彿杞闂撮殧锛堢锛?)
a1.datatype = "uinteger"
a1.default = "2"
a1:depends("show_advanced", "1")

a2 = s3:option(Value, "min_bandwidth", "鏈€灏忓甫瀹斤紙Mbps锛?)
a2.datatype = "uinteger"
a2.default = "5"
a2:depends("show_advanced", "1")

a3 = s3:option(Value, "lock_freq", "閿佸畾鐩爣棰戠偣")
a3.datatype = "uinteger"
a3.optional = true
a3:depends("enable_night_lock", "1")
a3.description = "渚嬪 5078锛坣78锛夈€傜暀绌哄垯鑷姩鎵弿銆?

-- ====== 淇濆瓨鍥炶皟 ======
function m.on_after_commit(map)
    os.execute("/etc/init.d/aiqosd restart >/dev/null 2>&1 &")
end

return m
