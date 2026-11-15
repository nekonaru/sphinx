-- | Uniform 'Puzzle' interface for sudoku grids.
module Sphinx.Sudoku.Puzzle
  (
  ) where

import Sphinx.Class (Puzzle(..))
import Sphinx.Sudoku.Parse (parseSudoku)
import Sphinx.Sudoku.Render (renderGrid)
import Sphinx.Sudoku.Solve (solveUpTo)
import Sphinx.Sudoku.Types (Grid)

instance Puzzle Grid where
  type Solution Grid = Grid
  parsePuzzle = parseSudoku
  solveLimit = solveUpTo
  renderSolution _ = renderGrid
  renderPuzzle = renderGrid
