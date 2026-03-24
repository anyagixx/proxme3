# ProxMe3 - Sing-box Proxy Scripts (English Version)

> Fork of [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) with full English translation and additional features.

---

## What's New in This Fork

- ✅ **Full English translation** - All Chinese text translated to English
- ✅ **User Management** - Add/delete users with share links generation (Menu item 17)
- ✅ **Multi-user support** - Create multiple users for all 4 protocols
- ✅ **Dumbproxy Integration** - Simple HTTPS proxy with auto SSL certificate for IP (Menu item 18)
- ✅ **SOCKS5 Proxy** - Built-in SOCKS5 proxy for Telegram via Sing-box (Menu item 19)

---

## Overview

### 1. Sing-box-yg One-Click Four-Protocol Coexistence Script (VPS Edition)
### 2. Serv00/Hostuno-sb-yg Multi-Platform One-Click Three-Protocol Coexistence Script

**Note:** All subscription nodes are generated locally. No third-party converters used.

---

## 1. VPS Edition - Four Protocols

**Supported Protocols:**
- Vless-reality-vision
- Vmess-ws(tls)/Argo
- Hysteria-2
- Tuic-v5

**Features:**
- IPv4, IPv6, and dual-stack support
- AMD64 and ARM64 architectures
- Alpine Linux support
- Recommended: Ubuntu

### Installation:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/sb.sh)
```

---

## 2. Serv00/Hostuno Edition - Three Protocols

**Supported Protocols:**
- Vless-reality
- Vmess-ws(argo)
- Hysteria2

### Installation:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00.sh)
```

---

## Menu Options (sb.sh)

| # | Function |
|---|----------|
| 1 | Install Sing-box |
| 2 | Uninstall Sing-box |
| 3 | Change config (certificates, UUID, Argo, IP priority, etc.) |
| 4 | Change ports |
| 5 | Domain routing |
| 6 | Stop/Restart service |
| 7 | Update script |
| 8 | Update kernel |
| 9 | View nodes & subscriptions |
| 10 | View logs |
| 11 | BBR acceleration |
| 12 | ACME certificates |
| 13 | Warp management |
| 14 | WARP-plus-Socks5 proxy |
| 15 | Refresh IP |
| 16 | User manual |
| **17** | **User management (add/delete users)** |
| **18** | **Dumbproxy HTTPS proxy (simple proxy with auto SSL)** |
| **19** | **SOCKS5 proxy for Telegram (via Sing-box)** |
| **20** | **MTProto proxy for Telegram (via Docker)** |
| **21** | **TURN Proxy (bypass censorship via VK/Yandex)** |

---

## Dumbproxy (Menu item 18)

Simple HTTPS proxy with automatic SSL certificate for your server IP.

**Features:**
- Auto-generated password
- Let's Encrypt certificate for IP address
- Port 8443 (non-conflicting with Sing-box)
- Easy credential display

**Usage:**
1. Install via menu item 18
2. Get credentials: `https://auto:PASSWORD@YOUR_IP:8443`
3. Configure in browser/app as HTTPS proxy

---

## SOCKS5 Proxy (Menu item 19)

Built-in SOCKS5 proxy for Telegram and other apps.

**Features:**
- No additional installation needed (uses Sing-box)
- Auto-generated credentials
- Port 1080 (customizable)
- **Multi-user support** - add multiple users on same port
- Works with Telegram, browsers, and any SOCKS5-compatible app

**Telegram Setup:**
1. Enable SOCKS5 via menu item 19
2. Get credentials or add new users
3. In Telegram: Settings → Data and Storage → Proxy → Add SOCKS5
4. Enter: Server, Port, Username, Password

**User Management:**
- Menu 19 → Option 4: Manage SOCKS5 users
- Add multiple users (all use same port 1080)
- Delete users (minimum 1 user required)

**Usage:**
```
SOCKS5 URL: socks5://USER:PASS@YOUR_IP:1080
```

---

## MTProto Proxy (Menu item 20)

MTProto proxy specifically designed for Telegram using Docker.

**Features:**
- Official Telegram MTProto proxy via Docker
- Auto-generated secret key
- Fake TLS masking (configurable domain)
- Port 443 by default (customizable)
- Supports Alpine Linux (OpenRC)

**Domain Options:**
- google.com (default)
- cloudflare.com
- microsoft.com
- apple.com
- amazon.com
- github.com
- Custom domain

**Telegram Setup:**
1. Install via menu item 20
2. Click the generated `tg://proxy?` link to auto-configure
3. Or manually add in Telegram: Settings → Data and Storage → Proxy → Add Proxy → MTProto

**Usage:**
```
MTProto Link: tg://proxy?server=YOUR_IP&port=443&secret=SECRET

Manual:
  Server: YOUR_IP
  Port: 443
  Secret: (auto-generated hex string)
```

---

## TURN Proxy (Menu item 21)

Bypass censorship by tunneling WireGuard traffic through VK Calls or Yandex Telemost TURN servers.

**How it works:**
```
[Client] --DTLS--> [TURN Server VK/Yandex] --UDP--> [Your VPS] --> [WireGuard] --> Internet
```

**Features:**
- Auto-install WireGuard if not present
- Auto-generated WireGuard keys
- Support for both VK Calls and Yandex Telemost
- Full Alpine Linux support (OpenRC)
- Complete client setup instructions

**VK Calls vs Yandex Telemost:**

| Feature | VK Calls | Yandex Telemost |
|---------|----------|-----------------|
| Speed | ~5 Mbps | No limit |
| Threads | 1 (risk of ban) | Multiple OK |
| Link source | Create or find online | Create at telemost.yandex.ru |

**Installation:**
1. Menu 21 → Option 1 (VK) or Option 2 (Yandex)
2. Server automatically configured with WireGuard
3. Follow displayed client instructions

**Client Setup:**
1. Download client from: https://github.com/cacggghp/vk-turn-proxy/releases
2. Get a VK/Yandex call link
3. Run client:
   ```bash
   # VK
   ./client-linux -peer YOUR_VPS_IP:56000 -vk-link "https://vk.com/call/join/xxx" -listen 127.0.0.1:9000
   
   # Yandex
   ./client-linux -udp -turn 5.255.211.241 -peer YOUR_VPS_IP:56000 -yandex-link "https://telemost.yandex.ru/j/xxx" -listen 127.0.0.1:9000
   ```
4. Configure WireGuard client with provided config
5. **Important:** Add VPN client app to WireGuard exclusions!

**WireGuard Client Config:**
```
[Interface]
PrivateKey = (auto-generated)
Address = 10.20.0.2/24
MTU = 1280
DNS = 8.8.8.8

[Peer]
PublicKey = (server public key)
Endpoint = 127.0.0.1:9000
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

---

## Credits

**Original Author:** [yonggekkk](https://github.com/yonggekkk)

**Dumbproxy:** [SenseUnit/dumbproxy](https://github.com/SenseUnit/dumbproxy)

**Fork Maintainer:** [anyagixx](https://github.com/anyagixx)

---

## License

See [LICENSE](LICENSE) file.
