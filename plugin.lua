return {
    name    = "metrics",
    version = "1.0",

    init = function()
        print("Loading metrics plugin")

        local all_metrics         = porla.session_metrics()
        local per_session_metrics = {}

        porla.on("session.stats", function(session, values)
            per_session_metrics[session.name] = {
                values = values,
                epoch  = porla.unix_time()
            }
        end)

        http_server.get("/metrics", function(req, res)
            for metric_key, metric in pairs(all_metrics) do
                local normalized_key = metric_key:gsub("%.", "_")

                if metric.type == "counter" then
                    normalized_key = normalized_key .. "_total"
                end

                res:write("# TYPE libtorrent_" .. normalized_key .. " " .. metric.type .. "\n")

                for session_name, data in pairs(per_session_metrics) do
                    local value = data.values[metric_key]

                    if value ~= nil then
                        res:write("libtorrent_" .. normalized_key .. "{session=\"" .. session_name .. "\"} " .. value .. " " .. data.epoch .. "\n")
                    end
                end
            end

            res:finish()
        end)
    end,

    destroy = function()
        print("Destroying metrics plugin")
    end
}
