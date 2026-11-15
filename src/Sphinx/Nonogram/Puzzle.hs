{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- | Uniform 'Puzzle' interface for nonograms.
--
-- The instance lives here, in its own module, to keep the solver
-- modules free of interface plumbing. The orphan warning is relaxed
-- for this reason.
module Sphinx.Nonogram.Puzzle
  (
  ) where

import Sphinx.Class (Puzzle(..))
import qualified Sphinx.Nonogram.Render as NRender
import Sphinx.Nonogram.Parse (parseNonogram)
import Sphinx.Nonogram.Solve (solveUpTo)
import qualified Sphinx.Nonogram.Types as NT

instance Puzzle NT.Nonogram where
  type Solution NT.Nonogram = NT.Solution
  parsePuzzle = parseNonogram
  solveLimit = solveUpTo
  renderSolution puzzle sol = NRender.renderSolution puzzle sol
  renderPuzzle = NRender.renderPuzzle
