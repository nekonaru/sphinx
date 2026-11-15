{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- | Uniform 'Puzzle' interface for logic puzzles.
--
-- The instance lives here, in its own module, to keep the solver
-- modules free of interface plumbing. The orphan warning is relaxed
-- for this reason.
module Sphinx.Logic.Puzzle
  (
  ) where

import Sphinx.Class (Puzzle(..))
import qualified Sphinx.Logic.DSL as DSL
import qualified Sphinx.Logic.Render as LRender

instance Puzzle DSL.LogicPuzzle where
  type Solution DSL.LogicPuzzle = DSL.LogicSolution
  parsePuzzle = DSL.parseLogic
  solveLimit = DSL.solveLimit
  renderSolution puzzle sol = LRender.renderSolution puzzle sol
  renderPuzzle = LRender.renderPuzzle
