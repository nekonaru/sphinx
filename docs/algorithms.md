# Algorithms

How Sphinx solves puzzles, and why.

## Sudoku

**Constraint propagation + backtracking with MRV.**

The solver works on an 81-cell grid where `0` means empty. Instead of
searching blindly, it first deduces everything it can for free:

1. **Candidate sets.** A cell's candidates are the digits not already
   placed in its row, column, or 3x3 box. They are stored as a 9-bit
   mask in an `Int`, so membership tests are bit operations.
2. **Naked singles.** If a cell has exactly one candidate left, that
   digit is placed.
3. **Hidden singles.** For each unit (row, column, box) and each
   digit, if that digit fits in exactly one cell of the unit, it is
   placed there.
4. Steps 2-3 repeat until nothing changes (a **fixpoint**). If an
   empty cell is left with no candidates, the branch is a dead end.
5. If the puzzle is still incomplete, the solver picks the empty cell
   with the fewest remaining candidates (**minimum remaining values**,
   MRV) and tries each candidate in turn. This keeps the search tree
   as small as possible.

Uniqueness checking (`--count 2`) is just `solveLimit 2`: the search
is lazy, so it stops as soon as two solutions are known.

The `--steps` mode records each deduction as a value of the `Step` ADT
(`NakedSingle`, `HiddenSingle`, `Guess`) and renders the list after
the solve.

**Generation** is the inverse process. First a full valid grid is
built by backtracking with a shuffled digit order (seeded splitmix64
PRNG). Then holes are dug in a shuffled cell order; a digit is only
removed when `solveLimit 2` still proves the puzzle has one solution.
This guarantees every generated puzzle is uniquely solvable.

## Nonogram

**Line solving + fixpoint propagation + branch and bound.**

Cells are `Maybe Bool` (`Nothing` = unknown). For a single line of
length `n` with clues `cs`:

1. **Enumerate** all valid fillings by recursion over the clue list,
   pruning offsets that cannot fit (`0 <= k <= m - sum(cs) - len(cs) + 1`).
2. **Filter** the enumeration by the cells already known. If every
   remaining filling fills (or empties) the same cell, that cell
   becomes known.

The whole puzzle repeats this for every row and column until no cell
changes. Then, if the board is still incomplete, it branches on the
line with the fewest remaining options. Lines with zero options prove
the branch is a dead end. Options hang off a lazy search, so `--count
N` never computes more than it needs.

**Example.** A row clue `2 1` on a length 6 line has three fillings:
`##.#..`, `.##.#.`, `..##.#`. If the first column of that row is
already known to be empty, the first filling is eliminated; if the
last column is known empty, only `##.#..` survives, and the row
collapses completely.

## Why these designs

- **Immutability everywhere** makes solvers composable and testable:
  no shared mutable grid, no hidden state.
- **Bitmasks** keep candidate operations O(1) for the 81-cell sudoku
  case.
- **Laziness** (`[Solution]`) gives bounded counting for free.
- The typeclass `Puzzle` (`parsePuzzle`, `solveLimit`,
  `renderSolution`, `renderPuzzle`) is the single extension point for
  new puzzle types.
