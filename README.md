# SSH Remote Access (VPN-only)

Modul **Magisk / KernelSU / KernelSU Next / APatch** (arm64) yang menjalankan **Dropbear SSH sebagai root** di HP, tapi port SSH **hanya dibuka lewat interface VPN** (Tailscale / WireGuard). Dari luar VPN, port-nya tertutup oleh iptables.

Login **hanya pakai key** (password dimatikan). Cocok untuk akses HP dari laptop tanpa mengekspos port ke internet.

---

## ⬇️ Yang harus diunduh

Buka **[Releases](../../releases/latest)** → pada rilis terbaru, bagian **Assets** → unduh file:

```
SSH-Remote-Access-vX.Y.Z.zip
```

> ❌ **JANGAN** unduh `Source code (zip)` / `Source code (tar.gz)`.
> Itu isi repo (ada folder `module/`, tanpa binary `dropbear`), bukan paket modul.
> Kalau salah unduh, modul terpasang tapi SSH tidak akan pernah jalan (di log muncul `dropbear tidak ada`).
>
> Modul sekarang **mendeteksi** zip yang salah dan **menonaktifkan dirinya sendiri** (membuat file `disable`) supaya tidak bingung. ZIP dari Releases selalu berisi binary `dropbear`, `dropbearkey`, `scp` untuk arm64.

Cara cepat cek zip benar sebelum flash (opsional, di Termux):

```sh
unzip -l ~/storage/downloads/SSH-Remote-Access-v0.2.0.zip | grep -E 'dropbear|dropbearkey|scp'
```

Kalau ketiga binary muncul di daftar → zip benar.

---

# Tutorial lengkap

Ada dua sisi: **HP** dan **laptop**. VPN harus tersambung di keduanya dan berada di jaringan yang sama.

## Ringkasan alur

```
[Laptop] buat SSH key  →  tempel public key ke HP  →  flash modul  →  reboot
        ↓
[HP] connect VPN (Tailscale/WireGuard) → dropbear listen di IP VPN:2222
        ↓
[Laptop] connect VPN yang sama → ssh root@<ip-vpn> -p 2222
```

---

## 1. Laptop: buat SSH key

Pilih salah satu sesuai shell yang kamu pakai.

### PowerShell

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\hp_key"
Get-Content "$env:USERPROFILE\.ssh\hp_key.pub"
```

### CMD

```cmd
ssh-keygen -t ed25519 -f "%USERPROFILE%\.ssh\hp_key"
type "%USERPROFILE%\.ssh\hp_key.pub"
```

Tekan **Enter** saat diminta passphrase (boleh juga diisi). Kalau diminta overwrite, berarti key sudah ada — pakai yang lama atau hapus dulu.

Output `type`/`Get-Content` menghasilkan **satu baris** diawali `ssh-ed25519 AAAA...`. Itu **public key** — salin seluruh barisnya untuk langkah berikutnya.

> File `hp_key` = **private key** (rahasia, jangan dibagikan, jangan ditaruh di HP).
> File `hp_key.pub` = **public key** (ini yang ditaruh di HP).

---

## 2. HP: siapkan VPN dan cek nama interface

1. Pasang **Tailscale** (paling mudah) atau **WireGuard** di HP.
2. Login dan **connect**.
3. Cek nama interface VPN. Di **Termux**:

```sh
su -c 'ip -br addr'
```

Cari baris yang punya IP VPN:

- Tailscale → biasanya interface `tailscale0`, IP `100.x.x.x`
- WireGuard / VPN lain → biasanya `tun0`, `tun1`, `wg0`, IP `10.x.x.x` atau `172.x.x.x`

Kalau ragu, catat saja semua nama yang muncul (mis. `tun1`, `tailscale0`, `wg0`).

> Di Android, nama interface bisa berbeda-beda tergantung app VPN. `tun0` sering dipakai app lain; Tailscale memakai `tailscale0`.

---

## 3. HP: taruh public key (pilih salah satu)

### Cara A — sebelum flash (paling praktis)

Simpan public key ke `/sdcard/sshvpn_authorized_keys`, satu baris:

**Termux:**
```sh
nano /sdcard/sshvpn_authorized_keys
# paste public key, lalu Ctrl+O Enter, Ctrl+X
```

**PowerShell** (kalau HP tersambung lewat ADB):
```powershell
Get-Content "$env:USERPROFILE\.ssh\hp_key.pub" | Out-File -Encoding ascii "$env:TEMP\ak.txt"
adb push "$env:TEMP\ak.txt" /sdcard/sshvpn_authorized_keys
```

**CMD** (ADB):
```cmd
type "%USERPROFILE%\.ssh\hp_key.pub" > "%TEMP%\ak.txt"
adb push "%TEMP%\ak.txt" /sdcard/sshvpn_authorized_keys
```

Installer akan meng-import-nya otomatis lalu **menghapus** file sementara itu.

### Cara B — lewat WebUI setelah flash

1. Buka **KernelSU Next → Modules → SSH Remote Access →** tombol **WebUI** (atau tombol **Action**).
2. Tempel public key di kolom *Authorized keys*.
3. Tekan **Simpan keys** (otomatis restart).

### Cara C — lewat Termux (tanpa WebUI)

```sh
# isi file dulu
nano /sdcard/sshvpn_authorized_keys

# import ke modul
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh keys-set "$(base64 -w0 /sdcard/sshvpn_authorized_keys)"'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh restart'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh status'
```

Harus muncul `keys=1` (atau lebih).

---

## 4. HP: flash modul

1. Buka **KernelSU Next → Modules → Install from storage** (atau *Install from file*).
2. Pilih `SSH-Remote-Access-vX.Y.Z.zip` dari langkah ⬇️.
3. Tunggu selesai, lalu **reboot**.

Setelah reboot, modul otomatis:
- menyalakan supervisor (`sshvpn.sh supervise`) yang memantau interface VPN
- membuat host key
- membuka firewall chain `SSHVPN`
- men-start dropbear begitu interface VPN punya IP

---

## 5. HP: verifikasi status

Di **Termux**:

```sh
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh status'
```

Contoh output sehat:

```
running=1
stopped=0
sup=1
port=2222
bind=iface
ifaces=tailscale0 wg0 tun0
idle=600
fwd=0
up=tun1=100.73.20.92      ← interface VPN aktif
bound=100.73.20.92        ← dropbear listen di IP ini
keys=1
fp=SHA256:xxxx            ← fingerprint host key
bins=ok
reason=berjalan
```

Arti field penting:

| Field | Arti |
|---|---|
| `running=1` | dropbear jalan |
| `bound` | IP VPN tempat SSH listen (alamat yang dipakai `ssh`) |
| `keys` | jumlah public key yang sah |
| `bins` | `ok` atau `hilang:<nama>` (zip salah) |
| `reason` | penjelasan singkat kalau belum jalan |

### Kalau `running=0`, lihat `reason=`

| reason | Penyebab | Solusi |
|---|---|---|
| `binary hilang:...` | zip bukan dari Releases | flash ulang zip Releases |
| `authorized_keys kosong` | public key belum masuk | isi lewat WebUI / Cara C |
| `menunggu interface VPN (...) aktif` | VPN belum connect / nama iface salah | connect VPN, atau betulkan `IFACES` |
| `dihentikan manual` | pernah Stop | `sshvpn.sh start` |
| `siap start` | kondisi sudah oke | `sshvpn.sh restart` |

Lihat juga log:

```sh
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh log | tail -n 20'
```

---

## 6. HP: betulkan nama interface VPN (kalau perlu)

Default: `IFACES="tailscale0 wg0 tun0"`. Kalau interface HP-mu beda (mis. `tun1`), set ulang.

**WebUI:** ubah field *Interface VPN* → **Simpan dan restart**.

**Termux:**
```sh
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh conf-set IFACES "tun1 tailscale0"'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh restart'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh status'
```

Pakai beberapa nama sekaligus aman — script memakai interface mana pun yang punya IPv4.

Ubah port juga bisa:
```sh
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh conf-set PORT 2222'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh restart'
```

---

## 7. Laptop: connect VPN yang sama

Pasang **Tailscale** atau **WireGuard** di laptop dengan **akun yang sama** seperti HP, lalu connect.

Cek kedua perangkat saling terlihat:

```powershell
tailscale status
```

Cari IP HP (mis. `100.73.20.92`). Itu alamat tujuan SSH.

> Alamat untuk `ssh` harus IP **interface VPN** — sama dengan nilai `bound=` di status HP. Kalau VPN-mu IP `10.x.x.x`, jangan pakai `100.x.x.x`.

---

## 8. Laptop: SSH ke HP

### PowerShell

```powershell
ssh -i "$env:USERPROFILE\.ssh\hp_key" root@100.73.20.92 -p 2222
```

### CMD

```cmd
ssh -i "%USERPROFILE%\.ssh\hp_key" root@100.73.20.92 -p 2222
```

> Di CMD variabel environment ditulis `%USERPROFILE%`, **bukan** `$env:USERPROFILE`. Menjalankan sintaks PowerShell di CMD menghasilkan:
> `Warning: Identity file $env:USERPROFILE\.ssh\hp_key not accessible`

Ganti `100.73.20.92` dengan IP VPN HP-mu. Saat pertama connect akan muncul pertanyaan fingerprint — bandingkan dengan `fp=` di status HP, lalu ketik `yes`.

Kalau berhasil, prompt jadi `#` (root).

### Tanpa `-i` (pakai ~/.ssh/config) — opsional

Buat `%USERPROFILE%\.ssh\config` (PowerShell):

```powershell
@"
Host hp
    HostName 100.73.20.92
    Port 2222
    User root
    IdentityFile ~/.ssh/hp_key
    IdentitiesOnly yes
"@ | Add-Content "$env:USERPROFILE\.ssh\config"
```

Setelah itu cukup:

```powershell
ssh hp
```

---

## 9. Kirim/ambil file (scp)

Dropbear tidak menyertakan `sftp-server`, jadi **wajib** pakai `-O` (protokol scp lama). Tanpa `-O` akan error `subsystem request failed` / `does not support sftp`.

### PowerShell — kirim ke HP

```powershell
scp -O -P 2222 -i "$env:USERPROFILE\.ssh\hp_key" C:\Users\user\Downloads\file.txt root@100.73.20.92:/sdcard/
```

### PowerShell — ambil dari HP

```powershell
scp -O -P 2222 -i "$env:USERPROFILE\.ssh\hp_key" root@100.73.20.92:/sdcard/foto.jpg .
```

### CMD

```cmd
scp -O -P 2222 -i "%USERPROFILE%\.ssh\hp_key" C:\file.txt root@100.73.20.92:/sdcard/
scp -O -P 2222 -i "%USERPROFILE%\.ssh\hp_key" root@100.73.20.92:/sdcard/foto.jpg .
```

Catatan: `-P` (huruf besar) untuk port di `scp`; `ssh` memakai `-p` (huruf kecil).

Alternatif tanpa scp — lewat SSH biasa:

```powershell
# kirim
Get-Content C:\file.txt -Raw | ssh -i "$env:USERPROFILE\.ssh\hp_key" root@100.73.20.92 -p 2222 "cat > /sdcard/file.txt"

# ambil
ssh -i "$env:USERPROFILE\.ssh\hp_key" root@100.73.20.92 -p 2222 "cat /sdcard/file.txt" > file.txt
```

---

## 10. Perintah harian di Termux

```sh
# jalan / restart / stop
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh start'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh restart'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh stop'

# status & log
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh status'
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh log | tail -n 40'

# lihat key yang terpasang
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh keys-get'

# fingerprint host key (untuk dicocokkan saat ssh pertama kali)
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh status | grep fp='

# firewall yang dipasang modul
su -c 'iptables -S SSHVPN'

# cek port sedang listen di IP VPN
su -c 'ss -ltnp | grep 2222'

# hapus semua (matikan + hapus data)
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh teardown'
```

Membersihkan known_hosts di laptop kalau host key berubah (setelah hapus data modul):

```powershell
ssh-keygen -R "[100.73.20.92]:2222"
```

```cmd
ssh-keygen -R "[100.73.20.92]:2222"
```

---

## Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| `Identity file ... not accessible` | sintaks PowerShell dipakai di CMD | pakai `%USERPROFILE%` di CMD |
| `Connection timed out` | HP belum listen / beda jaringan VPN / port tertutup firewall | cek `status`: harus `running=1` & `bound=<ip>`; cek `tailscale status` |
| `Connection refused` | dropbear mati walau VPN aktif | `sshvpn.sh log`, cek `reason=` |
| `Permission denied (publickey)` | public key belum cocok | `keys-get` di HP vs isi `hp_key.pub` di laptop |
| `Host key verification failed` | host key HP berubah | `ssh-keygen -R "[ip]:2222"` lalu ssh lagi |
| `subsystem request failed` / sftp error | scp tanpa `-O` | tambahkan `-O` |
| Log penuh `dropbear tidak ada` | zip salah (Source code) | unduh `SSH-Remote-Access-vX.Y.Z.zip` dari Releases |
| `running=0`, `reason=menunggu interface VPN` | nama iface salah | `conf-set IFACES "<nama>"` lalu restart |
| SSH jalan tapi putus saat layar mati | Android mematikan app VPN | matikan optimasi baterai untuk app VPN, aktifkan always-on VPN |

---

## Config (`/data/adb/sshvpn/sshvpn.conf`)

```sh
PORT="2222"                        # port SSH (1024-65535)
IFACES="tailscale0 wg0 tun0"       # interface VPN yang dipantau
BIND="iface"                       # iface = hanya IP VPN (aman) | all = semua IP, dibatasi iptables
IDLE="600"                         # putuskan sesi idle (detik), 0 = mati
ALLOW_FWD="0"                      # 1 = izinkan port forwarding / tunneling
```

Ubah lewat WebUI atau:
```sh
su -c 'sh /data/adb/modules/sshvpn/sshvpn.sh conf-set KEY VALUE'
```

Data & log ada di `/data/adb/sshvpn/` (`ssh/authorized_keys`, `dropbear_ed25519_host_key`, `sshvpn.log`).

---

## Cara kerja

- `service.sh` jalan saat boot → menyalakan `sshvpn.sh supervise`.
- `supervise` memeriksa tiap 15 detik: interface VPN mana yang punya IP, lalu start/restart dropbear kalau IP berubah; juga memastikan firewall tetap terpasang.
- Dropbear di-bind ke **IP interface VPN** (`-p <ip>:<port>`), bukan `0.0.0.0`.
- Chain `iptables`/`ip6tables` bernama `SSHVPN` menerima port SSH **hanya** dari interface VPN, lalu `DROP` sisanya.
- Tanpa authorized_keys, dropbear tidak dijalankan sama sekali (tidak ada jalan masuk tanpa key).

---

## Build dari source (kontributor)

Butuh Linux/macOS + Android NDK. Binary tidak disimpan di git (`module/dropbear*`, `module/scp` di-.gitignore).

```sh
export ANDROID_NDK_HOME=/path/to/ndk
bash scripts/build-dropbear.sh                        # build dropbear + dropbearkey + scp (arm64)
bash scripts/package.sh v0.2.0 2 Ryhandd/SSH-Remote-Access   # -> dist/SSH-Remote-Access-v0.2.0.zip
```

Rilis otomatis: push tag `v*` → GitHub Actions build binary dengan NDK, memverifikasi zip berisi ELF arm64, membuat GitHub Release, lalu memperbarui `update.json`.

Versi dropbear diatur di `.github/workflows/release.yml` (`DROPBEAR_VERSION`, default `2026.94`) dan `scripts/build-dropbear.sh`.

---

## Lisensi & kredit

Dropbear SSH © Matt Johnston (MIT). Modul ini hanya membungkusnya untuk Android.