# lk2nd untuk OPPO A37f

Status: **image sudah dibangun dan diverifikasi isinya. Belum pernah di-flash.**

```
build-lk2nd-msm8916/lk2nd.img   426.000 byte   (partisi boot: 32 MB — muat sangat longgar)
```

---

## Koreksi desain: A37 bukan DTB tersendiri

Draf pertama membuat `msm8916-oppo-a37.dts` sebagai berkas DTB terpisah, meniru
`msm8916-vivo-y21l.dts`. **Itu salah**, dan pembacaan perangkat yang membuktikannya:

```
/sys/devices/soc0/hw_platform         MTP
/sys/devices/soc0/platform_subtype_id 0
/sys/devices/soc0/platform_version    65536
/sys/devices/soc0/soc_id              206
```

`platform_subtype_id` = **0**. Artinya A37f mengaku sebagai **MTP generik** — tidak punya
subtype unik seperti Vivo Y21L yang memakai 13. Nomor proyek OPPO 15399 memang ada di
`qcom,board-id`, tapi ada di **cell ketiga**, sedangkan format Qualcomm standar hanya dua
cell. Dan `dtbTool` milik lk2nd memasangkan cell dua-dua:

```python
x = iter(board_id)
board_id = list(zip(x, x))     # <8 0 15399>  ->  [(8, 0)]  — 15399 dibuang
```

Akibatnya berkas DTB terpisah tadi masuk tabel QCDT sebagai `plat=206 variant=8 subtype=0`
— **persis sama dengan `msm8916-mtp.dtb`**. Dibuktikan dengan membongkar tabelnya:

```
plat=206 variant=0x8 subtype=0  -> 2 DTB: offset [8192, 10240]
```

Dua DTB bersaing untuk perangkat yang sama, dan pemenangnya ditentukan urutan, bukan
kebenaran. Kalau bootloader memilih `msm8916-mtp.dtb`, lk2nd tidak akan pernah tahu dia
sedang berjalan di A37.

**Cara yang benar** — dan memang sudah jadi pola lk2nd — adalah menjadikan A37 sebagai node
anak di dalam `msm8916-mtp.dts`, lalu dibedakan saat runtime. Marshall London, Vodafone
Smart prime 6, Asus ZenPad 8.0, dan Asus Zenfone Max semuanya ditangani begitu di berkas
yang sama.

Setelah dipindahkan, tabrakannya hilang:

```
plat=206 variant=8 subtype=0  ->  1 DTB
```

---

## Cara membangun

```bash
sudo apt install gcc-arm-none-eabi device-tree-compiler libfdt-dev python3

git clone https://github.com/msm8916-mainline/lk2nd
cd lk2nd
git apply /path/to/lk2nd/0001-msm8916-mtp-tambahkan-OPPO-A37.patch
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc)
```

Build memakan waktu sekitar 4 detik. Hasilnya `build-lk2nd-msm8916/lk2nd.img`.

Diuji dengan `arm-none-eabi-gcc` 13.2.1 di Ubuntu 24.04, terhadap lk2nd commit `3b7896f`.
Tidak ada peringatan maupun galat.

## Verifikasi sebelum flash

```bash
# 1. Node A37 benar-benar ada di DTB
dtc -I dtb -O dts build-lk2nd-msm8916/lk2nd/device/dts/msm8916/msm8916-mtp.dtb \
  | grep -A 20 oppo-a37

# 2. Tidak ada dua DTB yang memperebutkan plat=206 variant=8 subtype=0
python3 - <<'EOF'
import struct
d = open('build-lk2nd-msm8916/qcdt.img','rb').read()
magic, version, num = struct.unpack('<4sII', d[:12])
sz = {1:6, 2:6, 3:10}[version]
rows = [struct.unpack('<%dI'%sz, d[12+i*4*sz : 12+(i+1)*4*sz]) for i in range(num)]
hit = [r for r in rows if (r[0], r[1], r[2]) == (206, 8, 0)]
print("DTB untuk plat=206 variant=8 subtype=0:", len(hit), "(harus 1)")
EOF

# 3. Header boot image waras
#    ANDROID! / kernel @0x80008000 / pagesize 2048
```

## Cara flash

Belum dijalankan. Perlu cadangan Fase 1 lebih dulu.

```bash
adb reboot bootloader
fastboot flash boot build-lk2nd-msm8916/lk2nd.img
fastboot reboot
```

**Jalan pulang:** `fastboot flash boot boot-22.2.img` mengembalikan ROM lama. lk2nd hanya
menempati partisi `boot` dan tidak menyentuh apa pun yang lain.

## Yang harus diperiksa saat boot pertama

Satu hal masih belum bisa dipastikan tanpa menyalakannya, karena butuh akses root untuk
membaca `/proc/cmdline`: apakah bootloader OPPO mengoper parameter `mdss_mdp.panel=`.

`lk2nd,match-panel` bergantung pada parameter itu. Kalau ternyata tidak dioper, lk2nd akan
boot dengan benar tapi **tidak mengenali perangkat sebagai A37**.

Yang perlu dilihat di layar atau log lk2nd:

1. Apakah tertulis "OPPO A37" — kalau ya, `match-panel` bekerja dan tidak ada yang perlu
   diubah
2. Kalau tidak, baca cmdline yang dicetak lk2nd, cari string yang khas A37, lalu ganti
   `lk2nd,match-panel` dengan `lk2nd,match-cmdline = "*<string itu>*"` — persis seperti yang
   dilakukan entri `asus-z010d` di berkas yang sama

Kandidat yang sudah terlihat dari properti Android (`androidboot.*` yang sampai ke init):
`androidboot.startupmode=`, `androidboot.baseband=msm`, `androidboot.emmc=true`.
