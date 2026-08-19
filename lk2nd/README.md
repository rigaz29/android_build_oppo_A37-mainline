# lk2nd untuk OPPO A37f

Status: **build ketiga. Dua percobaan sebelumnya gagal — yang kedua menyebabkan bootloop.**

| Build | Struktur | Hasil di perangkat |
|---|---|---|
| 1 | A37 sebagai node anak di `msm8916-mtp.dts`, QCDT 44 DTB | Tidak boot. Aboot OPPO ambil DTB lain, jatuh ke fastboot bawaannya |
| 2 | A37 sebagai DTB tersendiri (board-id 3 cell), QCDT 1 DTB, `DEBUG_FBCON=1` | **Bootloop** |
| 3 | A37 node anak di `msm8916-mtp.dts`, QCDT dibatasi ke `msm8916-mtp.dtb` saja | belum diuji |

Build 3 menggabungkan dua pelajaran: struktur node anak yang dipakai
[PR lk2nd#190](https://github.com/msm8916-mainline/lk2nd/pull/190) untuk sepuluh perangkat
OPPO, **plus** pembatasan jumlah DTB yang diwajibkan komentar OPPO A57. Build 1 memakai
struktur yang benar tapi dengan 44 DTB; build 2 membatasi DTB tapi mengubah strukturnya
sekaligus. Build 3 hanya mengubah satu variabel dari build 1.

```
build-lk2nd-msm8916/lk2nd.img   292.880 byte   (partisi boot 32 MB; muat di bawah offset 512 KB)
sha256                          0422755fd2799c8df38e38b8d89f2d684a9c70187a065187967838c819f95d1a
```

---

## Kenapa percobaan pertama gagal

Image pertama di-flash lewat EDL, lalu perangkat boot ke fastboot dengan layar menyisakan
gambar charging OPPO. Sekilas itu terlihat seperti lk2nd yang berjalan tanpa OS. Ternyata
bukan — dua perintah membuktikannya:

```
> fastboot getvar all
all:
Finished. Total time: 0.002s

> fastboot flash recovery twrp.img
Sending 'recovery' (26684 KB)   OKAY
Writing 'recovery'              FAILED (remote: 'unknown command')
```

lk2nd menerbitkan puluhan variabel (termasuk `lk2nd:model`, `lk2nd:panel`) dan mendukung
`flash`. Yang menjawab di sini tidak punya variabel sama sekali dan menolak `flash` —
itu **fastboot bawaan OPPO yang dipangkas**, dan artinya lk2nd tidak pernah dijalankan.

Penyebabnya sudah didokumentasikan lk2nd sendiri, di komentar
`lk2nd/device/dts/msm8952/msm8940-oppo-a57.dts` untuk OPPO A57 — perangkat sezaman:

> *Custom board id is required by the bootloader. The bootloader will attempt to load the
> first dtb with matching msm id, which fails as the board id does not match. Add
> `LK2ND_DTBS="msm8940-oppo-a57.dtb"` to your make cmdline.*

Bootloader OPPO tidak melakukan pencocokan board-id yang benar. Dia mengambil **DTB
pertama yang msm-id-nya cocok**, lalu gagal karena board-id-nya tidak sesuai. Build
pertama kita memuat **44 DTB** dari semua perangkat msm8916 yang didukung lk2nd, jadi yang
terambil hampir pasti bukan punya A37.

Sekaligus ini menjelaskan kenapa `emmcdl` dipakai: komentar yang sama menyebut lk2nd tidak
bisa di-flash lewat fastboot pada perangkat OPPO, dan harus lewat EDL. Kita sudah
melakukannya dengan benar.

## Perbaikannya

Dua perubahan, keduanya mengikuti pola A57:

**1. A37 kembali jadi DTB tersendiri.** Sebelumnya A37 dipindah menjadi node anak di dalam
`msm8916-mtp.dts` untuk menghindari tabrakan slot QCDT. Untuk perangkat OPPO itu tidak
bisa — kita justru butuh DTB terpisah supaya bisa dibangun sendirian.

**2. Bangun hanya DTB itu.**

```bash
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc) \
     LK2ND_DTBS="msm8916-oppo-a37.dtb" DEBUG_FBCON=1
```

Nilai `LK2ND_DTBS` cukup nama berkasnya saja, tanpa subdirektori: `LOCAL_DIR` di
`lk2nd/device/dts/rules.mk` sudah tertimpa oleh `rules.mk` anak saat filter dijalankan,
jadi prefiksnya sudah `lk2nd/device/dts/msm8916/`.

Hasilnya tabel QCDT berisi tepat satu DTB:

```
magic=QCDT version=2 entries=4
  plat=206 variant=0x8 subtype=0  offset=2048    <- MSM8916
  plat=248 variant=0x8 subtype=0  offset=2048    <- MSM8216
  plat=249 variant=0x8 subtype=0  offset=2048    <- MSM8116
  plat=250 variant=0x8 subtype=0  offset=2048    <- MSM8616
```

Empat entri, tapi semuanya menunjuk **offset yang sama** — satu DTB didaftarkan di bawah
empat msm-id yang dilaporkan A37f. Jadi "DTB pertama yang cocok msm-id" pasti punya kita.

**3. `DEBUG_FBCON=1` ditambahkan** supaya lk2nd mencetak lognya ke layar. Build pertama
tidak memakainya, sehingga tidak ada umpan balik visual sama sekali — layar hanya
menyisakan gambar charging dari aboot.

## Satu quirk A57 yang kemungkinan besar TIDAK berlaku

Komentar yang sama menyebut A57 punya bootloader yang tidak bisa di-unlock, sehingga
butuh tanda tangan AVB OPPO yang disalin dari boot image bawaan — dan bahwa
`SIGN_BOOTIMG` generik **tidak** bekerja.

Untuk A37f itu kemungkinan besar tidak jadi soal, dengan alasan yang kuat: perangkat ini
sudah menjalankan **LineageOS 22.2 hasil build sendiri**. Kalau bootloader-nya memverifikasi
tanda tangan, boot image custom itu tidak akan pernah boot. Jadi verifikasi tanda tangan
sudah terbukti bukan penghalang di perangkat ini.

Kalau ternyata build ini tetap tidak jalan, barulah tanda tangan jadi tersangka berikutnya.

---

## Cara membangun

```bash
sudo apt install gcc-arm-none-eabi device-tree-compiler libfdt-dev python3

git clone https://github.com/msm8916-mainline/lk2nd
cd lk2nd
git apply /path/to/lk2nd/0001-msm8916-tambahkan-DTB-OPPO-A37.patch
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc) \
     LK2ND_DTBS="msm8916-oppo-a37.dtb" DEBUG_FBCON=1
```

Diuji dengan `arm-none-eabi-gcc` 13.2.1 di Ubuntu 24.04, terhadap lk2nd commit `3b7896f`.
Tidak ada peringatan maupun galat. Build memakan waktu sekitar 3 detik.

## Verifikasi sebelum flash

```bash
# 1. Tabel QCDT harus berisi tepat SATU DTB
python3 - <<'EOF'
import struct
d = open('build-lk2nd-msm8916/qcdt.img','rb').read()
magic, version, num = struct.unpack('<4sII', d[:12])
sz = {1:6, 2:6, 3:10}[version]
rows = [struct.unpack('<%dI'%sz, d[12+i*4*sz : 12+(i+1)*4*sz]) for i in range(num)]
print("entri:", num, "| offset unik:", set(r[-2] for r in rows), "(harus satu nilai)")
EOF

# 2. Node A37 ada di DTB
dtc -I dtb -O dts build-lk2nd-msm8916/lk2nd/device/dts/msm8916/msm8916-oppo-a37.dtb

# 3. Muat di bawah offset 512 KB (supaya boot.img Android bisa menyusul di atasnya)
#    292.880 < 524.288  OK
```

## Cara flash

Fastboot OPPO menolak `flash`, jadi EDL adalah satu-satunya jalan — dan itu memang yang
disarankan komentar A57.

```
emmcdl.exe -p <port> -f <firehose> -b boot lk2nd-a37f.img
```

**Jalan pulang:** `emmcdl.exe -p <port> -f <firehose> -b boot boot-22.2.img` mengembalikan
ROM lama. lk2nd hanya menempati partisi `boot` dan tidak menyentuh `system`, `persist`,
`modem`, maupun `userdata`.

## Yang harus diperiksa saat boot pertama

Kali ini ada umpan balik visual karena `DEBUG_FBCON=1`:

1. **Layar menampilkan log lk2nd** — kalau ini muncul, lk2nd jalan
2. `fastboot getvar all` menampilkan baris `lk2nd:*`. Yang paling penting:
   - `lk2nd:model` = `OPPO A37`
   - `lk2nd:panel` — ini sekaligus menguji apakah `lk2nd,match-panel` bekerja
3. `fastboot oem help` menampilkan perintah `oem` milik lk2nd
4. Kalau perlu log lengkap: `fastboot oem log && fastboot get_staged /dev/stdout`

Kalau `getvar all` masih kosong dan `flash` masih ditolak, berarti yang menjawab tetap
aboot OPPO — dan tersangka berikutnya adalah verifikasi tanda tangan.
