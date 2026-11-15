# Changelog

All notable changes to this project are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/).

## v0.2.0 - 2026-11-16

Sphinx grows a third puzzle type: a small Einstein (zebra) puzzle DSL.

### New features

- **Logic puzzle solver.** A small DSL and solver for zebra (Einstein) style logic puzzles: houses, categories, and six clue types (`eq`, `pos`, `nextto`, `leftof`, `immleft`, `notsame`).
- **`sphinx logic FILE`.** Solve a logic puzzle and print the aligned table; `--count N` counts up to N solutions.
- **`SolveStats` reporting.** The logic solver reports guesses and pruned branches.

### Improvements

- **Logo assets.** Square mark added in light and dark variants; the README header uses a dark-mode aware `<picture>` element.
- **Performance.** Nonogram line propagation fused into a single pass with early exit; a 15x15 random demo nonogram solves in about 130 ms.
- **Examples.** `examples/zebra-einstein.txt` ships a small, uniquely solvable zebra puzzle.
- **Testing.** 45 test examples including the logic puzzle suite; everything green on GHC 9.6, 9.8 and 9.10.

### Bug fixes

- **Unicode digits.** Both parsers now reject non-ASCII digits with a clear error instead of storing out-of-range values or crashing.
- **Logic DSL parser.** The `category name: v1 ...` line now accepts the natural spacing (`name:` attached or detached).

### Usage

- `sphinx logic examples/zebra-einstein.txt` solves the zebra puzzle and prints the table.
- `sphinx logic examples/zebra-einstein.txt --count 2` checks uniqueness.

## v0.1.0 - 2026-11-15

First public release.

### New features

- **Sudoku solver**: constraint propagation (naked singles, hidden
  singles) plus backtracking with a minimum remaining values heuristic.
- **Nonogram solver**: line solving, constraint propagation to a
  fixpoint, and backtracking on the line with the fewest options.
- **Step-by-step explanations** (`--steps`) for sudoku solves.
- **Solution counting** (`--count N`) for uniqueness checks and more.
- **Puzzle generator** for sudoku (`--generate easy|medium|hard`) with
  a guaranteed unique solution, reproducible via `--seed`.
- **`Puzzle` typeclass** as the uniform library interface
  (`parsePuzzle`, `solveLimit`, `renderSolution`, `renderPuzzle`).

### Improvements

- English documentation with an Indonesian translation: installation,
  usage, library API, input formats, and algorithm notes.
- Property-based tests (QuickCheck) and golden tests for the renderers.
- CI on GitHub Actions: build with `-Werror` and the full test suite
  on GHC 9.6, 9.8 and 9.10.

### Bug fixes

- None yet; this is the first release.

### Usage

- `sphinx sudoku examples/sudoku-easy.txt` solves and prints the grid.
- `sphinx sudoku examples/sudoku-hard.txt --count 2` checks uniqueness.
- `sphinx sudoku examples/sudoku-easy.txt --steps` prints the deduction steps.
- `sphinx sudoku --generate hard --seed 42` generates a new puzzle.
- `sphinx nonogram examples/nonogram-heart.txt` renders the solved image.
