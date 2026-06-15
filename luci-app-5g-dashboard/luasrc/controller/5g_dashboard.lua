module("luci.controller.5g_dashboard", package.seeall)

function index()
    -- 挂载为左侧一级菜单，放在 'admin' 根节点下
    -- 排序权重(index)设为 2，确保它精准插在"首页"和"网络向导"之间
    entry({"admin", "5g_dashboard"}, template("5g_dashboard/index"), _("5G 监控看板"), 2).dependent = false
    entry({"admin", "5g_dashboard", "overview"}, template("5g_dashboard/index"), nil)
end
