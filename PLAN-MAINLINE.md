# Rencana porting LineageOS mainline ke OPPO A37f

Dokumen kerja. Sepuluh fase, dari nol sampai ROM terpasang di perangkat.

Target akhir: **LineageOS 23.2 (Android 16) di atas kernel Linux mainline 6.19**, tanpa
satu pun blob vendor OPPO, di perangkat yang dirilis 2016 dengan SoC yang kernel
downstream-nya berhenti di 3.10.108.

---

## Ringkasan keputusan

| Hal | Keputusan | Alasan |
|---|---|---|
| Basis Android | LineageOS `lineage-23.2` | Branch tempat stack mainline resmi hidup |
| Kernel | `msm8916-mainline/linux`, branch `wip/msm8916/6.19` | Branch yang dipakai target `mi8916` resmi |
| Perangkat rujukan | `mi8916` (Redmi 2) di `LineageOS/android_device_xiaomi_mi89xx-mainline` | Satu-satunya target msm8916 mainline resmi |
| Rujukan DTS kernel | `msm8916-longcheer-l8150.dts` | Touchscreen RMI4 di alamat, GPIO IRQ, dan supply yang sama |
| Rujukan kartu SD | `msm8916-asus-z00l.dts` | `cd-gpios` di GPIO 38, sama persis dengan A37f |
| Validasi awal | postmarketOS, bukan Android | Siklus build hitungan menit, bukan jam |
| Arsitektur | 64-bit only | Bawaan stack mainline; tidak ada blob 32-bit yang perlu dipertahankan |
| Layout partisi | Tetap normal (`system` → system, `data` → userdata) | Partisi A37f cukup longgar, tidak perlu trik `/data` di SD seperti Redmi 2 |

## Apa yang tidak akan berfungsi

Perlu diterima sebelum menghabiskan waktu berminggu-minggu. Ini bukan keterbatasan A37f —
tidak ada satu pun perangkat msm8916 mainline yang punya fitur-fitur ini hari ini.

| Fitur | Status | Kenapa |
|---|---|---|
| Telepon, SMS, data seluler | **tidak ada** | Tidak ada RIL/radio HAL di seluruh tree mainline LineageOS. Plumbing modem (`q6v5_mss`, `rmtfs`, `qrtr`, `bam_dmux`) ada, lapisan Android-nya tidak |
| Kamera | **tidak ada** | Opsi `camera-provider-hal_libcamera` tersedia tapi belum diaktifkan untuk target msm8916 mana pun |
| Deep sleep | **dimatikan** | `TARGET_SUPPORTS_SUSPEND := false` di device tree rujukan; layar mati tetap boros |
| SELinux enforcing | **tidak** | Stack mainline masih `androidboot.selinux=permissive` |
| Magnetometer, sensor cahaya, proximity | **tidak ada** | Chip di A37f (MMC3416x, APDS9921) belum punya driver mainline — lihat Fase 9 |
| Speaker | **perlu kerja tambahan** | Amplifier eksternal TS4621 (enable GPIO 120, boost GPIO 118). Coba `simple-audio-amplifier` dulu; kalau gagal perlu port driver codec. Headset dan earpiece tidak terpengaruh |

Karena itu: **jangan buang ROM 22.2 yang sudah jalan.** Ini proyek paralel, bukan pengganti.

---

## Fase 0 — Prasyarat

**Tujuan:** tidak ada yang dimulai sebelum jalan pulang aman.

1. **Perangkat kedua.** A37f akan sering tidak bisa dipakai berhari-hari. Jangan pakai unit
   yang jadi HP harian.
2. **Kabel dan akses EDL.** Kalau `aboot` rusak, satu-satunya jalan pulang adalah EDL
   (mode 9008) + QFIL dengan firehose msm8916. Siapkan sebelum, bukan sesudah, ada masalah.
3. **Bootloader terbuka.** Verifikasi: `fastboot oem device-info`, atau cukup dengan
   berhasilnya `fastboot flash boot`. ROM 22.2 yang sudah terpasang membuktikan ini sudah
   beres.
4. **Host build.** Kernel + Android: 16 GB RAM, ~400 GB disk. Kernel mainline sendiri jauh
   lebih ringan (~10 GB, build 15 menit di 8 core).
5. **Toolchain.** Clang untuk kernel (AOSP prebuilt atau distro), `gcc-aarch64-linux-gnu`,
   `arm-none-eabi-gcc` untuk lk2nd, `dtc`, `mkbootimg`, `abootimg`.

**Kriteria lulus:** `fastboot devices` mengenali perangkat, dan kamu tahu persis cara
masuk EDL.

---

## Fase 1 — Amankan jalan pulang

**Tujuan:** apa pun yang rusak nanti, bisa dikembalikan.

```bash
# Dari TWRP/OrangeFox (repo android_build_oppo_A37-twrp), lewat adb shell:
for p in boot recovery system persist modem modemst1 modemst2 fsg fsc \
         aboot abootbak sbl1 rpm tz hyp devinfo oem config keystore misc; do
    dd if=/dev/block/bootdevice/by-name/$p of=/external_sd/backup-a37f/$p.img
done
```

Yang paling penting: **`persist`** (kalibrasi Wi-Fi/BT/sensor — tidak bisa dibuat ulang),
**`modemst1`/`modemst2`/`fsg`/`fsc`** (data NV modem — kalau hilang, IMEI hilang), dan
**`aboot`** (bootloader).

Simpan cadangan di luar perangkat. Verifikasi ukurannya sesuai
[`HARDWARE-A37f.md`](HARDWARE-A37f.md).

**Kriteria lulus:** cadangan `persist` dan `modemst*` ada di komputer, terverifikasi
ukurannya bukan nol.

---

## Fase 2 — lk2nd

**Status: image sudah dibangun dan diverifikasi. Belum di-flash.**

Bootloader OPPO tidak bisa memuat kernel mainline langsung. lk2nd dipasang di partisi
`boot`, lalu dia yang menyiapkan DTB dan menyerahkan kendali ke kernel.

```bash
git clone https://github.com/msm8916-mainline/lk2nd
cd lk2nd
git apply /path/to/lk2nd/0001-msm8916-mtp-tambahkan-OPPO-A37.patch
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc)
fastboot flash boot build-lk2nd-msm8916/lk2nd.img
```

Build selesai dalam ~4 detik, tanpa peringatan. Hasilnya 426.000 byte — partisi `boot`
A37f 32 MB, jadi muat sangat longgar.

**Satu koreksi desain terjadi di fase ini.** Draf awal membuat berkas DTB tersendiri untuk
A37. Ternyata salah: perangkat melaporkan `platform_subtype_id = 0`, artinya dia MTP
generik tanpa subtype unik. Ditambah `dtbTool` lk2nd membuang cell ketiga `qcom,board-id`
(`<8 0 15399>` menjadi `(8, 0)`), DTB tersendiri itu bertabrakan langsung dengan
`msm8916-mtp.dtb`. Perbaikannya: A37 jadi node anak di dalam `msm8916-mtp.dts` dan
dibedakan saat runtime — pola yang sudah dipakai Marshall London, Vodafone Smart prime 6,
dan dua perangkat Asus di berkas yang sama. Rincian dan cara verifikasinya di
[`lk2nd/README.md`](lk2nd/README.md).

**Mekanisme pencocokannya sudah dikonfirmasi.** `lk2nd,match-panel` bergantung pada
parameter `mdss_mdp.panel=` dari bootloader; dengan `adb root`, `/proc/cmdline` menunjukkan
parameter itu memang dioper dan nama nodenya persis sama dengan yang ada di entri lk2nd.

**Kriteria lulus:** perangkat boot ke lk2nd, `fastboot devices` mengenalinya, dan layar
atau log lk2nd menampilkan "OPPO A37".

**Jalan pulang:** `fastboot flash boot boot-22.2.img` mengembalikan ROM lama. lk2nd hanya
menempati partisi `boot`.

---

## Fase 3 — Kernel mainline boot pertama

**Tujuan:** kernel 6.19 hidup dan bicara, walau layar masih mati.

```bash
git clone -b wip/msm8916/6.19 https://github.com/msm8916-mainline/linux
cd linux
cp /path/to/kernel/msm8916-oppo-a37.dts arch/arm64/boot/dts/qcom/
echo 'dtb-$(CONFIG_ARCH_QCOM) += msm8916-oppo-a37.dtb' >> arch/arm64/boot/dts/qcom/Makefile

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- msm8916_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image.gz dtbs modules
```

DTS-nya ada di [`kernel/msm8916-oppo-a37.dts`](kernel/msm8916-oppo-a37.dts) — 470 baris,
seluruh GPIO dan supply sudah dipetakan dari DTS downstream dan diverifikasi terhadap
perangkat. Sudah dicek: 31 label eksternal yang dirujuknya semua ada di dtsi yang
di-include, dan kurungnya seimbang. **Belum pernah dikompilasi** — inilah pengujian
pertamanya.

Urutan debugging kalau tidak boot:

1. `dtc` gagal → kesalahan sintaks, perbaiki apa yang dikeluhkan
2. Boot tapi diam → aktifkan `CONFIG_SERIAL_MSM_CONSOLE`, sambungkan UART lewat jack
   headset (msm8916 mengeksposnya di sana), atau baca `ramoops` lewat lk2nd
   (`lk2nd.pass-ramoops=zap`)
3. Panic awal → cek `reserved-memory`; l8150 butuh penyesuaian alamat `wcnss_mem`/`mpss_mem`
   karena firmware wcnss-nya tidak relokatable. Kalau A37f kena hal serupa, salin polanya

**Kriteria lulus:** kernel mencetak log sampai `Freeing unused kernel memory`, dan
USB gadget muncul di host (`lsusb`).

---

## Fase 4 — Validasi cepat lewat postmarketOS

**Tujuan:** memangkas siklus percobaan dari jam ke menit.

Ini bukan langkah opsional dan bukan pengalihan. Fase 5 sampai 8 semuanya soal driver
kernel, dan menguji driver kernel dengan cara membangun ulang ROM Android setiap kali
adalah pemborosan waktu terbesar yang bisa dilakukan di proyek ini.

```bash
pmbootstrap init          # vendor: oppo, codename: a37
pmbootstrap install
pmbootstrap flasher flash_kernel
```

Buat paket device pmOS minimal (`device-oppo-a37`) yang menunjuk ke kernel dan DTB yang
sama. Semua pekerjaan Fase 5–8 dikerjakan di sini, baru hasilnya dibawa ke Android.

**Kriteria lulus:** shell postmarketOS lewat SSH atau serial.

---

## Fase 5 — Layar

**Tujuan:** panel menyala di kernel mainline.

Panel A37f varian BOE ILI9881C belum punya driver mainline. Drivernya dihasilkan otomatis
dari DTB downstream:

```bash
# 1. Kompilasi DTB downstream sebagai sumber data
cd /path/to/kernel_oppo_msm8939
make ARCH=arm msm8916-mtp-15399.dtb

# 2. Hasilkan driver panel
git clone --recursive https://github.com/msm8916-mainline/linux-panel-drivers
cp arch/arm/boot/dts/qcom/msm8916-mtp-15399.dtb linux-panel-drivers/dtb/
cp /path/to/kernel/panel/oppo-a37.sh linux-panel-drivers/config/
cd /path/to/linux   # pohon kernel mainline
/path/to/linux-panel-drivers/generate.sh
```

Config generatornya ada di [`kernel/panel/oppo-a37.sh`](kernel/panel/oppo-a37.sh), sudah
memetakan ketiga varian panel ke nama compatible yang dipakai DTS.

Unit yang dipakai riset ini memakai varian BOE — dua varian lain tetap dihasilkan supaya
DTS-nya bisa dipakai unit lain nanti.

**Kriteria lulus:** `/dev/dri/card0` ada, dan `modetest -s` menampilkan gambar.

---

## Fase 6 — Sentuh, tombol, penyimpanan, daya

**Tujuan:** perangkat bisa dioperasikan tanpa kabel.

Empat-empatnya sudah ditulis di DTS dan seharusnya jalan tanpa kode baru:

| Bagian | Node | Yang perlu dicek |
|---|---|---|
| Touchscreen | `syna,rmi4-i2c` @0x20, fungsi **F11** | Titik sentuh terbaca. Tombol kapasitif ada di strip Y 1745–1900 di luar area layar — pemetaannya lewat `ts_vkeys` di Fase 9, bukan di kernel |
| Tombol volume | `gpio-keys` TLMM 107/108 | Kalau volume-down mati, tukar ke `&pm8916_resin` |
| Kartu SD | `sdhc_2`, `cd-gpios` GPIO 38 | Deteksi kartu masuk/keluar |
| Baterai + charger | `ti,bq24196` @0x6b | Persentase masuk akal; pengisian jalan |

Backlight (`ti,lm3630a` @0x38) juga masuk fase ini — perhatikan bahwa downstream memakai
compatible `lm3630_bl` (varian tanpa A). Register map-nya sama, tapi ini yang paling
mungkin butuh penyesuaian.

**Kriteria lulus:** bisa menavigasi antarmuka pmOS dengan jari, membaca persentase baterai
yang benar, dan mengisi daya.

---

## Fase 7 — Wi-Fi, Bluetooth, audio

**Tujuan:** perangkat berguna sebagai komputer saku.

Ketiganya sudah didukung mainline msm8916 dan tidak butuh kode baru — hanya firmware dan
konfigurasi:

- **Wi-Fi:** `wcn36xx` + `wcnss_pil`. Butuh `WCNSS_qcom_wlan_nv.bin` dari partisi
  `persist` perangkat. Varian iris di DTS masih `wcn3620` — konfirmasi dari perangkat.
- **Bluetooth:** `btqca`. Alamat MAC diambil dari `persist` lewat tool `bdaddr`.
- **Audio:** `q6*` (ADSP lewat APR) + `snd_soc_apq8016_sbc`. Butuh berkas UCM ALSA;
  salin dari perangkat msm8916 sejenis di `msm8916-mainline/alsa-ucm-conf` lalu sesuaikan.
  **Speaker butuh kerja tambahan.** A37f punya amplifier eksternal TS4621 di i2c-6 0x60,
  dengan enable di GPIO 120 (`spk-pa-en`) dan boost di GPIO 118 (`yda145_boost-en`).
  Coba dulu `simple-audio-amplifier` pada GPIO 120 + regulator tetap untuk GPIO 118 —
  jauh lebih murah daripada menulis driver codec. Kalau chip tetap terkunci mute, barulah
  port `sound/soc/codecs/ts4621.c` (580 baris) dari kernel downstream. Earpiece dan headset
  lewat codec PMIC tidak terpengaruh dan seharusnya jalan lebih dulu.

**Kriteria lulus:** tersambung Wi-Fi, suara keluar dari headset. Speaker menyusul setelah
driver TS4621 ada.

---

## Fase 8 — Pindah ke LineageOS mainline

**Tujuan:** dari Linux biasa ke Android.

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2
cp android/A37-mainline.xml .repo/local_manifests/
repo sync -c -j8 --no-clone-bundle --no-tags
```

Manifest-nya ada di [`android/A37-mainline.xml`](android/A37-mainline.xml).

Kernel mainline butuh tiga patch Android yang tidak ada di upstream — diambil dari
`android-mainline` milik Google, didokumentasikan di README
`LineageOS/android_device_xiaomi_mi89xx-mainline`:

| Patch | Gunanya |
|---|---|
| `ANDROID: usb: gadget: configfs: Add Uevent to notify userspace` | USB di mode normal |
| `ANDROID: mm/memfd-ashmem-shim: Introduce shim layer` | Codec media |
| `ANDROID: mm: shmem: Use memfd-ashmem-shim ioctl handler` | Codec media |

Ditambah satu suntingan manual: di `mm/Kconfig`, hapus dependensi `ASHMEM_C` pada opsi
`MEMFD_ASHMEM_SHIM`.

**Kriteria lulus:** `repo sync` selesai bersih dan `breakfast a37_mainline` lolos.

---

## Fase 9 — Device tree Android

**Tujuan:** membungkus kernel yang sudah jalan jadi ROM.

Ini fase yang paling mudah, karena polanya tinggal disalin dari `mi8916`. Struktur yang
perlu dibuat di `device/oppo/a37-mainline/`:

```
BoardConfig.mk          TARGET_QCOM_SOC_FAMILY := msm8916
                        TARGET_KERNEL_SOURCE := kernel/mainline/msm8916-mainline
                        TARGET_DTB_LIST_WILDCARD := qcom/msm8916-oppo-a37
                        BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432      # 32 MB
                        BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432  # 32 MB
device.mk               TARGET_SUPPORTS_SUSPEND := false  (sementara)
lineage_a37_mainline.mk core_64_bit_only + full_base_telephony + common_full_phone
fstab/                  system, vendor, data, persist, metadata
modprobe/               modules.load.basic / .drm / .touchscreen / .normal
kconfigs/fixups.config  CONFIG_INTERCONNECT_QCOM_MSM8916=y, CONFIG_SUSPEND=y
overlays/               resolusi 720x1280, density 280
vintf/manifest.xml      kosong (tidak ada HAL vendor)
```

**Layout partisi — ini keunggulan A37f.** Perangkat rujukan `mi8916` harus menaruh
`/system` di partisi `userdata` dan memindahkan `/data` ke kartu SD karena partisinya
sempit. A37f tidak perlu: `system` 2816 MB cukup untuk build 64-bit-only tanpa blob, dan
`userdata` 11,4 GB tetap utuh. Karena tidak ada partisi `vendor`, pakai
`TARGET_COPY_OUT_VENDOR := system/vendor`.

Daftar modul kernel yang perlu dimuat, diturunkan dari inventaris hardware:

```
modules.load.drm         msm.ko, panel-oppo-a37-boe-ili9881c.ko
modules.load.touchscreen rmi_core.ko, rmi_i2c.ko
modules.load.basic       lm3630a_bl.ko, bq24190_charger.ko
modules.load.normal      wcn36xx, wcnss_ctrl, btqca, q6*, venus_*, pm8xxx_vibrator,
                         st_accel_i2c, qcom_q6v5_mss, qcom_wcnss_pil
```

**Kriteria lulus:** `brunch a37_mainline` menghasilkan zip.

---

## Fase 10 — Instalasi

**Tujuan:** ROM terpasang dan boot.

```bash
# 1. lk2nd sudah di partisi boot sejak Fase 2 — jangan ditimpa
# 2. Masuk fastboot lk2nd
fastboot flash system  out/target/product/a37_mainline/system.img
fastboot flash boot    out/target/product/a37_mainline/boot.img
fastboot erase userdata
fastboot erase cache
```

Catatan:

- **`persist` jangan disentuh.** Wi-Fi dan Bluetooth mengambil kalibrasi dari sana.
- **`modem` jangan dihapus.** Firmware modem tetap dimuat `q6v5_mss` walau tidak ada RIL,
  dan menghapusnya menghilangkan IMEI.
- Boot pertama akan lama (beberapa menit) dan SELinux permissive — ini normal untuk
  stack ini.

**Kriteria lulus:** masuk launcher, layar sentuh jalan, Wi-Fi tersambung.

**Jalan pulang:** flash balik `boot.img` dan `system.img` dari ROM 22.2, atau pulihkan
cadangan Fase 1.

---

## Setelah boot: pekerjaan lanjutan

Diurutkan dari yang paling berdampak:

1. **Driver magnetometer MMC3416x.** Chip terpasang, mainline hanya punya `mmc35240` yang
   register map-nya berbeda. Tanpa ini tidak ada kompas dan rotasi otomatis pincang.
2. **Driver ALS/proximity APDS9921.** Tanpa ini layar tidak mati saat menelepon — walau
   untuk sekarang memang tidak bisa menelepon.
3. **Deep sleep.** Menghapus `TARGET_SUPPORTS_SUSPEND := false` dan menguji. Ini yang
   memisahkan "mainan" dari "bisa dipakai sehari".
4. **Kirim DTS ke hulu.** `msm8916-mainline/linux` belum punya satu pun perangkat OPPO.
   A37 termasuk perangkat yang jumlah unitnya banyak, jadi kontribusinya berguna untuk
   orang lain.
5. **SELinux enforcing.** Setelah semuanya stabil.

---

## Pekerjaan yang tidak bergantung pada perangkat

Bisa dikerjakan kapan saja, tidak perlu menunggu fase sebelumnya:

- Menulis paket device postmarketOS (`device-oppo-a37`)
- Menyiapkan berkas UCM ALSA berdasarkan perangkat msm8916 sejenis
- Membaca `msm_fb_panel_info` unit lain untuk memastikan DTS varian Tianma dan Truly
