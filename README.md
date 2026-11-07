# A Porla metrics exporter

This is a simple metrics exporter for Porla. It adds a `/metrics` endpoint to
the HTTP server that exports libtorrent session metrics for each session.

## Metrics

- `libtorrent_<metric>` for every libtorrent session metric, with dots replaced by underscores
  (`net.sent_payload_bytes` becomes `libtorrent_net_sent_payload_bytes_total`). Counters get a
  `_total` suffix.
- `porla_session_stats_updated_seconds`, the Unix time of the latest stats from each session.

Every series has a `session` label with the session name. Stats are collected every
`timer_session_stats` milliseconds, 5000 by default.

## Prometheus

```yaml
scrape_configs:
  - job_name: porla
    scrape_interval: 15s
    static_configs:
      - targets: ["localhost:1337"]
```

Scraping much faster than the stats interval only repeats the same values. Use
`rate(...[$__rate_interval])` in Grafana, with the data source's scrape interval set to match.

The values are what Porla last received, so they keep their last value if a session stops
sending stats. To alert on that:

```promql
time() - porla_session_stats_updated_seconds > 60
```
