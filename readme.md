# Clean USB Debugging Magisk Module

Modul ini dibuat untuk mengatur ulang dan membersihkan konfigurasi **USB Debugging / Tethering** secara otomatis pada perangkat Android melalui Magisk.  
Cocok digunakan jika Anda mengalami masalah dengan **USB Debugging** atau ingin melakukan konfigurasi ulang setelah flashing / update sistem.

## Fitur
- Reset otomatis flag USB Debugging.
- Menjalankan skrip kustom pada tahap berbeda proses boot (`post-fs-data`, `post-boot`, `service`).
- Mendukung instalasi melalui Magisk Manager maupun Recovery.
- Dapat dihapus dengan aman menggunakan `uninstall.sh`.

## Struktur File
- **module.prop** — Informasi modul (nama, versi, deskripsi).
- **post-fs-data.sh** — Dieksekusi saat partisi `/data` sudah ter-mount.
- **post-boot.sh** — Berjalan setelah boot selesai.
- **service.sh** — Menjalankan service khusus di background.
- **customize.sh** — Kustomisasi saat proses instalasi.
- **reset_usb_debug_flag.sh** — Skrip untuk mereset flag USB Debugging.
- **uninstall.sh** — Skrip untuk menghapus modul ini.
- **META-INF/** — File pendukung untuk instalasi via Recovery.

## Cara Instalasi
1. Pastikan Magisk sudah terpasang di perangkat Anda.
2. Buka **Magisk Manager**.
3. Pilih **Install from Storage** dan arahkan ke file `<nama_file>.zip`.
4. Reboot perangkat setelah instalasi selesai.

## Cara Uninstall
1. Buka **Magisk Manager**.
2. Pilih modul. 
3. Reboot perangkat.

## Catatan
- Gunakan modul ini dengan hati-hati, khususnya jika Anda menggunakan USB Debugging untuk keperluan development.
- Disarankan melakukan backup sebelum instalasi.

## Lisensi
Modul ini dibagikan apa adanya, tanpa jaminan. Gunakan dengan risiko Anda sendiri.
