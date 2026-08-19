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
| `6-0060` | ts4621 | **Amplifier speaker eksternal** (class-D, dikontrol I²C) | **belum ada** |

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
| `i2c-6` | BLSP1 QUP6 `78ba000` | amplifier speaker TS4621 |

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

## GPIO: dari pinctrl downstream, disilangkan dengan `/proc/interrupts`

Grup pinctrl yang menyebut nomor pin secara eksplisit di `msm8916-pinctrl-15399.dtsi`:

| Grup | GPIO | Keterangan |
|---|---|---|
| `lis3dh_int1_pin` | **34** | INT1 akselerometer — lihat catatan di bawah |
| `sim2_cd_pin` | 56 | deteksi kartu SIM 2 |
| `sim1_cd_pin` | 60 | deteksi kartu SIM 1 |
| `cdc-pdm-lines` | 63 | audio PDM |
| `hw_operator_gpio1/2/3` | 16, 17, 106 | identifikasi operator (khas OPPO) |
| `hw_sub_gpio1/2` | 86, 111 | identifikasi varian papan |
| `tp_gpio_id1/2/3_config` | 109, 114, 119 | ID touchscreen **dan** ID panel |
| `usb-id-pin` | **110** | USB ID (OTG) |
| `ext_buck_vsel` | 116 | lihat catatan |

Pin lain yang dipakai DTS diambil dari properti eksplisit di board DTS, bukan dari
pinctrl: touchscreen IRQ 13, panel reset 25, panel enable 97, backlight enable 98,
LM3630 HWEN 69, charger IRQ 62, volume up/down 107/108, SD card-detect 38, proximity
IRQ 113.

### Label GPIO dari perangkat

`/sys/kernel/debug/gpio` menampilkan label yang diberikan driver, jadi ini bukti terkuat
untuk memastikan tiap pin. Basis TLMM = 902.

| TLMM | Label di perangkat | Arah | Dipakai DTS mainline sebagai |
|---|---|---|---|
| 13 | `rmi4_irq_gpio` | in | interrupt touchscreen |
| 25 | `disp_rst_n` | — | `reset-gpios` panel |
| 34 | (tidak diminta) | — | INT1 LIS3DH, dibiarkan mati |
| 38 | `7864900.sdhci cd` | in | `cd-gpios` kartu SD |
| 69 | `backlight_enable` | out hi | `enable-gpios` LM3630 |
| 97 | `disp_enable` | — | regulator `reg_panel_vdd` |
| 98 | `bklt_enable` | — | regulator `reg_bl_vdd` |
| 107 | `volume_up` | in | `gpio-keys` |
| 108 | `volume_down` | in | `gpio-keys` |
| 109 / 114 / 119 | `TP_ID1/2/3` | in | ID panel + touchscreen |
| 110 | `USB_ID_GPIO` | in | OTG (belum diaktifkan) |
| 113 | `apds_irq` | in | interrupt proximity |
| 116 | `sdcard_vdd_enable` | out lo | regulator `reg_sd_vdd` |
| 118 | `YDA_BOOST` | out lo | boost amplifier speaker |
| 120 | `YDA_GPIO` | out lo | enable amplifier speaker |
| 16, 17, 106, 86, 111, 50–52 | `HW_ID*`, `SUB_HW_ID*`, `pcb_ver_flag*` | in | identifikasi varian papan, tidak dipakai |

**GPIO panel hanya muncul saat layar menyala.** Downstream mdss melepas `disp_rst_n`,
`disp_enable`, dan `bklt_enable` ketika panel dimatikan, jadi pembacaan pertama (layar
mati) sempat terlihat seolah ketiganya tidak terpakai. Setelah layar dinyalakan,
ketiganya muncul dengan label di atas — cocok persis dengan yang dimodelkan di DTS.

**GPIO 116 terselesaikan.** Berkas pinctrl menamainya `ext_buck_vsel` (sisa desain NCP6335D
yang chipnya tidak terpasang), tapi perangkat menamainya `sdcard_vdd_enable`. Yang kedua
yang berlaku.

### Yang benar-benar aktif, menurut `/proc/interrupts`

```
 13:   3464   msm_tlmm_irq   synaptics-s3203
288:      2   msm_tlmm_irq   7864900.sdhci cd
330:      2   msm_tlmm_irq   apds9921
428:      0   msm_tlmm_irq   msm_otg
493:      2   msm_tlmm_irq   volume_up
494:      2   msm_tlmm_irq   volume_down
```

Tiga hal yang diselesaikan daftar ini:

**Volume down memang di TLMM.** Ada dua entri terpisah `volume_up` dan `volume_down`, dua-duanya
di `msm_tlmm_irq` dan dua-duanya dengan hitungan bukan nol. Jadi A37f tidak memakai PMIC
resin untuk volume down seperti kebanyakan perangkat msm8916 — `gpio-keys` dengan TLMM
107 dan 108 sudah benar. (Bitmap `capabilities/key` juga mengonfirmasi: `gpio-keys`
mendaftarkan kode 114 dan 115, sedangkan `qpnp_pon` mendaftarkan 114 dan 116.)

**LIS3DH tidak punya interrupt sama sekali.** Tidak ada entri untuk lis3dh, dan node
`st@19` downstream memang tidak punya properti `interrupts` — sensornya jalan polled
(`st,init-interval = 200`). Pinnya ada di GPIO 34, tapi belum terbukti tersambung, jadi
di DTS mainline interruptnya dibiarkan dikomentari.

**OTG tersambung.** Ada entri `msm_otg` di TLMM, dan pin `usb-id-pin` di GPIO 110.
Digabung dengan regulator OTG VBUS milik BQ24196, artinya OTG bisa diaktifkan setelah
USB gadget terbukti jalan.

### Orientasi akselerometer

Node `st@19` downstream memberi pemetaan sumbunya:

```
st,axis-map-x = <1>;  st,negate-x;   ->  out_x = -raw_y
st,axis-map-y = <0>;                 ->  out_y = +raw_x
st,axis-map-z = <2>;                 ->  out_z = +raw_z
```

Diterjemahkan jadi `mount-matrix` mainline `"0","-1","0", "1","0","0", "0","0","1"`.
Tetap perlu dicek sekali dengan memiringkan perangkat.

### Catatan GPIO 116

Berkas pinctrl menamainya `ext_buck_vsel` — sisa dari desain rujukan yang memakai buck
NCP6335D. Buck itu tidak terpasang di A37f (drivernya tidak ter-bind). Yang berlaku adalah
pemakaian di node `sdhc_2`: `vdd-gpio-en = <&msm_gpio 116 0x1>`, yaitu enable daya kartu SD.

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

## Amplifier speaker TS4621

Chip terakhir yang belum teridentifikasi ternyata penting. Drivernya ada di kernel
downstream sebagai **codec ASoC**, bukan driver misc:

```
sound/soc/codecs/ts4621.c    580 baris
```

Isinya memastikan fungsinya — amplifier speaker yang dikontrol lewat I²C:

```c
ts4621_reg_write(0x01, 0x01);  // path disable and I2C disable
ts4621_reg_write(0x02, 0xC0);  // mute and set volume -64dB
cTemp = cValue | 0xc0;         // path enable
static int DEFAULT_GAIN = 0x38;
```

Dump register dari perangkat cocok dengan itu — hanya 4 register yang berulang di
seluruh ruang alamat:

```
00: 40 01 c0 00 40 01 c0 00 ...
       ^  ^
       |  +-- reg 0x02 = 0xc0, mute
       +----- reg 0x01 = 0x01, path disable
```

Yaitu keadaan diam saat tidak ada yang diputar.

Amplifier ini juga punya dua jalur kendali GPIO, dari `msm8916-audio-internal_codec.dtsi`:

```
spk-pa-en       = <&msm_gpio 120 0x00>;   // enable amplifier
yda145_boost-en = <&msm_gpio 118 0x00>;   // enable boost
```

Namanya menyebut **Yamaha YDA145**, tapi yang benar-benar terpasang adalah TS4621 —
drivernya ter-bind dan chipnya menjawab di bus, sementara YDA145 tidak punya jejak di i2c.
Pola yang sama dengan sensor: OPPO menuliskan semua varian pemasok, hanya satu yang
dipasang. Kedua GPIO terbaca `out lo` saat tidak ada audio.

**Konsekuensi untuk Fase 7:** mainline belum punya driver `ts4621`. Jalur earpiece dan
headset lewat codec PMIC (`pm8916_codec` + `q6*`) seharusnya tetap jalan.

Untuk speaker, langkah pertama yang layak dicoba adalah `simple-audio-amplifier` dengan
`enable-gpios` ke GPIO 120 plus regulator tetap untuk boost di GPIO 118 — jauh lebih murah
daripada langsung menulis driver codec. Register `0x01` TS4621 punya bit "I2C disable",
yang menyiratkan ada mode gain tetap tanpa kendali I²C. Kalau ternyata chip tetap terkunci
mute, barulah perlu driver codec sungguhan.

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
| Iris | **WCN3620** — didukung dua petunjuk: hanya 2,4 GHz, dan node `qcom,wcnss-wlan` punya `qcom,has-autodetect-xo` tanpa `qcom,has-48mhz-xo`. Belum dibaca dari ID chip |

Di mainline keduanya ditangani `wcn36xx` + `wcnss_pil` + `btqca`, dengan varian iris
dideklarasikan di DTS (`&wcnss_iris { compatible = "qcom,wcn3620"; }`).
