# Changelog

All notable changes to this project are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-15

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
  on GHC 9.6 and 9.10.

### Bug fixes

- None yet; this is the first release.
