## v0.2.0
- Fix: modul menonaktifkan dirinya sendiri (`disable`) kalau zip tidak berisi binary `dropbear`/`dropbearkey`/`scp`, jadi tidak lagi "terpasang tapi tidak jalan".
- Fix: `status` sekarang punya field `bins=` (ok / hilang:<nama>) dan `reason=` yang menjelaskan penyebab `running=0` (binary hilang, keys kosong, VPN belum aktif, dihentikan manual, siap start).
- Fix: log mencatat path lengkap saat binary tidak ditemukan.
- Fix: `service.sh` memastikan supervisor hidup lagi (fallback setelah 20 detik).
- Fix: WebUI menampilkan baris *Binary* dan alasan status.
- Fix: `package.sh` gagal keras kalau binary belum dibuild (tidak ada lagi zip tanpa binary).
- Fix: workflow memverifikasi zip berisi `dropbear`, `dropbearkey`, `scp` dan `dropbear` benar-benar ELF arm64 sebelum rilis.
- Fix: installer meng-import public key dengan `base64 -w0` dan menghapus file sementara setelah import.
- Docs: README ditulis ulang — tutorial lengkap HP (Termux) + laptop (PowerShell/CMD), cara pilih zip Releases yang benar, scp `-O`, troubleshooting.
- Build: dropbear dinaikkan ke `2026.94`.

## v0.1.0
- Rilis awal: dropbear root key-only, bind ke IP interface VPN (Tailscale/WireGuard app)
- Firewall iptables/ip6tables (chain SSHVPN) + supervisor yang memantau interface
- WebUI (KernelSU / KernelSU Next / APatch / MMRL): status, keys, pengaturan, log
- Kompatibel Magisk, KernelSU, KernelSU Next, APatch (arm64)