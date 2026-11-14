# SSH Remote Access (VPN-only)

Modul Magisk / KernelSU / KernelSU Next / APatch (arm64). Dropbear SSH sebagai root, login hanya pakai key, hanya bisa diakses lewat interface VPN.

## Pasang
1. Pasang app Tailscale atau WireGuard di HP, connect.
2. Ambil zip dari Releases, flash lewat root manager.
3. Taruh public key di `/sdcard/sshvpn_authorized_keys` sebelum flash, atau isi lewat WebUI.
4. Reboot. Login: `ssh root@<ip-vpn> -p 2222`. File: `scp -O` (dropbear tidak punya sftp-server).

## Cara kerja
- `sshvpn.sh supervise` jalan saat boot, memantau interface di `IFACES` dan restart dropbear kalau IP berubah.
- Dropbear di-bind ke IP interface VPN, plus chain iptables/ip6tables `SSHVPN` yang menerima port SSH hanya dari interface tersebut.
- Data di `/data/adb/sshvpn` (config, keys, host key, log). Tombol Action menjalankan restart + status.

## Config (`/data/adb/sshvpn/sshvpn.conf`)
`PORT` `IFACES` `BIND` (`iface`|`all`) `IDLE` `ALLOW_FWD`. Nama interface Tailscale di Android bisa beda, cek dengan `ip -br a`.

## Build
Push tag `v*`, GitHub Actions build dropbear dengan NDK, bikin zip, rilis, dan update `update.json`. Lokal: `bash scripts/build-dropbear.sh && bash scripts/package.sh v0.1.0 1 owner/repo`.
Versi dropbear di workflow (`2025.88`) perlu dicek ada di matt.ucc.asn.au/dropbear/releases.
