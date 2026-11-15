<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-mark-dark.png">
    <img src="assets/logo-mark.png" alt="Logo Sphinx" width="120" />
  </picture>
  <h1>Sphinx: Penyelesai Puzzle</h1>
  <p><b>Penyelesai puzzle berbasis constraint: sudoku, nonogram dan puzzle logika,<br/>
  diselesaikan cepat, dijelaskan langkah demi langkah. CLI dan library yang bisa dipakai ulang.</b></p>

  <a href="https://github.com/nekonaru/sphinx/releases"><img src="https://img.shields.io/github/v/release/nekonaru/sphinx?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/nekonaru/sphinx/actions/workflows/ci.yml"><img src="https://github.com/nekonaru/sphinx/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Haskell-%3E%3D9.6.6-5e5086?style=flat-square&logo=haskell&logoColor=white" alt="Haskell" />
  <img src="https://img.shields.io/badge/Platform-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows-2E8B57?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square" alt="Status" />
</div>

<br />

[English](README.md) | **Bahasa Indonesia**

> [!NOTE]
> Sphinx adalah penyelesai puzzle untuk sudoku, nonogram dan puzzle logika (zebra). Sphinx membaca file teks, mencetak jawabannya, menjelaskan langkah penyelesaiannya, dan mengecek apakah sebuah puzzle bisa diselesaikan secara unik.

---

## Daftar Isi

- [Tentang](#tentang)
- [Fitur](#fitur)
- [Kebutuhan](#kebutuhan)
- [Instalasi](#instalasi)
- [Pemakaian](#pemakaian)
- [Struktur Proyek](#struktur-proyek)
- [Pengembangan](#pengembangan)
- [Pengujian](#pengujian)
- [Keamanan](#keamanan)
- [Integrasi Berkelanjutan](#integrasi-berkelanjutan)
- [FAQ](#faq)
- [Penulis](#penulis)
- [Lisensi](#lisensi)

---

## Tentang

**Sphinx** adalah penyelesai puzzle open source yang ditulis dalam Haskell. Sphinx menangani puzzle sudoku, nonogram dan puzzle logika gaya Einstein (zebra), menjelaskan langkah penyelesaian sudoku, mengecek apakah sebuah puzzle memiliki solusi unik, dan bisa membuat puzzle sudoku baru dengan solusi unik yang dijamin. Pakai sebagai alat baris perintah (CLI) atau sebagai library di balik typeclass `Puzzle`.

---

## Fitur

### Solver

| Fitur | Deskripsi |
|-------|-----------|
| **Solver sudoku** | Propagasi constraint (naked single, hidden single) lalu backtracking dengan heuristik minimum remaining values |
| **Solver nonogram** | Line solving, propagasi constraint sampai fixpoint, lalu branch pada baris atau kolom dengan opsi paling sedikit |
| **Mode langkah demi langkah** | `--steps` mencetak setiap deduksi yang dilakukan solver, diklasifikasikan sebagai `NakedSingle`, `HiddenSingle` atau `Guess` (Bahasa Indonesia) |
| **Menghitung solusi** | `--count N` menghitung sampai N solusi; `--count 2` memberitahu apakah puzzle itu unik |
| **Generator puzzle** | `--generate easy\|medium\|hard` membuat sudoku baru dengan solusi unik yang dijamin (`--seed` untuk puzzle yang reproducible) |
| **Render nonogram** | Nonogram yang selesai dicetak sebagai gambar blok dengan petunjuk baris dan kolom yang rapi |

### Puzzle logika

| Fitur | Deskripsi |
|-------|-----------|
| **Solver puzzle logika** | Enam tipe petunjuk (`eq`, `pos`, `nextto`, `leftof`, `immleft`, `notsame`); menyelesaikan puzzle Einstein (zebra) kecil dengan hingga 6 rumah |
| **Menghitung solusi** | `--count N` menghitung sampai N solusi; `--count 2` memberitahu apakah puzzle itu unik |
| **Output tabel rapi** | Puzzle yang selesai dicetak sebagai tabel kecil, satu baris per kategori, satu kolom per rumah |

### Library

| Fitur | Deskripsi |
|-------|-----------|
| **Typeclass `Puzzle`** | Satu antarmuka seragam: `parsePuzzle`, `solveLimit`, `renderSolution`, `renderPuzzle` |
| **Inti yang murni** | Semua logika solving bersifat lazy, murni dan bebas efek samping; I/O hanya ada di CLI |
| **Error bertipe** | Setiap mode kegagalan punya error bertipe dengan pesan yang ramah |

### Contoh dan Pengujian

| Fitur | Deskripsi |
|-------|-----------|
| **Contoh puzzle** | `examples/` berisi sudoku mudah, sudoku sulit, sudoku dengan banyak solusi dan dua nonogram |
| **Property test** | Property QuickCheck untuk kebenaran solver, plus fuzzing input hostile untuk kedua parser |
| **Golden test** | Keluaran renderer diverifikasi terhadap file golden yang dikomit |

---

## Kebutuhan

| Dependency | Versi Minimum | Catatan |
|------------|---------------|---------|
| **GHC** | 9.6.6 | Pasang lewat [ghcup](https://www.haskell.org/ghcup/) |
| **cabal-install** | 3.10+ | Pasang juga lewat ghcup |
| **Index Hackage** | terbaru | `cabal update` mengunduhnya sekali |
| **C compiler** | apa pun yang dibawa ghcup | Hanya dibutuhkan jika ada dependency yang mengompilasi C (tidak ada pada dependency saat ini) |

> [!TIP]
> Kalau kamu hanya ingin CLI-nya dan tidak berencana build dari source, bagian build di bawah tetap cuma dua perintah: `cabal update` dan `cabal install exe:sphinx`.

---

## Instalasi

### Opsi A: Build dan pasang CLI

1. Pasang toolchain (lewati kalau kamu sudah punya ghcup):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ghcup install ghc --set recommended
ghcup install cabal --set recommended
```

2. Ambil kode dan pasang executable-nya:

```bash
git clone https://github.com/nekonaru/sphinx.git
cd sphinx
cabal update
cabal install exe:sphinx
```

3. Verifikasi instalasi:

```bash
sphinx --version
sphinx --help
```

### Opsi B: Build dari source untuk development

Sama seperti Opsi A, ditambah test suite:

```bash
cabal build --ghc-options=-Werror
cabal test --test-show-details=direct
```

> [!IMPORTANT]
> Build yang bersih berarti nol warning. Kalau `cabal build` mencetak `-W` warning, perubahannya belum siap.

---

## Pemakaian

### Peluncuran pertama

Selesaikan contoh puzzle yang disertakan dan cetak gridnya:

```bash
sphinx sudoku examples/sudoku-easy.txt
```

Cek bahwa puzzle itu benar-benar terselesaikan:

```bash
sphinx sudoku examples/sudoku-hard.txt --count 2
```

### Pemakaian sehari-hari

- **Selesaikan dengan penjelasan**: `sphinx sudoku examples/sudoku-easy.txt --steps`
- **Cek keunikan**: `sphinx sudoku examples/sudoku-hard.txt --count 2`
- **Buat puzzle baru**: `sphinx sudoku --generate hard --seed 42`
- **Selesaikan nonogram**: `sphinx nonogram examples/nonogram-heart.txt`
- **Keunikan nonogram**: `sphinx nonogram examples/nonogram-heart.txt --count 2`
- **Selesaikan puzzle logika**: `sphinx logic examples/zebra-einstein.txt`
- **Keunikan logika**: `sphinx logic examples/zebra-einstein.txt --count 2`
- **Statistik pencarian**: `sphinx nonogram examples/nonogram-heart.txt --steps`
- **Dari pipe**: `cat examples/sudoku-easy.txt | sphinx sudoku -`

### Format input

Sudoku: satu baris berisi 81 karakter, atau 9 baris berisi 9 karakter. `.` dan `0` berarti kosong, digit 1-9 adalah angka yang diberikan.

```
530070000600195000098000060800060003400803001700020006060000280000419005000080079
```

Nonogram: baris petunjuk baris, baris pemisah `---`, lalu baris petunjuk kolom. Setiap petunjuk adalah daftar panjang blok yang dipisah spasi; `0` pada satu baris berarti baris itu kosong.

```
2 2
7
7
5
3
1
---
2
4
5
5
5
4
2
```

Logika: tentukan jumlah rumah, kategori berisi nilai, lalu bagian `clues:`. Setiap kategori harus memiliki tepat `houses` nilai dan nilai tidak boleh berulang antar kategori. Jumlah rumah antara 2 dan 6.

```
houses: 3
category name: Alice Bob Carol
category drink: tea coffee juice
category color: red green blue
clues:
pos Alice 1
eq tea green
notsame Bob tea
eq Carol juice
leftof red juice
```

Petunjuk: `eq X Y` (rumah sama), `pos X N` (X ada di rumah N), `nextto X Y` (berdekatan), `leftof X Y` (di kiri), `immleft X Y` (langsung di kiri), `notsame X Y` (rumah berbeda).

### Pemakaian sebagai library

```haskell
import Sphinx.Class (Puzzle(..), firstSolution, isUnique)
import qualified Sphinx.Sudoku.Parse as Sudoku

main :: IO ()
main = case Sudoku.parseSudoku "530070000600195000098000060800060003400803001700020006060000280000419005000080079" of
  Left err -> putStrLn ("puzzle tidak valid: " ++ show err)
  Right grid -> do
    print (firstSolution grid)   -- solusi pertama, bila ada
    print (isUnique grid)        -- True bila tepat satu solusi
```

Typeclass `Puzzle` adalah satu-satunya titik ekstensi untuk tipe puzzle baru:

```haskell
class Puzzle p where
  type Solution p
  parsePuzzle    :: String -> Either SphinxError p
  solveLimit     :: Int -> p -> [Solution p]
  renderSolution :: p -> Solution p -> String
  renderPuzzle   :: p -> String
```

---

## Struktur Proyek

```
sphinx/
├── sphinx.cabal                 # Definisi package (library, CLI, test suite)
├── app/
│   └── Main.hs                  # Entry point CLI (optparse-applicative)
├── src/
│   ├── Sphinx/
│   │   ├── Class.hs             # Typeclass Puzzle dan helper
│   │   ├── Error.hs             # Error bertipe untuk setiap mode kegagalan
│   │   ├── Sudoku/              # Types, Parse, Solve, Render, Generate, Puzzle
│   │   ├── Nonogram/            # Types, Parse, Line, Solve, Render, Puzzle
│   │   └── Logic/               # DSL, Render, Puzzle (puzzle zebra)
├── test/
│   ├── Spec.hs                  # hspec + QuickCheck + golden test
│   └── golden/                  # Keluaran renderer yang diharapkan
├── examples/                    # Contoh puzzle (sudoku, nonogram, logika)
├── docs/
│   └── algorithms.md            # Cara kerja solver
├── assets/
│   └── logo.png
├── README.md                    # English
├── README.id.md                 # Bahasa Indonesia (file ini)
└── LICENSE                      # MIT
```

---

## Pengembangan

### Menambah fitur

1. Tulis atau sesuaikan test dulu (hspec untuk contoh, QuickCheck untuk properti).
2. Jaga library tetap murni; semua I/O tinggal di `app/Main.hs`.
3. Build dengan warning sebagai error: `cabal build --ghc-options=-Werror`.
4. Jalankan seluruh suite: `cabal test`.
5. Perbarui `README.md` dan `README.id.md` bersama-sama, dan tambahkan satu baris ke kedua changelog.

> [!WARNING]
> File di `test/golden/` adalah keluaran yang diharapkan. Perbarui hanya dengan menjalankan renderer lagi, jangan pernah mengeditnya dengan tangan.

### Menambah tipe puzzle baru

1. Buat `src/Sphinx/<YourPuzzle>/` berisi modul `Types`, `Parse`, `Solve`, `Render`, `Puzzle`, mengikuti layout sudoku dan nonogram.
2. Tambahkan instance dari typeclass `Puzzle` (lihat `src/Sphinx/Sudoku/Puzzle.hs`).
3. Sambungkan ke CLI di `app/Main.hs` dan tambahkan test plus examples.

---

## Pengujian

```bash
cabal build --ghc-options=-Werror
cabal test --test-show-details=direct
```

| Check | Requirement |
|-------|-------------|
| Build | Nol warning, nol error (`-Werror`) |
| Unit test | Semua contoh lolos |
| Property test | Property QuickCheck lolos (kebenaran solver, fuzzing input) |
| Golden test | Keluaran renderer cocok persis dengan `test/golden/` |

Suite berisi 45 contoh dan berjalan dalam sekitar satu detik.

---

## Keamanan

Sphinx adalah alat offline: membaca file teks yang kamu tunjuk dan mencetak hasilnya. Sphinx tidak memakai jaringan, tidak menjalankan subproses, tidak menyimpan kredensial, dan tidak membuat file sementara. CLI menolak file yang lebih besar dari 1 MiB, dan kedua parser mengembalikan error bertipe untuk input yang rusak. Dependency di-build dengan `-Werror` di CI pada tiga versi GHC.

> [!NOTE]
> Laporkan kerentanan secara privat lewat GitHub Security Advisories: https://github.com/nekonaru/sphinx/security/advisories/new. Lihat [SECURITY.md](SECURITY.md).

---

## Integrasi Berkelanjutan

| Workflow | Tujuan |
|----------|--------|
| `ci.yml` | Build dengan `-Werror` dan jalankan seluruh test suite pada GHC 9.6.6, 9.8.4 dan 9.10.1 |

Branch `main` mewajibkan check `build-test` lolos sebelum merge; direct push oleh maintainer diizinkan. Rilis di-tag `vX.Y.Z` setelah CI hijau.

---

## FAQ

<details><summary><b>Apakah Sphinx butuh internet?</b></summary>

Tidak. Sphinx bekerja sepenuhnya offline. Hanya `cabal update` pada instalasi pertama yang mengunduh metadata package.

</details>

<details><summary><b>Kenapa Haskell?</b></summary>

Fungsi murni, data immutable dan laziness cocok untuk solver backtracking: penghitung solusi (`--count`) berhenti begitu jawabannya diketahui.

</details>

<details><summary><b>Bisakah dipakai sebagai library?</b></summary>

Bisa. Tambahkan package `sphinx` sebagai dependency dan gunakan typeclass `Puzzle`. Lihat [Pemakaian sebagai library](#pemakaian-sebagai-library).

</details>

<details><summary><b>Seberapa akurat tingkat kesulitan puzzle yang digenerate?</b></summary>

Tingkat kesulitan ditentukan dari banyaknya angka yang dibiarkan (easy 40, medium 32, hard 26). Hard tidak sama dengan setiap puzzle tersulit versi manusia, tapi setiap puzzle hasil generator punya tepat satu solusi.

</details>

<details><summary><b>Apakah keluaran <code>--steps</code> berbahasa Inggris?</b></summary>

Tidak. `--steps` mencetak langkah deduksi dalam Bahasa Indonesia, sesuai spesifikasi produk. Sisanya berbahasa Inggris.

</details>

---

## Penulis

<div align="center">

| [![nekonaru](https://github.com/nekonaru.png?size=100)](https://github.com/nekonaru) |
|:---:|
| **nekonaru** ([GitHub](https://github.com/nekonaru)) |

</div>

---

## Lisensi

Didistribusikan di bawah **Lisensi MIT**. Lihat [`LICENSE`](LICENSE) untuk informasi lebih lanjut.
