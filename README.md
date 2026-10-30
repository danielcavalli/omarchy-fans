# Fans for Omarchy

Case fans driven by the CPU **and** the graphics card together, from the Omarchy bar.

Motherboards drive case fans from the CPU temperature, so a GPU running flat out heats the case
while the fans barely move. This plugin gives every fan group two curves, one on the CPU and
one on the GPU, and runs it at whichever asks for more. The bar shows the hotter of the two;
the panel shows each group's speed, both curves and where each temperature sits on them.
Profiles, a timed boost and curve edits are a click, a key or one command away, for you or an
AI agent.

## How it works

| Part | Runs as | Does |
|---|---|---|
| `omarchy-fansd` | root (systemd) | reads the temperatures every 2 s, sets the fan headers, serves its state on `/run/omarchy-fans/socket` |
| `omarchy-fans` | you | the command line, for you and for agents (`--json` everywhere) |
| the plugin | the Omarchy shell | the bar widget and its panel, over the same socket |

The plugin runs inside the shell as your user and cannot write fan speeds; only the root
service touches hardware, and **safety lives there, whatever a client asks for**:

- pump headers are never written; they stay on their BIOS setting
- every group goes to 100% when the CPU or the GPU reaches its limit (90 °C and 85 °C by default)
- every group keeps a minimum speed
- a temperature that cannot be read sends the groups that follow it to 100%
- curves that fall as temperature rises, or that do not reach 100% by the limit, are refused
- when the service stops, crashes or is set to the `bios` profile, every header goes back to the
  BIOS curve

Speeds rise at once and fall slowly, and a falling temperature is averaged, so fans do not pulse.

## Install

Needs an Omarchy with shell plugins (4.x), a Super I/O fan controller the kernel drives
(`nct6775` or `it87`; most ASUS, MSI, Gigabyte and ASRock boards) and Python 3.

```bash
omarchy plugin add https://github.com/danielcavalli/omarchy-fans.git --enable
~/.config/omarchy/plugins/rio.dan.fans/setup
```

`setup` asks for `sudo` once. It installs the service and the command and loads the fan driver
at every boot. It asks nothing: a header the BIOS runs at a flat 100% that spins like a pump (or
reports no speed) is the pump, never touched; every other header is fans. It prints what it
found. If it gets the pump wrong, name it: `setup --pump 7`. `omarchy-fansd headers` lists the
headers with their speeds; run `setup` again any time to redo it.

## Use

**Bar:** the fan glyph and the hotter of the CPU and GPU, red near a limit. Left click opens the
panel, right click cycles the profile, middle click boosts.

**Panel:** profiles, a 15-minute boost, and for each group its speed, why it runs at that speed
and its two curves (CPU in the foreground colour, GPU in the accent) with the current point.
Keys: `1`-`5` profiles, `b` boost.

**Profiles:**

| Profile | Does |
|---|---|
| `quiet` | GPU curves 5 °C later, minimums 10 points lower |
| `balanced` | the curves as set |
| `cool` | GPU curves 5 °C earlier (long GPU jobs) |
| `max` | everything at 100% |
| `bios` | hands the fans back to the board; the service keeps reporting |

**Command line:**

```bash
omarchy-fans status                    # or --json
omarchy-fans profile cool
omarchy-fans boost 100 30m             # boost off
omarchy-fans curve show
omarchy-fans curve set fans gpu 40:40,60:65,72:100
omarchy-fans curve reset
omarchy-fans watch --json              # a line per update
```

Shell IPC works too: `omarchy-shell rio.dan.fans status|profile <name>|boost <duty> <duration>|boostOff`.

## Default curves (balanced)

| | Curve | Minimum |
|---|---|---|
| CPU | 40 °C 35% → 60 °C 50% → 75 °C 75% → 85 °C 100% | 35% |
| GPU | 40 °C 40% → 55 °C 55% → 65 °C 75% → 72 °C 100% | |

Every fan follows both, CPU fan and AIO radiator fans included, so the CPU never gets less air
than its own curve asks and the case clears the GPU's heat. Edits made with `curve set` are kept
in `/var/lib/omarchy-fans/state.json`; the headers and limits are in
`/etc/omarchy-fans/config.json`, where the fans can be split into more groups, each with its own
curves.

## Temperatures

- **CPU:** AMD `k10temp` Tctl or Intel `coretemp` package, plus the board's own reading of the
  CPU where it has one (`TSI0_TEMP`); the hottest counts.
- **GPU:** NVIDIA through NVML (every card; the hottest counts), or one discrete AMD card by PCI
  address (`"gpu": "amdgpu:0000:03:00.0"`). Integrated graphics are ignored.

## Uninstall

```bash
~/.config/omarchy/plugins/rio.dan.fans/uninstall
omarchy plugin remove rio.dan.fans
```

## License

MIT
