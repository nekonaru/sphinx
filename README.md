# Sphinx - Puzzle solver in Haskell

<img src="assets/logo.png" alt="Sphinx logo" width="640">

[![CI](https://github.com/nekonaru/sphinx/actions/workflows/ci.yml/badge.svg)](https://github.com/nekonaru/sphinx/actions/workflows/ci.yml)

Sphinx solves constraint-based puzzles. It is a Haskell library plus a
CLI that handles sudoku and nonogram puzzles today, explains how it
solved a sudoku step by step, and checks whether a puzzle has a unique
solution.

[Bahasa Indonesia](README.id.md) | English

## Features

- **Sudoku solver** with constraint propagation (naked singles, hidden
  singles) and backtracking with an MRV (minimum remaining values)
  heuristic.
- **Nonogram solver** with line solving, propagation to a fixpoint,
  and backtracking on the hardest line.
- **Step-by-step mode** (`--steps`) that prints every deduction the
  sudoku solver made, from naked singles to guesses.
- **Uniqueness check** (`--count 2`) to see whether a puzzle has
  exactly one solution.
- **Puzzle generator** for sudoku (`--generate easy|medium|hard`) that
  guarantees a unique solution.
- **Library API** through a single typeclass, so new puzzle types plug
  into the same interface.
- Property-based tests (QuickCheck) and golden tests for the renderers.

## Installation

Install GHC and cabal first (for example with
[ghcup](https://www.haskell.org/ghcup/)):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ghcup install ghc --set recommended
ghcup install cabal --set recommended
```

Then build and install Sphinx:

```sh
git clone https://github.com/nekonaru/sphinx.git
cd sphinx
cabal update
cabal install exe:sphinx
```

## Usage

Solve a sudoku and print the grid:

```sh
sphinx sudoku examples/sudoku-easy.txt
```

Check whether a puzzle is unique (exits 0; prints "2 or more
solution(s)" if not):

```sh
sphinx sudoku examples/sudoku-hard.txt --count 2
```

Print the deduction steps:

```sh
sphinx sudoku examples/sudoku-easy.txt --steps
```

Generate a new puzzle:

```sh
sphinx sudoku --generate hard --seed 42
```

Solve a nonogram and render it as a block image:

```sh
sphinx nonogram examples/nonogram-heart.txt
```

Every command also reads from standard input when you pass `-` as the
file name:

```sh
cat examples/sudoku-easy.txt | sphinx sudoku -
```

## Input formats

### Sudoku

One line of 81 characters, or 9 lines of 9 characters. `.` and `0`
mean empty, digits 1-9 are givens:

```
530070000600195000098000060800060003400803001700020006060000280000419005000080079
```

### Nonogram

Row clue lines, a separator line with `---`, then column clue lines.
Each clue is a space separated list of block lengths; `0` on a line
means that line is empty:

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

## Library usage

```haskell
import Sphinx.Class (Puzzle(..), firstSolution, isUnique)
import qualified Sphinx.Sudoku.Parse as Sudoku

main :: IO ()
main = case Sudoku.parseSudoku "530070000600195000098000060800060003400803001700020006060000280000419005000080079" of
  Left err -> putStrLn ("invalid puzzle: " ++ show err)
  Right grid -> do
    print (firstSolution grid)   -- first solution, if any
    print (isUnique grid)        -- True when exactly one solution exists
```

The `Puzzle` typeclass is the uniform interface over all puzzle types:

```haskell
class Puzzle p where
  type Solution p
  parsePuzzle    :: String -> Either SphinxError p
  solveLimit     :: Int -> p -> [Solution p]
  renderSolution :: p -> Solution p -> String
  renderPuzzle   :: p -> String
```

## Development

```sh
cabal build           # build library, CLI and tests
cabal test            # run hspec + QuickCheck + golden tests
```

The source tree follows the usual library + executable layout: `src/`
holds the library, `app/Main.hs` the CLI, `test/` the test suite and
`examples/` sample puzzles. See `docs/algorithms.md` for how the
solvers work.

## Performance

Measured on GHC 9.6 with `-O2` on a mid-range laptop: Arto Inkala's
puzzle (widely used as a hard benchmark) solves in well under a second.
Nonogram puzzles of typical 15x15 to 20x20 size solve in about the same
time. The solver counts up to N solutions lazily, so uniqueness checks
stop at the second solution.

## Contributing

Issues and pull requests are welcome. Please run `cabal test` before
submitting; CI enforces a warning-free build.

## License

[MIT](LICENSE) (c) 2026 nekonaru
