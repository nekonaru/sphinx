{-# LANGUAGE TypeFamilies #-}

-- | The puzzle typeclass every Sphinx puzzle implements.
--
-- A puzzle is a parsed, validated value. Solving it is pure: the
-- same puzzle always yields the same solutions, and no I/O happens
-- anywhere in the library.
module Sphinx.Class
  ( Puzzle(..)
  , firstSolution
  , isUnique
  ) where

import Data.Maybe (listToMaybe)

import Sphinx.Error (SphinxError)

class Puzzle p where
  -- | The solution type produced by the solver.
  type Solution p

  -- | Parse and validate a puzzle from its textual representation.
  parsePuzzle :: String -> Either SphinxError p

  -- | Find up to @n@ solutions. Pass @'maxBound'@ for all of them
  -- (only sensible for puzzles with few solutions).
  solveLimit :: Int -> p -> [Solution p]

  -- | Render a puzzle with its givens replaced by the solution.
  renderSolution :: p -> Solution p -> String

  -- | Render the puzzle as given, without solving it.
  renderPuzzle :: p -> String

-- | Solve a puzzle and return the first solution, if any.
firstSolution :: Puzzle p => p -> Maybe (Solution p)
firstSolution = listToMaybe . solveLimit 1

-- | Check whether a puzzle has exactly one solution.
isUnique :: Puzzle p => p -> Bool
isUnique p = case solveLimit 2 p of
  [_] -> True
  _ -> False
