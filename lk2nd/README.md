# lk2nd untuk OPPO A37f

Status: **belum berhasil. lk2nd panic di A37f, penyebabnya belum diketahui.**

| Build | Perubahan | Hasil di perangkat |
|---|---|---|
| 1 | node anak di `msm8916-mtp.dts`, QCDT 44 DTB | fastboot OPPO, layar hitam — **tidak bootloop** |
| 2 | DTB tersendiri, QCDT 1 DTB, `DEBUG_FBCON=1` | **bootloop** |
| 3 | node anak, QCDT dibatasi ke `msm8916-mtp.dtb`, + `gpio-keys` | **bootloop** |
| diag | seperti 3, + `PANIC_REBOOT_MODE=NO_REBOOT` + `DEBUG=2` | belum dicoba |
| 4 | board-id kustom `<8 0 15399>` + `LK2ND_DTBS`, **tanpa** fbcon | belum dicoba |
| 5 | board-id kustom + `LK2ND_QCDTBS` (appended DTB dipertahankan) | belum dicoba |

**Build 1 adalah keadaan paling aman** — perangkat masih bisa dijangkau lewat fastboot dan
di-flash ulang, bukan bootloop.

---

## Koreksi diagnosis

Build 2 dan 3 dibangun di atas kesimpulan yang salah. Ceritanya perlu ditulis supaya tidak
diulang.

Setelah build 1, perangkat berakhir di fastboot dengan `fastboot getvar all` kosong dan
`fastboot flash` ditolak `unknown command`. Dari situ disimpulkan lk2nd **tidak pernah
dijalankan**, dan yang menjawab adalah aboot OPPO. Komentar OPPO A57 di
`lk2nd/device/dts/msm8952/msm8940-oppo-a57.dts` tampak menjelaskannya:

> *The bootloader will attempt to load the first dtb with matching msm id, which fails as
> the board id does not match.*

Build 2 dan 3 dibangun untuk memperbaiki itu — membatasi jumlah DTB. Keduanya **bootloop**.

Kesalahannya baru terlihat di `lk2nd/project/lk2nd.mk`:

```make
PANIC_REBOOT_MODE ?= FASTBOOT_MODE
```

**Saat lk2nd panic, dia reboot ke mode fastboot.** Jadi fastboot OPPO yang muncul setelah
build 1 justru bukti lk2nd **berjalan lalu panic** — bukan bukti lk2nd tidak dimuat. Seluruh
teori pemilihan DTB tidak menjelaskan apa pun, dan dua build berikutnya memperbaiki masalah
yang tidak ada.

Pelajaran metode: build 2 mengubah dua variabel sekaligus (struktur DTB dan jumlah DTB),
build 3 juga dua (jumlah DTB dan `gpio-keys`). Keduanya tidak bisa dilacak.

## Yang sudah tersingkir

- **Pemilihan DTB.** Jumlah DTB tidak mengubah hal mendasar; lk2nd tetap panic.
- **Alamat boot image.** Header build 1 cocok persis dengan boot.img LineageOS 22.2 yang
  jalan di perangkat: kernel `0x80008000`, ramdisk `0x81000000`, tags `0x80000100`.
- **Verifikasi tanda tangan AVB.** Device tree LineageOS A37 tidak menandatangani boot.img
  sama sekali (`BoardConfig.mk` hanya menyetel `--ramdisk_offset` dan `--tags_offset`), dan
  ROM itu boot normal. Jadi bootloader A37f tidak memverifikasi — berbeda dari A57.
- **Appended DTB.** Bukan jalan keluar: diskusi [PR lk2nd#190](https://github.com/msm8916-mainline/lk2nd/pull/190)
  mencatat *"most MSM8916 devices require non-appended DTB to boot successfully; appended
  DTB configurations caused crashes"*.

## Variabel yang sempat luput: appended DTB

`LK2ND_DTBS` menyaring **dua-duanya** — `ADTBS` dan `QCDTBS`:

```make
ADTBS  := $(filter $(LK2ND_DTBS_FILTER),$(ADTBS))
QCDTBS := $(filter $(LK2ND_DTBS_FILTER),$(QCDTBS))
```

Karena `msm8916-oppo-a37.dtb` maupun `msm8916-mtp.dtb` tidak ada di daftar `ADTBS`
(isinya `msm8916-qrd-9.dtb` dan `msm8939-qrd-skuk.dtb`), build 2 dan 3 berakhir dengan
**nol appended DTB** — dan itu satu-satunya hal yang mereka bagi. Build 1 punya 2 appended
DTB dan tidak bootloop.

`LK2ND_QCDTBS` mengganti `QCDTBS` saja tanpa menyentuh `ADTBS`, jadi bisa dipakai untuk
menerapkan hack board-id sambil mempertahankan appended DTB.

## Soal tanda tangan OPPO

[`affggh/oppo_fake_signature`](https://github.com/affggh/oppo_fake_signature) menyasar
**A57 dan R9s saja**, dan mensyaratkan downgrade aboot lebih dulu. Keduanya perangkat
msm8937/msm8953 dari era penguncian bootloader — beda generasi dengan A37 (msm8916, awal
2016), yang masuk kelompok [PR#190](https://github.com/msm8916-mainline/lk2nd/pull/190)
dan bukan [PR#403](https://github.com/msm8916-mainline/lk2nd/pull/403) yang sudah di-merge.

Bukti bahwa A37f tidak memverifikasi tanda tangan tetap kuat: LineageOS 22.2 di perangkat
ini dibangun dari device tree yang tidak menandatangani boot.img sama sekali, dan ROM itu
boot normal.

## Yang belum diketahui

**Kenapa lk2nd panic di A37f.** Untuk menjawabnya ada build diagnostik:

```bash
make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8916 -j$(nproc) \
     LK2ND_DTBS="msm8916-mtp.dtb" DEBUG_FBCON=1 DEBUG=2 PANIC_REBOOT_MODE=NO_REBOOT
```

`PANIC_REBOOT_MODE=NO_REBOOT` membuat lk2nd **berhenti** saat panic alih-alih reboot, dan
`DEBUG_FBCON=1` mencetak lognya ke layar. Bootloop berubah jadi layar diam yang menampilkan
baris terakhir sebelum crash — bisa difoto dan dibaca.

## Entri device: datanya sudah terkonfirmasi

Terlepas dari kegagalan boot, isi entri A37 sudah tervalidasi dua kali. Diturunkan mandiri
dari DTS downstream dan `/proc/interrupts` perangkat, lalu ternyata **cocok persis** dengan
entri A37 di PR lk2nd#190: nomor proyek 15399, tiga nama node panel yang sama, dan
`KEY_VOLUMEDOWN` di GPIO 108 / `KEY_VOLUMEUP` di GPIO 107 yang sama.

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
