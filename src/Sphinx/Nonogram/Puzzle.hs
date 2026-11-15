-- | Uniform 'Puzzle' interface for nonograms.
module Sphinx.Nonogram.Puzzle
  (
  ) where

import Sphinx.Class (Puzzle(..))
import qualified Sphinx.Nonogram.Render as NRender
import Sphinx.Nonogram.Parse (parseNonogram)
import Sphinx.Nonogram.Solve (solveUpTo)
import Sphinx.Nonogram.Types (Nonogram, Solution)

instance Puzzle Nonogram where
  type Solution Nonogram = Solution
  parsePuzzle = parseNonogram
  solveLimit = solveUpTo
  renderSolution puzzle sol = NRender.renderSolution puzzle sol
  renderPuzzle = NRender.renderPuzzle
