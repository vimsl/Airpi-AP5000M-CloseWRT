--[[
/usr/lib/lua/luci/controller/aiqos.lua
LuCI控制器: 菜单 + 路由 + 状态API
]]--

module("luci.controller.aiqos", package.seeall)

function index()
    entry({"admin", "services", "aiqos"},
          cbi("aiqos"),
          translate("5G AI Optimization"),
          50)

    entry({"admin", "services", "aiqos", "status"},
          view("aiqos/status"),
          translate("Status"),
          10)

    entry({"admin", "services", "aiqos", "status_json"},
          call("action_status_json"),
          nil).leaf = true

    entry({"admin", "services", "aiqos", "history_json"},
          call("action_history_json"),
          nil).leaf = true

    entry({"admin", "services", "aiqos", "lock_now"},
          call("action_lock_now"),
          nil).leaf = true
end

function action_status_json()
    luci.http.prepare_content("application/json")

    local status = {
        sinr = "N/A",
        rsrp = "N/A",
        bandwidth = "N/A",
        latency = "N/A",
        uptime = "N/A",
        cake_active = false,
        sinr_coeff = "1.0"
    }

    -- 读取SINR系数
    local f = io.open("/tmp/aiqos_sinr_coeff", "r")
    if f then
        local line = f:read("*line")
        f:close()
        if line then
            local parts = {}
            for word in line:gmatch("%S+") do
                table.insert(parts, word)
            end
            if #parts >= 2 then
                status.sinr_coeff = parts[1]
                status.sinr = parts[2]
            end
        end
    end

    -- 读取CAKE队列状态
    local handle = io.popen("tc -s qdisc show dev wwan0 2>/dev/null | grep -A5 cake")
    if handle then
        local output = handle:read("*all")
        handle:close()
        if output and #output > 0 then
            status.cake_active = true
            local bw = output:match("bandwidth (%d+%a?)")
            if bw then
                status.bandwidth = bw
            end
        end
    end

    -- 运行时间
    local f2 = io.open("/var/run/aiqosd.pid", "r")
    if f2 then
        local pid = f2:read("*line")
        f2:close()
        if pid then
            local handle2 = io.popen("ps -p " .. pid .. " -o etime= 2>/dev/null")
            if handle2 then
                local etime = handle2:read("*line")
                handle2:close()
                if etime then
                    status.uptime = etime:match("^%s*(.-)%s*$")
                end
            end
        end
    end

    luci.http.write_json(status)
end

function action_history_json()
    luci.http.prepare_content("application/json")

    local history = {}
    local f = io.open("/var/log/sinr_injector.log", "r")
    if f then
        local lines = {}
        for line in f:lines() do
            local sinr = line:match("SINR=([%d.-]+)dB")
            if sinr then
                local ts = line:match("%[(.-)%]")
                table.insert(lines, { time = ts, sinr = tonumber(sinr) })
            end
        end
        f:close()

        local count = #lines
        if count > 100 then
            for i = count - 99, count do
                table.insert(history, lines[i])
            end
        else
            history = lines
        end
    end

    luci.http.write_json(history)
end

function action_lock_now()
    luci.http.prepare_content("application/json")

    local ret = os.execute("/usr/bin/night_lock.sh 2>&1")
    local result = {
        success = (ret == 0),
        message = ret == 0 and "Lock triggered successfully" or "Lock failed"
    }
    luci.http.write_json(result)
end
