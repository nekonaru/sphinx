{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- | Uniform 'Puzzle' interface for sudoku grids.
--
-- The instance lives here, in its own module, to keep the solver
-- modules free of interface plumbing. The orphan warning is relaxed
-- for this reason.
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
