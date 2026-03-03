#!/bin/bash
# ConfuseRKN — self-host whitelist subscription
# License: GNU General Public License v3.0
# The script installs packages and downloads tools/libraries that may be under other licenses.
set -e

SERVICE_NAME="confuserkn"
INSTALL_DIR="/var/www/confuserkn"
THREADS=200
TIMEOUT=3

# ===============================
# FUNCTIONS
# ===============================

install_stack() {
    echo "=== INSTALLING STACK ==="

    echo "  Updating package lists..."
    apt update >/dev/null 2>&1
    echo "  ✓ apt updated"

    echo "  Installing: python3, python3-venv, nginx, curl, cron, nano..."
    apt install -y python3 python3-venv nginx curl cron nano >/dev/null 2>&1
    echo "  ✓ System packages installed"

    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR

    # -------------------------------
    # DOMAIN
    # -------------------------------
    echo ""
    echo "  [Domain] — address where subscription will be available."
    read -p "  Enter domain (empty = auto-detect server IP): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        DOMAIN=$(curl -s ifconfig.me)
        echo "  → Using IP: $DOMAIN"
    fi

    # -------------------------------
    # SUBSCRIPTION PATH
    # -------------------------------
    echo ""
    echo "  [Subscription path] — URL part after domain (e.g. sub → http://domain/sub)."
    read -p "  Enter path (empty = sub): " SUB_PATH
    if [ -z "$SUB_PATH" ]; then
        SUB_PATH="sub"
    fi

    # -------------------------------
    # SOURCES
    # -------------------------------
    echo ""
    echo "  [Sources] — URLs of lists from which subscription keys are fetched."
    echo "  Default: EtoNeYaProject, BypassWhitelistRu"
    read -p "  Use default sources? (y/n): " DEF
    if [ "$DEF" = "y" ]; then
cat > sources.txt <<EOF
https://raw.githubusercontent.com/EtoNeYaProject/etoneyaproject.github.io/refs/heads/main/whitelist
https://raw.githubusercontent.com/LowiKLive/BypassWhitelistRu/refs/heads/main/WhiteList-Bypass_Ru.txt
EOF
        echo "  → Added: EtoNeYaProject, BypassWhitelistRu"
    else
        nano sources.txt
    fi

    # -------------------------------
    # SOCKS5
    # -------------------------------
    echo ""
    echo "  [Proxy] — use when sources are unreachable without proxy"
    echo "  (e.g. GitHub/raw is blocked in your region)."
    echo "  Format: ip:port  OR  ip:port:user:password"
    read -p "  Use SOCKS5 proxy? (y/n): " USE_PROXY
    if [ "$USE_PROXY" = "y" ]; then
        read -p "  Enter SOCKS5 proxy: " PROXY
        echo "$PROXY" > proxy.txt
        echo "  → Proxy saved"
    else
        rm -f proxy.txt
    fi

    # -------------------------------
    # PYTHON VENV
    # -------------------------------
    echo ""
    echo "  Creating Python venv..."
    python3 -m venv venv >/dev/null 2>&1
    source venv/bin/activate
    pip install --upgrade pip >/dev/null 2>&1
    pip install "httpx[http2,socks]" >/dev/null 2>&1
    echo "  ✓ Python packages: httpx, http2, socks"

    # -------------------------------
    # DOWNLOADER
    # -------------------------------
cat > downloader.py <<'PYEOF'
#!/usr/bin/env python3
import httpx, socket, urllib.parse, concurrent.futures, os, sys

INPUT_FILE="sources.txt"
OUTPUT_FILE="sub.txt"
TIMEOUT=3
MAX_WORKERS=200

def parse_proxy(raw):
    """Convert ip:port or ip:port:user:password to socks5:// URL"""
    p = raw.strip()
    if not p:
        return None
    if p.startswith(("socks5://", "socks4://", "http://", "https://")):
        return p
    parts = p.split(":")
    if len(parts) == 2:
        return f"socks5://{parts[0]}:{parts[1]}"
    if len(parts) >= 4:
        ip, port, user = parts[0], parts[1], parts[2]
        password = ":".join(parts[3:])
        user = urllib.parse.quote(user, safe="")
        password = urllib.parse.quote(password, safe="")
        return f"socks5://{user}:{password}@{ip}:{port}"
    return p

proxy = None
if os.path.exists("proxy.txt"):
    with open("proxy.txt") as f:
        p = f.read().strip()
        if p:
            proxy = parse_proxy(p)
            print("Using proxy: socks5://***")

transport = httpx.HTTPTransport(retries=2)
if proxy:
    client = httpx.Client(transport=transport, proxy=proxy, timeout=10, http2=True)
else:
    client = httpx.Client(transport=transport, timeout=10, http2=True)

def download(url):
    try:
        r=client.get(url)
        r.raise_for_status()
        lines=[l.strip() for l in r.text.splitlines() if l.strip() and not l.startswith("#")]
        print(f"Downloaded: {url} ({len(lines)} lines)")
        return lines
    except Exception as e:
        print("Failed:",url,e)
        return []

def tcp_check(link):
    try:
        parsed=urllib.parse.urlparse(link)
        host=parsed.hostname
        port=parsed.port or 443
        sock=socket.create_connection((host,port),timeout=TIMEOUT)
        sock.close()
        return link
    except:
        return None

def main():
    if not os.path.exists(INPUT_FILE):
        print("sources.txt missing")
        sys.exit(1)

    all_links=[]
    with open(INPUT_FILE) as f:
        sources=[x.strip() for x in f if x.strip()]

    print("Running parser...")
    for s in sources:
        all_links += download(s)

    print("Total links:",len(all_links))
    print("Checking TCP...")

    good=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures=[ex.submit(tcp_check,l) for l in all_links]
        for f in concurrent.futures.as_completed(futures):
            r=f.result()
            if r:
                good.append(r)

    with open(OUTPUT_FILE,"w") as f:
        f.write("\n".join(good))

    print("SUCCESS:",len(good),"working keys")

if __name__=="__main__":
    main()
PYEOF
    chmod +x downloader.py

    # -------------------------------
    # NGINX
    # -------------------------------
cat > /etc/nginx/sites-available/simplehost <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        root $INSTALL_DIR;
        autoindex on;
    }

    location = /$SUB_PATH {
        alias $INSTALL_DIR/sub.txt;
        default_type text/plain;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/simplehost /etc/nginx/sites-enabled/simplehost
    nginx -t >/dev/null 2>&1
    systemctl restart nginx >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    echo "  ✓ Nginx configured and started"

    # -------------------------------
    # SYSTEMD SERVICE + TIMER
    # -------------------------------
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=ConfuseRKN Parser
After=network.target

[Service]
Type=oneshot
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/downloader.py
EOF

cat > /etc/systemd/system/${SERVICE_NAME}.timer <<EOF
[Unit]
Description=Run parser every 30 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable ${SERVICE_NAME}.timer >/dev/null 2>&1
    systemctl start ${SERVICE_NAME}.timer >/dev/null 2>&1
    echo "  ✓ Timer: parser every 30 min"

    # -------------------------------
    # FIRST RUN
    # -------------------------------
    echo "  Running first parse..."
    $INSTALL_DIR/venv/bin/python $INSTALL_DIR/downloader.py >/dev/null 2>&1
    KEYS=$(wc -l < "$INSTALL_DIR/sub.txt" 2>/dev/null || echo 0)
    echo "  ✓ First parse: $KEYS working keys"

    echo ""
    echo "✅ INSTALL COMPLETE"
    echo ""
    echo "  Subscription URL:"
    echo "  http://$DOMAIN/$SUB_PATH"
    echo ""
    read -p "  Press Enter to return to menu... " _
}

run_parser() {
    cd $INSTALL_DIR
    source venv/bin/activate
    python downloader.py
}

source_friendly_name() {
    case "$1" in
        *EtoNeYaProject*etoneyaproject*whitelist*) echo "EtoNeYaProject" ;;
        *BypassWhitelistRu*WhiteList-Bypass*) echo "BypassWhitelistRu" ;;
        *) echo "$1" ;;
    esac
}

edit_sources() {
    cd $INSTALL_DIR
    nano sources.txt
}

remove_source() {
    cd $INSTALL_DIR
    echo ""
    if [ ! -f sources.txt ] || [ ! -s sources.txt ]; then
        echo "  No sources. Add them via Edit sources [3] or First install [1]."
        echo ""
        read -p "  Press Enter to continue... " _
        return
    fi
    SOURCES=()
    while IFS= read -r line; do
        [ -n "$line" ] && SOURCES+=("$line")
    done < sources.txt
    echo "  Current sources:"
    echo ""
    for i in "${!SOURCES[@]}"; do
        n=$((i + 1))
        FRIENDLY=$(source_friendly_name "${SOURCES[$i]}")
        echo "    [$n] $FRIENDLY"
    done
    echo "    [0] Cancel"
    echo ""
    read -p "  Enter number to remove (0 = cancel): " NUM
    if [ "$NUM" = "0" ] || [ -z "$NUM" ]; then
        echo "  Cancelled."
    else
        if [[ "$NUM" =~ ^[0-9]+$ ]] && [ "$NUM" -ge 1 ] && [ "$NUM" -le "${#SOURCES[@]}" ]; then
            REMOVED="${SOURCES[$((NUM - 1))]}"
            FRIENDLY=$(source_friendly_name "$REMOVED")
            { for i in "${!SOURCES[@]}"; do
                [ $((i + 1)) -ne "$NUM" ] && echo "${SOURCES[$i]}"
            done; } > sources.txt
            echo "  → Removed: $FRIENDLY"
        else
            echo "  Invalid number."
        fi
    fi
    echo ""
    read -p "  Press Enter to continue... " _
}

change_subpath() {
    cd $INSTALL_DIR
    read -p "Enter new subscription path (example: subka): " SUB_PATH
    if [ -z "$SUB_PATH" ]; then SUB_PATH="sub"; fi
    sed -i "/location = /c\    location = /$SUB_PATH { alias $INSTALL_DIR/sub.txt; default_type text/plain; }" /etc/nginx/sites-available/simplehost
    nginx -t && systemctl restart nginx
    echo "Subscription path updated to /$SUB_PATH"
}

show_subscription_url() {
    echo ""
    if [ -f /etc/nginx/sites-available/simplehost ]; then
        DOMAIN=$(grep server_name /etc/nginx/sites-available/simplehost | head -1 | sed 's/.*server_name[[:space:]]*\([^;]*\);.*/\1/' | tr -d ' ')
        SUB_PATH=$(grep "location = " /etc/nginx/sites-available/simplehost | head -1 | sed 's/.*location = \/\([^ /]*\).*/\1/')
        if [ -n "$DOMAIN" ] && [ -n "$SUB_PATH" ]; then
            echo "  Subscription URL:"
            echo "  http://$DOMAIN/$SUB_PATH"
        else
            echo "  Not installed yet. Run First install [1]."
        fi
    else
        echo "  Not installed yet. Run First install [1]."
    fi
    echo ""
    read -p "  Press Enter to continue... " _
}

toggle_proxy() {
    cd $INSTALL_DIR
    echo ""
    if [ -f proxy.txt ] && [ -s proxy.txt ]; then
        echo "  Proxy is ON"
        read -p "  Disable proxy? (y/n): " DIS
        if [ "$DIS" = "y" ]; then
            rm -f proxy.txt
            echo "  → Proxy disabled"
        fi
    else
        echo "  Proxy is OFF."
        read -p "  Enable SOCKS5 proxy? (y/n): " ENA
        if [ "$ENA" = "y" ]; then
            echo "  Format: ip:port  OR  ip:port:user:password"
            read -p "  Enter SOCKS5 proxy: " PROXY
            if [ -n "$PROXY" ]; then
                echo "$PROXY" > proxy.txt
                echo "  → Proxy enabled"
            fi
        fi
    fi
    echo ""
}

# ===============================
# MENU
# ===============================
clear_menu() {
    clear
}

print_header() {
    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│              ConfuseRKN 1.0             │"
    echo "└─────────────────────────────────────────┘"
    echo ""
    echo "  Project by GoodbyeWL. Thanks for participating in the fight for open and free internet."
    echo "  Sources: EtoNeYaProject, BypassWhitelistRu (LowiKLive) — fighting Roskomnadzor, helping users browse as before."
    echo "  Updates: GitHub gbwltg/ConfuseRKN | Telegram @GoodbyeWLAlt"
    echo ""
}

print_menu() {
    echo "  [1]  First install"
    echo "  [2]  Run parser now"
    echo "  [3]  Edit sources"
    echo "  [4]  Change subscription path"
    echo "  [5]  Toggle proxy"
    echo "  [6]  Show subscription URL"
    echo "  [7]  Remove a source"
    echo "  [0]  Exit"
    echo ""
}

while true; do
    clear_menu
    print_header
    print_menu
    read -p "  Select option: " OPTION

    case $OPTION in
        1) install_stack ;;
        2) run_parser ;;
        3) edit_sources ;;
        4) change_subpath ;;
        5) toggle_proxy ;;
        6) show_subscription_url ;;
        7) remove_source ;;
        0) echo ""; echo "  Goodbye."; echo ""; exit 0 ;;
        *) echo ""; echo "  Invalid option. Press Enter..."; read ;;
    esac
done
