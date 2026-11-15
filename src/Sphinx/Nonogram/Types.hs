-- | Core types for nonogram (picross) puzzles.
--
-- A nonogram is a rectangular grid where every row and every column
-- carries a list of clues (the lengths of its consecutive filled
-- blocks, in order). A solution assigns every cell to filled or
-- empty such that all lines match their clues.
module Sphinx.Nonogram.Types
  ( Nonogram(..)
  , Solution(..)
  , clueSum
  , clueLineLength
  , gridRows
  , gridCols
  , filledCount
  , cellAt
  , setCell
  ) where

import qualified Data.Vector as V

-- | A puzzle instance. The shape is the number of row clue lists by
-- the number of column clue lists.
data Nonogram = Nonogram
  { rowClues :: [[Int]]
  , colClues :: [[Int]]
  } deriving (Eq, Show)

-- | A solved (or partially solved) grid, one row of booleans per row.
newtype Solution = Solution { unSolution :: V.Vector (V.Vector Bool) }
  deriving (Eq, Show)

-- | Sum of a clue list (number of filled cells in the line).
clueSum :: [Int] -> Int
clueSum = sum

-- | Minimum number of cells a clue list needs, blocks plus the
-- mandatory gaps between them.
clueLineLength :: [Int] -> Int
clueLineLength [] = 0
clueLineLength cs = sum cs + length cs - 1

gridRows :: Nonogram -> Int
gridRows = length . rowClues

gridCols :: Nonogram -> Int
gridCols = length . colClues

-- | Number of filled cells in a solution.
filledCount :: Solution -> Int
filledCount = sum . map (V.length . V.filter id) . V.toList . unSolution

-- | Read a cell (row, column, 0-based). Out-of-range reads as 'False'.
cellAt :: Solution -> Int -> Int -> Bool
cellAt (Solution rows) r c = case rows V.!? r of
  Nothing -> False
  Just row -> case row V.!? c of
    Nothing -> False
    Just v -> v

-- | Write a cell; out-of-range writes return the input unchanged.
setCell :: Solution -> Int -> Int -> Bool -> Solution
setCell (Solution rows) r c filled =
  case rows V.!? r of
    Nothing -> Solution rows
    Just row
      | c < 0 || c >= V.length row -> Solution rows
      | otherwise -> Solution (rows V.// [(r, row V.// [(c, filled)])])
