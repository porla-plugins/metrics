local events      = require("porla_events")
local http_server = require("porla_http_server")
local sessions    = require("porla_sessions")

return {
    init = function()
        local all_metrics         = sessions.metrics()
        local per_session_metrics = {}

        events.on("session.stats", function(e)
            per_session_metrics[e.session.name] = e.stats
        end)

        events.on("session.unloaded", function(e)
            per_session_metrics[e.session_name] = nil
        end)

        http_server.get("/metrics", function(_, res)
            res:write_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")

            for metric_key, metric in pairs(all_metrics) do
                local normalized_key = metric_key:gsub("%.", "_")

                if metric.type == "counter" then
                    normalized_key = normalized_key .. "_total"
                end

                res:write("# TYPE libtorrent_" .. normalized_key .. " " .. metric.type .. "\n")

                for session_name, stats in pairs(per_session_metrics) do
                    local value = stats[metric_key]

                    if value ~= nil then
                        -- no explicit timestamps since prometheus discards repeated timestamps
                        -- and a late session.stats event would then be a gap in the series
                        res:write("libtorrent_" ..
                            normalized_key ..
                            "{session=\"" .. session_name .. "\"} " .. value .. "\n")
                    end
                end
            end

            res:finish()
        end)
    end
}
