# Changelog

Semua perubahan penting proyek ini didokumentasikan di sini. Formatnya
mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan
proyek ini memakai [Semantic Versioning](https://semver.org/).

## v0.2.0 - 2026-11-16

Sphinx punya tipe puzzle ketiga: DSL kecil untuk puzzle logika gaya
Einstein (zebra).

### Fitur baru

- **Solver puzzle logika.** DSL kecil dan solver untuk puzzle logika gaya Einstein (zebra): rumah, kategori, dan enam tipe petunjuk (`eq`, `pos`, `nextto`, `leftof`, `immleft`, `notsame`).
- **`sphinx logic FILE`.** Menyelesaikan puzzle logika dan mencetak tabel yang rapi; `--count N` menghitung sampai N solusi.
- **Pelaporan `SolveStats`.** Solver logika melaporkan tebakan dan cabang yang dipangkas.

### Peningkatan

- **Aset logo.** Mark persegi ditambahkan dalam varian terang dan gelap; header README memakai elemen `<picture>` yang sadar dark mode.
- **Performa.** Propagasi baris nonogram digabung menjadi satu pass dengan early exit; demo nonogram acak 15x15 selesai dalam sekitar 130 ms.
- **Contoh.** `examples/zebra-einstein.txt` berisi puzzle zebra kecil dengan solusi unik.
- **Pengujian.** 45 contoh test termasuk test suite puzzle logika; semuanya hijau di GHC 9.6, 9.8 dan 9.10.

### Perbaikan bug

- **Digit Unicode.** Kedua parser kini menolak digit non-ASCII dengan error yang jelas, bukan menyimpan nilai di luar rentang atau crash.
- **Parser DSL logika.** Baris `category name: v1 ...` kini menerima spasi yang wajar (`name:` menyatu atau terpisah).

### Pemakaian

- `sphinx logic examples/zebra-einstein.txt` menyelesaikan puzzle zebra dan mencetak tabel.
- `sphinx logic examples/zebra-einstein.txt --count 2` mengecek keunikan.

## v0.1.0 - 2026-11-15

Rilis publik pertama.

### Fitur baru

- **Solver sudoku**: propagasi constraint (naked single, hidden
  single) lalu backtracking dengan heuristik minimum remaining values.
- **Solver nonogram**: line solving, propagasi constraint sampai
  fixpoint, dan backtracking pada baris/kolom dengan opsi paling sedikit.
- **Penjelasan langkah demi langkah** (`--steps`) untuk solusi sudoku.
- **Menghitung solusi** (`--count N`) untuk cek keunikan dan lainnya.
- **Generator puzzle** sudoku (`--generate easy|medium|hard`) dengan
  solusi unik yang dijamin, bisa diulang lewat `--seed`.
- **Typeclass `Puzzle`** sebagai antarmuka seragam library
  (`parsePuzzle`, `solveLimit`, `renderSolution`, `renderPuzzle`).

### Peningkatan

- Dokumentasi English dengan terjemahan Indonesia: instalasi, pemakaian,
  API library, format input, dan catatan algoritma.
- Property test (QuickCheck) dan golden test untuk renderer.
- CI di GitHub Actions: build dengan `-Werror` dan seluruh test suite
  pada GHC 9.6, 9.8 dan 9.10.

### Perbaikan bug

- Belum ada; ini rilis pertama.

### Pemakaian

- `sphinx sudoku examples/sudoku-easy.txt` menyelesaikan dan mencetak grid.
- `sphinx sudoku examples/sudoku-hard.txt --count 2` mengecek keunikan.
- `sphinx sudoku examples/sudoku-easy.txt --steps` mencetak langkah deduksi.
- `sphinx sudoku --generate hard --seed 42` membuat puzzle baru.
- `sphinx nonogram examples/nonogram-heart.txt` menampilkan gambar hasil.
