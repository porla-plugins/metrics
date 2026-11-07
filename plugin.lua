local events      = require("porla_events")
local http_server = require("porla_http_server")
local sessions    = require("porla_sessions")
local timers      = require("porla_timers")

-- an unescaped quote in one session name makes Prometheus reject the whole scrape
local function escape_label(value)
    return (value:gsub("[\\\"\n]", { ["\\"] = "\\\\", ["\""] = "\\\"", ["\n"] = "\\n" }))
end

return {
    init = function()
        local metrics = {}

        for key, metric in pairs(sessions.metrics()) do
            local name = "libtorrent_" .. key:gsub("%.", "_")

            if metric.type == "counter" then
                name = name .. "_total"
            end

            table.insert(metrics, { key = key, name = name, type = metric.type })
        end

        table.sort(metrics, function(a, b) return a.name < b.name end)

        -- keyed by id, so a renamed session replaces its series instead of leaving the old name behind
        local per_session = {}

        events.on("session.stats", function(e)
            -- the session can be gone by the time the event runs, and session.unloaded may already have been handled
            if e.session == nil then
                return
            end

            per_session[e.session_id] = {
                label   = escape_label(e.session.name),
                stats   = e.stats,
                updated = timers.epoch() / 1000
            }
        end)

        events.on("session.unloaded", function(e)
            per_session[e.session_id] = nil
        end)

        http_server.get("/metrics", function(_, res)
            local lines = {}

            for _, metric in ipairs(metrics) do
                table.insert(lines, "# TYPE " .. metric.name .. " " .. metric.type)

                for _, session in pairs(per_session) do
                    local value = session.stats[metric.key]

                    if value ~= nil then
                        -- no explicit timestamps since prometheus discards repeated timestamps
                        -- and a late session.stats event would then be a gap in the series
                        table.insert(lines, metric.name .. "{session=\"" .. session.label .. "\"} " .. value)
                    end
                end
            end

            table.insert(lines, "# TYPE porla_session_stats_updated_seconds gauge")

            for _, session in pairs(per_session) do
                table.insert(lines,
                    "porla_session_stats_updated_seconds{session=\"" .. session.label .. "\"} " .. session.updated)
            end

            res:write_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            res:finish(table.concat(lines, "\n") .. "\n")
        end)
    end
}
