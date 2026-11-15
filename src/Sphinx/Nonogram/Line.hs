-- | Line solver for nonograms.
--
-- For one line of length @n@ with clues @cs@, 'arrangements' enumerates
-- every filling that satisfies the clues. Line lengths in real
-- nonograms are small (at most a few dozen cells), so plain recursive
-- enumeration is fast enough and keeps the code simple.
module Sphinx.Nonogram.Line
  ( arrangements
  , lineOptions
  ) where

import Sphinx.Nonogram.Types (clueLineLength)

-- | All fillings of a line that satisfy the clues.
arrangements :: Int -> [Int] -> [[Bool]]
arrangements n cs = go n cs
  where
    go m [] = [replicate m False]
    go m (c:rest)
      | c <= 0 = []
      | otherwise =
          [ replicate k False ++ replicate c True ++ suffix
          | k <- [0 .. m - clueLineLength (c:rest)]
          , suffix <- case rest of
              [] -> [replicate (m - k - c) False]
              _  -> map (False :) (go (m - k - c - 1) rest)
          ]

-- | All options for one line of a puzzle, given the currently known
-- cells ('Just True' filled, 'Just False' empty, 'Nothing' unknown).
lineOptions :: Int -> [Int] -> [Maybe Bool] -> [[Bool]]
lineOptions len clues known =
  [ line
  | line <- arrangements len clues
  , consistent line known
  ]

consistent :: [Bool] -> [Maybe Bool] -> Bool
consistent line known = and (zipWith fits line known)
  where
    fits actual m = case m of
      Nothing -> True
      Just expected -> actual == expected
