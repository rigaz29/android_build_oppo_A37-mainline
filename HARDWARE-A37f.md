# Inventaris hardware OPPO A37f

Semua isi dokumen ini dibaca **langsung dari unit fisik** lewat `adb` pada 18 Agustus 2026,
bukan dari spesifikasi pabrikan atau tebakan dari DTS. Unit yang dibaca menjalankan
LineageOS 22.2 (Android 15) dengan kernel downstream 3.10.108.

Skrip yang menghasilkannya: [`scripts/harvest-device-info.sh`](scripts/harvest-device-info.sh).

---

## Identitas

| Butir | Nilai |
|---|---|
| Model / device | `A37` / `A37f` |
| SoC | MSM8916 (Snapdragon 410), `soc_id` 206, revisi 1.0 |
| RAM | 1887 MB terbaca (2 GB terpasang) |
| eMMC | 15028 MB |
| Layar | 720×1280, density 280 |
| GPU | Adreno 306, GLES 3.0 (`ro.opengles.version` = 196608) |
| SIM | DSDS (dual SIM) |
| Kernel saat dibaca | `3.10.108-lineageos-g265ed1cfb35` |

### Identitas yang dipakai bootloader

```
/proc/device-tree/qcom,board-id  = 00000008 00000000 00003c27   ->  <8 0 15399>
/proc/device-tree/qcom,msm-id    = 206/0, 248/0, 249/0, 250/0
/proc/device-tree/model          = "Qualcomm Technologies, Inc. MSM 8916 MTP"
/proc/device-tree/compatible     = "qcom,msm8916-mtp", "qcom,msm8916", "qcom,mtp"
```

### Identitas dari SMEM (yang benar-benar dibandingkan bootloader)

```
/sys/devices/soc0/hw_platform          MTP
/sys/devices/soc0/platform_subtype_id  0
/sys/devices/soc0/platform_version     65536      (major 1, minor 0)
/sys/devices/soc0/soc_id               206
/sys/devices/soc0/revision             1.0
/sys/devices/soc0/raw_id               1797
```

**`platform_subtype_id` = 0.** A37f mengaku MTP generik, tanpa subtype unik — berbeda dari
Vivo Y21L yang memakai 13. Nomor proyek 15399 tidak muncul di SMEM sama sekali, jadi
pencocokan DTB standar tidak melihatnya. Ini yang menentukan bentuk entri lk2nd; lihat
[`lk2nd/README.md`](lk2nd/README.md).

`0x3c27` = 15399 = nomor proyek OPPO untuk A37. Perhatikan `qcom,board-id` punya **tiga
cell**, sedangkan format Qualcomm standar hanya dua (`<variant_id subtype_id>`) — OPPO
menambahkan nomor proyek di cell ketiga. Ini penting untuk entri lk2nd.

`msm-id` 248/249/250 adalah MSM8216/MSM8116/MSM8616, varian sekeluarga yang ikut
dicantumkan DTB pabrikan.

---

## Panel yang benar-benar terpasang

```
/sys/class/graphics/fb0/msm_fb_panel_info:
  panel_name=oppo15399boe ili9881c 720p video mode dsi panel
```

Unit ini memakai varian **BOE + Ilitek ILI9881C**, yaitu varian *primary* dari tiga yang
didukung firmware. Dua varian lain (Tianma NT35521S dan Truly NT35521S) ada di unit lain
dan dipilih lewat GPIO 109/114/119.

Konsekuensi: DTS di repo ini menargetkan varian BOE. Kalau nanti dipasang di unit dengan
panel berbeda, layar akan mati total sampai DTB yang cocok dipilih lk2nd.

---

## Cmdline dari bootloader

Dibaca dengan `adb root` (build `userdebug`, jadi tidak perlu `su`). Serial diredaksi.

```
sched_enable_hmp=1 androidboot.hardware=qcom ehci-hcd.park=3
androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1
ramoops.mem_address=0x9ff00000 ramoops.mem_size=0x400000 ramoops.record_size=0x40000
ramoops.console_size=0x100000 ramoops.pmsg_size=0x40000 ramoops.dump_oops=1 ramoops.ecc=1
androidboot.selinux=permissive androidboot.init_fatal_reboot_target=recovery
hung_task_panic=1 androidboot.emmc=true androidboot.serialno=<diredaksi>
androidboot.baseband=msm
mdss_mdp.panel=1:dsi:0:qcom,mdss_dsi_oppo15399boe_ili9881c_720p_video:1:none
inside_ldo androidboot.startupmode=pwrkey androidboot.mode=reboot lk_version=V1.0
```

Dua hal penting di sini:

**`mdss_mdp.panel=` dioper.** Nama node panelnya persis sama dengan yang dipakai entri
lk2nd, jadi `lk2nd,match-panel` punya bahan untuk bekerja. Ini menutup satu-satunya
pertanyaan terbuka di Fase 2.

**Wilayah ramoops sudah disiapkan bootloader** di `0x9ff00000`, 4 MB, dengan console 1 MB.
Berguna untuk Fase 3: kalau kernel mainline mati sebelum sempat bicara, log terakhirnya
bisa diambil dari sana lewat `lk2nd.pass-ramoops`.

---

## Touchscreen: dibaca langsung dari chip

Diverifikasi dengan `i2cget` ke `/dev/i2c-5` alamat `0x20`. Page Description Table
halaman 0, dipindai turun dari `0xE9` dengan entri 6 byte:

| Alamat | Fungsi | Query | Ctrl | Data | Arti |
|---|---|---|---|---|---|
| `0xE9` | **F34** | `0x87` | `0x4d` | — | flash / pembaruan firmware |
| `0xE3` | **F01** | `0x90` | `0x51` | `0x13` | kendali perangkat |
| `0xDD` | **F11** | `0xad` | `0x57` | `0x15` | sensor 2D |
| `0xD7` | `0x00` | | | | akhir PDT |

Query F01 byte 11–16 mengeja `s3203_` dalam ASCII (`0x73 0x33 0x32 0x30 0x33 0x5f`).
**Chip menjawab lewat protokol RMI4** — dukungan mainline untuk touchscreen A37f bukan
lagi asumsi, tapi hasil pengukuran.

Dua konsekuensi untuk DTS:

**Fungsi sensornya F11, bukan F12.** `msm8916-longcheer-l8150.dts` yang jadi rujukan
memakai F12, jadi bagian ini tidak bisa disalin mentah. Ikutannya: properti
`syna,no-pressure` dibuang, karena hanya `rmi_f12.c` yang membacanya.

**Tidak ada F1A, dan itu masuk akal.** F11 Ctrl6–9 melaporkan sensor maksimum
**1100 × 1900**, sedangkan DTS downstream menyebut area panel **1100 × 1745**. Selisih Y
1745–1900 adalah strip tiga tombol kapasitif di bawah layar. Jadi tombolnya memang bagian
dari permukaan sentuh, bukan fungsi tombol tersendiri — pemetaannya dilakukan di userspace
lewat `ts_vkeys`, persis seperti `mi8916`.

---

## Chip I²C: yang ada vs yang cuma tertulis di DT

Ini temuan paling berharga dari pembacaan device. DTS downstream mendaftarkan **semua**
varian pemasok pada bus sensor, jadi daftar node di DTS tidak bisa dipakai untuk
menyimpulkan apa yang terpasang. Yang menentukan adalah driver mana yang berhasil
*bind* — artinya chip-nya benar-benar menjawab di bus.

### Terpasang (driver ter-bind)

| Bus-alamat | Nama | Chip | Driver mainline |
|---|---|---|---|
| `0-0019` | lis3dh | ST LIS3DH, akselerometer | **ada** — `st,lis3dh-accel` |
| `0-0030` | mmc3416x | MEMSIC MMC3416x, magnetometer | **belum ada** |
| `0-0053` | apds9921 | Avago APDS9921, ALS + proximity | **belum ada** |
| `4-006b` | bq24196-charger | TI BQ24196, charger | **ada** — `ti,bq24196` |
| `5-0020` | synaptics-s3203 | Synaptics S3203, touchscreen | **ada** — `syna,rmi4-i2c` |
| `5-0038` | lm3630_bl | TI LM3630, backlight | **ada** — `ti,lm3630a` |
| `6-0060` | ts4621 | ST TS4621, fungsi belum teridentifikasi | — |

### Tertulis di DT tapi chip tidak ada

`ak8963` (0x0c), `kxtj9` (0x1f), `yas533` (0x2e), `stk3x1x` (0x48), `mpu6050` (0x68),
`ncp6335d-regulator` (1-001c), `nfc-nci` (6-000e).

Dua di antaranya penting:

- **`ncp6335d` tidak ter-bind.** Buck eksternal untuk VDD_APC tidak terpasang di unit ini,
  jadi tegangan inti CPU datang dari PMIC. Kebetulan menguntungkan: mainline msm8916 memang
  tidak mengatur VDD_APC per-device (`cpu_opp_table` tanpa `cpu-supply`), jadi tidak ada
  yang hilang.
- **`nfc-nci` tidak ter-bind.** A37f tidak punya NFC.

### Pemetaan bus

| Node Linux | Alamat register | Isi di A37f |
|---|---|---|
| `i2c-0` | BLSP1 QUP2 `78b6000` | sensor |
| `i2c-1` | BLSP1 QUP1 `78b5000` | (kosong — ncp6335d tidak ada) |
| `i2c-4` | BLSP1 QUP4 `78b8000` | charger BQ24196 |
| `i2c-5` | BLSP1 QUP5 `78b9000` | touchscreen + backlight |
| `i2c-6` | BLSP1 QUP6 `78ba000` | ts4621 |

---

## Input

```
/proc/bus/input/devices:
  synaptics-s3203        -> layar sentuh
  synaptics-s3203-kpd    -> tiga tombol kapasitif, dilaporkan kontroler sentuh sendiri
  compass                -> mmc3416x
  lis3dh-accel           -> lis3dh
  light / proximity      -> apds9921
  qpnp_pon               -> tombol power (PMIC)
  gpio-keys              -> volume up/down
  msm8x16-snd-card-mtp Button Jack -> tombol headset
```

Adanya `synaptics-s3203-kpd` sebagai input device terpisah menunjukkan tombol kapasitif
dilaporkan oleh kontroler sentuh, bukan lewat GPIO. Pembacaan PDT di atas memperjelas
caranya: bukan lewat fungsi F1A, melainkan dari strip sentuh Y 1745–1900 di bawah layar
yang disintesis driver jadi tombol.

---

## Daya

| Butir | Nilai |
|---|---|
| LED notifikasi | **tidak ada** — `/sys/class/leds/` hanya berisi `lcd-backlight` |
| Vibrator | ada, `/sys/class/timed_output/vibrator` (PMIC) |
| Charger | `POWER_SUPPLY_MODEL_NAME=OPCHARGER` (driver OPPO untuk BQ24196) |
| Baterai | Li-ion. Varian "high": 4,4 V / 2580 mAh (`qcom,fcc-mah`) |

Tabel OCV 31 titik di DTS dikonversi dari `qcom,pc-temp-ocv-lut` kolom 25 °C pada
`batterydata-oppo-4v4-2550mah-high-ATL.dtsi`. Satu titik non-monotonik pada 8 %
(3694 mV, lebih tinggi dari titik 9 %) dikoreksi manual jadi 3691 mV supaya
`simple-battery` menerimanya.

---

## Layout partisi

Total eMMC 15028 MB, skema lama (bukan A/B, bukan dynamic partition).

| Partisi | Blok | Ukuran |
|---|---|---|
| `boot` | `mmcblk0p22` | 32 MB |
| `recovery` | `mmcblk0p23` | 32 MB |
| `system` | `mmcblk0p24` | 2816 MB |
| `cache` | `mmcblk0p26` | 128 MB |
| `persist` | `mmcblk0p27` | 32 MB |
| `userdata` | `mmcblk0p38` | 11404 MB |
| `modem` | `mmcblk0p1` | 64 MB |

Partisi lain: `aboot`/`abootbak`, `hyp`/`hypbak`, `rpm`, `tz`, `sbl1`, `fsg`, `fsc`,
`modemst1`/`modemst2`, `misc`, `devinfo`, `keystore`, `config`, `oem`, `LOGO`, `DRIVER`,
`DDR`, `oppodycnvbk`, `oppostanvbk`, `reserve1`–`reserve4`, `reserve_exp1`.

**Ini posisi yang jauh lebih longgar daripada perangkat rujukan.** Redmi 2 (`mi8916`,
satu-satunya target msm8916 mainline resmi) harus menaruh `/system` di partisi `userdata`
dan memindahkan `/data` ke kartu SD karena partisinya terlalu sempit. A37f tidak perlu
akrobat itu: `system` 2816 MB cukup untuk build 64-bit-only tanpa blob, dan `userdata`
11,4 GB tetap utuh untuk `/data`.

---

## Radio

| Butir | Nilai |
|---|---|
| Wi-Fi | WCNSS "prima", firmware `CNSS-PR-2-0-1-1-c1-2-11-99836-1`, hanya 2,4 GHz |
| Bluetooth | `vendor.qcom.bluetooth.soc = smd` (terpadu di WCNSS) |
| Iris | belum dibaca langsung; b/g/n tanpa 5 GHz mengarah ke **WCN3620** — perlu konfirmasi |

Di mainline keduanya ditangani `wcn36xx` + `wcnss_pil` + `btqca`, dengan varian iris
dideklarasikan di DTS (`&wcnss_iris { compatible = "qcom,wcn3620"; }`).
