<h1 align="center">ConfuseRKN</h1>
<p align="center">
  <em>Self-host your own whitelist subscription</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License: GPL-3.0">
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey.svg" alt="Platform: Linux">
</p>

---

Script to run your own whitelist subscription, similar to **GoodbyeWL** or **EtoNeYa**: aggregates keys from sources, checks them, and serves a public subscription URL that users add to their VPN/client.

> **Sources:** EtoNeYaProject, BypassWhitelistRu — fighting Roskomnadzor, helping users browse as before.

---

## Table of Contents

- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Menu](#menu)
- [Sources](#sources)
- [SOCKS5 Proxy](#socks5-proxy)
- [Files & Directories](#files--directories)
- [How It Works](#how-it-works)
- [Credits](#credits)
- [License](#license)
- [Links](#links)

---

## Requirements

| | |
|---|---|
| **OS** | Linux (Debian/Ubuntu recommended) |
| **Privileges** | Root or sudo |
| **Packages** | python3, python3-venv, nginx, curl, cron, nano *(installed automatically)* |

---

## Quick Start

**One-liner** (download and run):

```bash
curl -sSL https://raw.githubusercontent.com/gbwltg/ConfuseRKN/refs/heads/main/script.sh | sudo bash
```

**Or** download first, then run:

```bash
curl -sSL https://raw.githubusercontent.com/gbwltg/ConfuseRKN/refs/heads/main/script.sh -o confuserkn.sh
sudo bash confuserkn.sh
```

Select **[1] First install** → follow prompts → share your subscription URL.

---

## Installation

1. **Download** and run:

   ```bash
   # Option A: one-liner
   curl -sSL https://raw.githubusercontent.com/gbwltg/ConfuseRKN/refs/heads/main/script.sh | sudo bash

   # Option B: download file, then run
   curl -sSL https://raw.githubusercontent.com/gbwltg/ConfuseRKN/refs/heads/main/script.sh -o confuserkn.sh
   sudo bash confuserkn.sh
   ```

2. **Choose** `[1] First install` in the menu.

3. **Configure** via prompts:

   | Prompt | Description |
   |--------|-------------|
   | Domain | Where the subscription will be available *(empty = auto-detect IP)* |
   | Subscription path | URL path *(e.g. `sub` → `http://your-server/sub`)* |
   | Sources | Use defaults or add custom URLs |
   | SOCKS5 proxy | Enable if GitHub/raw is blocked in your region |

4. **Share** the subscription URL with users — they add it to their VPN/client as a subscription.

---

## Menu

| # | Option | Description |
|---|--------|-------------|
| 1 | First install | Full setup: packages, Python venv, Nginx, systemd timer |
| 2 | Run parser now | Manually update subscription |
| 3 | Edit sources | Edit `sources.txt` in nano |
| 4 | Change subscription path | Change URL path *(e.g. `/sub` → `/my-sub`)* |
| 5 | Toggle proxy | Enable or disable SOCKS5 proxy |
| 6 | Show subscription URL | Display current subscription URL |
| 7 | Remove a source | Remove a source from the list |
| 0 | Exit | Quit the script |

---

## Sources

The parser fetches whitelist content from URLs listed in `sources.txt`.

**Default sources:**
- **EtoNeYaProject** — community whitelist
- **BypassWhitelistRu** (LowiKLive) — Russian bypass whitelist

**Custom sources:** add URLs in `sources.txt` (one per line). Lines starting with `#` are ignored.

---

## SOCKS5 Proxy

Use when GitHub or `raw.githubusercontent.com` is blocked.

**Format:**
- `ip:port`
- `ip:port:user:password`

**Example:** `127.0.0.1:1080`

---

## Files & Directories

| Path | Purpose |
|------|---------|
| `/var/www/confuserkn/` | Install directory |
| `sources.txt` | List of source URLs |
| `sub.txt` | Generated subscription *(output)* |
| `proxy.txt` | SOCKS5 config *(optional)* |
| `downloader.py` | Parser script |
| `/etc/nginx/sites-available/simplehost` | Nginx config |
| `confuserkn.service` / `confuserkn.timer` | Systemd service & timer *(every 30 min)* |

---

## How It Works

```
sources.txt  →  Download whitelists  →  Extract links  →  TCP check  →  sub.txt  →  Nginx serves
                                                                                        ↓
                                                                              User subscription URL
```

1. Parser reads URLs from `sources.txt`
2. Downloads whitelist content from each source
3. Extracts links *(skips empty lines and `#` comments)*
4. TCP check verifies each link is reachable *(200 workers)*
5. Writes working keys to `sub.txt`
6. Nginx serves `sub.txt` at your domain/path
7. Systemd timer runs the parser every 30 minutes

---

## Credits

| Project | Role |
|---------|------|
| **GoodbyeWL** | Script & self-host concept |
| **EtoNeYaProject** | Default whitelist source |
| **BypassWhitelistRu** (LowiKLive) | Default whitelist source |

*Thanks for participating in the fight for open and free internet.*

---

## License

**GNU General Public License v3.0**

This script downloads and installs packages, tools, and libraries (e.g. Python, nginx, pip packages) that may be distributed under other licenses. See their respective documentation.

---

## Links

- **GitHub:** [GoodbyeWL](https://github.com/gbwltg/ConfuseRKN/)
- **Telegram:** [@GoodbyeWLAlt](https://t.me/GoodbyeWLAlt)
