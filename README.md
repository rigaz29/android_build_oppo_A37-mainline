# android_build_oppo_A37-mainline

Rencana porting **LineageOS 23.2 (Android 16)** ke **OPPO A37 / A37f** di atas **kernel
Linux mainline 6.19** — tanpa satu pun blob vendor OPPO.

Bukan kelanjutan dari [`android_build_oppo_A37-22`](https://github.com/rigaz29/android_build_oppo_A37-22).
Jalur ini membuang seluruh kernel downstream 3.10.108 dan seluruh 282 blob vendor, lalu
membangun ulang dari nol di atas kernel upstream dengan HAL sumber terbuka.

---

## Kenapa jalur ini ada

Kernel A37f sudah mentok. Diverifikasi lewat `git ls-remote` ke CodeLinaro: rilis CAF untuk
keluarga 8916 **hanya ada di kernel 3.10** — tag terakhir `LA.BR.1.3.1-01110-8x16.0`
(3.10.49). Repo msm-3.18 memang memuat 890 tag `8x16`, tapi **nol yang unik** (warisan
histori saat branching). Kernel yang dipakai sekarang, 3.10.108, sudah **di atas** plafon
CAF berkat merge LTS komunitas, dan 3.10.108 adalah rilis 3.10.y terakhir kernel.org
(EOL November 2017).

Artinya tidak ada versi kernel yang lebih tinggi untuk ditumpangi. Satu-satunya jalan naik
adalah keluar dari silsilah downstream sama sekali.

Itu ternyata mungkin: MSM8916 adalah **SoC family kelas satu** di stack mainline resmi
LineageOS, dan sudah ada target yang benar-benar boot — `mi8916` (Xiaomi Redmi 2) di
`LineageOS/android_device_xiaomi_mi89xx-mainline`.

---

## Isi

| Berkas | Keterangan |
|---|---|
| **[`PLAN-MAINLINE.md`](PLAN-MAINLINE.md)** | Dokumen utama. Sepuluh fase, dari prasyarat sampai instalasi, dengan kriteria lulus dan jalan pulang tiap fase |
| **[`HARDWARE-A37f.md`](HARDWARE-A37f.md)** | Inventaris hardware, dibaca langsung dari unit fisik lewat adb — bukan dari spesifikasi pabrikan |
| [`kernel/msm8916-oppo-a37.dts`](kernel/msm8916-oppo-a37.dts) | Draf device tree kernel mainline, 470 baris |
| [`kernel/panel/oppo-a37.sh`](kernel/panel/oppo-a37.sh) | Config generator driver panel untuk ketiga varian layar |
| [`lk2nd/`](lk2nd/) | Entri bootloader lk2nd sebagai patch untuk `msm8916-mtp.dts`, plus catatan koreksi desainnya. **Image sudah dibangun dan diverifikasi** |
| [`android/A37-mainline.xml`](android/A37-mainline.xml) | Local manifest, 16 project, semua repo diverifikasi ada di `lineage-23.2` |
| [`scripts/harvest-device-info.sh`](scripts/harvest-device-info.sh) | Skrip pembaca data hardware. Hanya membaca, tanpa root |

---

## Temuan yang menentukan kelayakan

**1. Touchscreen-nya Synaptics, bukan Goodix.** Ini pertaruhan terbesar proyek ini dan
hasilnya bagus. A37f memakai **Synaptics S3203** di i2c 0x20 — kontroler RMI4, dan
`drivers/input/rmi4` di mainline sudah lengkap (f01/f11/f12/f1a/f34/f54). Lebih dari itu,
`msm8916-longcheer-l8150.dts` yang sudah ada di kernel mainline punya node `rmi4@20` dengan
**alamat i2c, GPIO interrupt (13), dan vio-supply (pm8916_l6) yang sama persis**. Praktis
tinggal salin dan ganti `vdd-supply` ke `pm8916_l17`.

Bandingkan dengan nasib target SDM439 di repo resmi, yang README-nya menulis "almost all
of the touchscreen variants aren't supported in the kernel yet. You'll have to interact
with the device in other ways."

**2. Empat IC kunci sudah punya driver mainline.**

| Bagian | IC di A37f | Driver mainline |
|---|---|---|
| Touchscreen | Synaptics S3203 @0x20 | `syna,rmi4-i2c` |
| Panel | BOE ILI9881C (terpasang di unit ini) | `panel-ilitek-ili9881c.c` upstream |
| Backlight | TI LM3630 @0x38 | `lm3630a_bl.c` |
| Charger | TI BQ24196 @0x6b | `bq24190_charger.c` sudah punya entri `ti,bq24196` |

**3. Partisinya lebih longgar daripada perangkat rujukan.** Redmi 2 harus menaruh
`/system` di partisi `userdata` dan memindahkan `/data` ke kartu SD. A37f punya `system`
2816 MB dan `userdata` 11404 MB — tidak perlu akrobat itu.

**4. Daftar sensor di DTS downstream tidak bisa dipercaya.** Downstream mendaftarkan semua
varian pemasok sekaligus. Pembacaan `/sys/bus/i2c/devices` di unit fisik menunjukkan yang
benar-benar terpasang hanya **LIS3DH** (ada di mainline), **MMC3416x**, dan **APDS9921**
(dua terakhir belum ada di mainline). Sementara `kxtj9`, `yas533`, `stk3x1x`, `ak8963`,
`mpu6050`, dan `ncp6335d` yang tertulis di DT ternyata chip-nya tidak ada.

---

## Yang tidak akan berfungsi

Bukan keterbatasan A37f — tidak ada satu pun perangkat msm8916 mainline yang punya ini
hari ini:

- **Telepon, SMS, data seluler** — tidak ada RIL/radio HAL di seluruh tree mainline
  LineageOS. Plumbing modem (`q6v5_mss`, `rmtfs`, `qrtr`, `bam_dmux`) ada, lapisan
  Android-nya tidak
- **Kamera** — opsi `camera-provider-hal_libcamera` tersedia tapi belum diaktifkan untuk
  target msm8916 mana pun
- **Deep sleep** — `TARGET_SUPPORTS_SUSPEND := false` di device tree rujukan
- **Kompas, sensor cahaya, proximity** — chip-nya belum punya driver mainline

**ROM 22.2 tetap jadi sistem harian.** Ini proyek paralel, bukan pengganti.

---

## Status

| Bagian | Status |
|---|---|
| Riset kelayakan | selesai |
| Inventaris hardware | selesai, diverifikasi di perangkat |
| DTS kernel | draf ditulis, label eksternal diverifikasi, **belum dikompilasi** |
| Entri lk2nd | **dibangun, isi DTB dan tabel QCDT diverifikasi** — belum di-flash |
| Local manifest | ditulis, keberadaan semua repo diverifikasi |
| Device tree Android | belum dibuat (Fase 9) |
| Fase 0–10 | belum dijalankan |
