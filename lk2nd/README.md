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
lk2nd-a37f-mtp.img        294.928 byte  sha256 1dc2c92d8ec98fece7657097c994187077d11a65676fb684e1e3d40a49bceba0
lk2nd-a37f-mtp-fbcon.img  294.928 byte  sha256 30829f66cdf677135c79f5807db8b95ebbf6d1e0eef3f9752e32330db8273299
```

Dua varian dibangun untuk mengisolasi `DEBUG_FBCON`, yang ikut ditambahkan di build 2 dan
belum tersingkirkan sebagai penyebab bootloop. **Coba yang tanpa fbcon lebih dulu.**

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

## Perbaikan di build 3

Dua sumber digabung:

**Struktur dari PR lk2nd#190.** PR itu menambahkan sepuluh perangkat OPPO msm8916/msm8939,
termasuk A37, sebagai **node anak di `msm8916-mtp.dts`** — tanpa DTB tersendiri dan tanpa
board-id per-perangkat. Entri A37-nya cocok persis dengan yang diturunkan mandiri di repo
ini: tiga nama node panel yang sama, dan `KEY_VOLUMEDOWN 108` / `KEY_VOLUMEUP 107` yang
sama seperti hasil pembacaan `/proc/interrupts`.

**Pembatasan DTB dari komentar A57.** Bangun hanya satu DTB, supaya "DTB pertama yang
msm-id-nya cocok" pasti yang benar:

```bash
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc) LK2ND_DTBS="msm8916-mtp.dtb"
```

Nilai `LK2ND_DTBS` cukup nama berkasnya saja tanpa subdirektori: `LOCAL_DIR` di
`lk2nd/device/dts/rules.mk` sudah tertimpa oleh `rules.mk` anak saat filter dijalankan.

Hasilnya QCDT berisi satu entri:

```
plat=206 variant=0x8 subtype=0
```

Cocok dengan yang dilaporkan SMEM perangkat: `soc_id=206`, `hw_platform=MTP`,
`platform_subtype_id=0`.

**Kenapa build 2 tidak bisa dilacak.** Build 2 mengubah dua hal sekaligus dari build 1 —
struktur DTB *dan* jumlah DTB — lalu bootloop. Karena dua variabel berubah bersamaan,
kegagalannya tidak bisa dikaitkan ke salah satunya. Build 3 hanya mengubah satu variabel
dari build 1: jumlah DTB.

**Appended DTB jangan dipakai.** Diskusi PR#190 mencatat: *"Mirror 5s and most MSM8916
devices require non-appended DTB to boot successfully; appended DTB configurations caused
crashes"*. Image lk2nd berbasis appended DTB (39 DTB, tanpa QCDT) karena itu tidak cocok
untuk A37f.

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
git apply /path/to/lk2nd/0001-msm8916-mtp-tambahkan-OPPO-A37.patch
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc) LK2ND_DTBS="msm8916-mtp.dtb"
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
dtc -I dtb -O dts build-lk2nd-msm8916/lk2nd/device/dts/msm8916/msm8916-mtp.dtb | grep -A20 oppo-a37

# 3. Muat di bawah offset 512 KB (supaya boot.img Android bisa menyusul di atasnya)
#    294.928 < 524.288  OK
```

## Cara flash

Fastboot OPPO menolak `flash`, jadi EDL adalah satu-satunya jalan — dan itu memang yang
disarankan komentar A57.

```
emmcdl.exe -p <port> -f <firehose> -b boot lk2nd-a37f-mtp.img
```

**Jalan pulang:** `emmcdl.exe -p <port> -f <firehose> -b boot boot-22.2.img` mengembalikan
ROM lama. lk2nd hanya menempati partisi `boot` dan tidak menyentuh `system`, `persist`,
`modem`, maupun `userdata`.

## Yang harus diperiksa saat boot pertama

Untuk varian `-fbcon`, log lk2nd tercetak di layar:

1. **Layar menampilkan log lk2nd** — kalau ini muncul, lk2nd jalan
2. `fastboot getvar all` menampilkan baris `lk2nd:*`. Yang paling penting:
   - `lk2nd:model` = `OPPO A37`
   - `lk2nd:panel` — ini sekaligus menguji apakah `lk2nd,match-panel` bekerja
3. `fastboot oem help` menampilkan perintah `oem` milik lk2nd
4. Kalau perlu log lengkap: `fastboot oem log && fastboot get_staged /dev/stdout`

Kalau `getvar all` masih kosong dan `flash` masih ditolak, berarti yang menjawab tetap
aboot OPPO — dan tersangka berikutnya adalah verifikasi tanda tangan.
