# Fans: notes for AI agents

You can read and steer this machine's case fans. The hardware is guarded by the root service
`omarchy-fansd`, so nothing you send can stop a fan, touch a pump or let a part overheat; use it
freely.

## Read

```bash
omarchy-fans status --json
```

```json
{"ok": true, "status": {
  "profile": "balanced", "boost": null, "safety": [],
  "limits": {"cpu": 90, "gpu": 85},
  "temps": {"cpu": 69.0, "gpu": 78.0}, "smoothed": {"cpu": 69.0, "gpu": 78.0},
  "gpus": [{"index": 0, "temp": 78.0, "watts": 280, "fan": 98}],
  "groups": {"intake": {"label": "Intake", "headers": [5], "duty": 100, "target": 100,
                        "reason": "gpu", "asks": {"cpu": 63, "gpu": 100}, "rpm": [1520],
                        "min": 40, "curves": {"cpu": [[50, 40], [70, 60], [85, 100]],
                                              "gpu": [[40, 40], [55, 55], [65, 75], [72, 100]]}}},
  "pumps": [{"header": 7, "rpm": 2710, "duty": 100}]}}
```

`reason` says what sets a group's speed: `cpu` or `gpu` (that curve asks most), `minimum`,
`max`, `boost`, `<source> at its limit` (safety), `no <source> reading`, or `bios`.
`safety` lists sources at their limit. `gpus[].fan` is the card's own fan, a good sign of
whether the case air is helping.

## Steer

| Want | Command |
|---|---|
| a long GPU job is about to start | `omarchy-fans profile cool` |
| maximum air for a while | `omarchy-fans boost 100 30m` (ends by itself; `boost off`) |
| quiet, e.g. a call | `omarchy-fans profile quiet` |
| the board's own control | `omarchy-fans profile bios` |
| a different curve | `omarchy-fans curve set GROUP cpu|gpu T:D,T:D,...` |
| undo curve edits | `omarchy-fans curve reset [GROUP [SOURCE]]` |

Add `--json` for machine-readable replies. Exit codes: `0` done, `1` refused (the message says
why, e.g. a curve that does not reach 100% by the limit), `2` the service is not running.

A curve has 2-8 points of `temperature:duty`, temperatures rising, duty never falling, ending at
100% at or below the source's limit.

## Protocol

The CLI and the bar speak JSON lines on `/run/omarchy-fans/socket` (group-restricted to the
user who ran setup): `{"cmd": "status"}`, `{"cmd": "subscribe"}` (a status every 2 s),
`{"cmd": "profile", "name": "cool"}`, `{"cmd": "boost", "duty": 100, "seconds": "15m"}`,
`{"cmd": "boost", "off": true}`, `{"cmd": "curve", "group": "intake", "source": "gpu",
"points": [[40, 40], [72, 100]]}`, `{"cmd": "curve-reset"}`, `{"cmd": "config"}`.
Every reply is `{"ok": true, "status": ...}` or `{"ok": false, "error": "..."}`.
