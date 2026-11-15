-- | Core types for the 9x9 sudoku puzzle.
--
-- A 'Grid' is an 81 cell vector of values 0-9 where 0 means empty.
-- Row and column indices are 0-based.
module Sphinx.Sudoku.Types
  ( Grid(..)
  , emptyGrid
  , getCell
  , setCell
  , rowIndex
  , colIndex
  , boxIndex
  , peers
  , unitNames
  , units
  , isSolved
  ) where

import Data.List (nub, sort)
import Data.Vector (Vector)
import qualified Data.Vector as V

-- | The puzzle grid. Invariant: 'unGrid' has length 81 and every
-- element is in the range 0-9. Construct grids with
-- 'Sphinx.Sudoku.Parse.parseSudoku' or 'emptyGrid' instead of by hand.
newtype Grid = Grid { unGrid :: Vector Int }
  deriving (Eq, Show)

-- | An empty 9x9 grid.
emptyGrid :: Grid
emptyGrid = Grid (V.replicate 81 0)

-- | Read the cell at a 0-based position. Positions outside 0-80
-- are treated as empty cells never touched by the solver.
getCell :: Grid -> Int -> Int
getCell (Grid v) i
  | i >= 0 && i < 81 = v V.! i
  | otherwise = 0

-- | Return a copy of the grid with the given cell set.
setCell :: Int -> Int -> Grid -> Grid
setCell i d (Grid v) = Grid (v V.// [(i, d)])

-- | 0-based row of a cell position.
rowIndex :: Int -> Int
rowIndex i = i `div` 9

-- | 0-based column of a cell position.
colIndex :: Int -> Int
colIndex i = i `mod` 9

-- | 0-based 3x3 box index (0-8, row major).
boxIndex :: Int -> Int
boxIndex i = (rowIndex i `div` 3) * 3 + colIndex i `div` 3

-- | Human readable names for the 27 units, used in error messages.
unitNames :: Vector String
unitNames = V.fromList $
  [ "row " ++ show (r + 1) | r <- [0 .. 8] ] ++
  [ "column " ++ show (c + 1) | c <- [0 .. 8] ] ++
  [ "box " ++ show (b + 1) | b <- [0 .. 8] ]

-- | All 27 units as lists of cell positions. Rows first, then
-- columns, then boxes. Aligns with 'unitNames'.
units :: Vector [Int]
units = V.fromList $
  [ [ r * 9 + c | c <- [0 .. 8] ] | r <- [0 .. 8] ] ++
  [ [ r * 9 + c | r <- [0 .. 8] ] | c <- [0 .. 8] ] ++
  [ [ (br * 3 + dr) * 9 + bc * 3 + dc | dr <- [0 .. 2], dc <- [0 .. 2] ]
  | br <- [0 .. 2], bc <- [0 .. 2] ]

-- | Peer positions for every cell: the other 20 cells in the same
-- row, column, or box, sorted and deduplicated.
peers :: Vector [Int]
peers = V.fromList
  [ sort (nub [ j | u <- V.toList units, i `elem` u, j <- u, j /= i ]) | i <- [0 .. 80] ]

-- | True when every cell is filled and every unit holds 1-9.
isSolved :: Grid -> Bool
isSolved g
  | any (\i -> getCell g i == 0) [0 .. 80] = False
  | otherwise = all unitOk (V.toList units)
  where
    unitOk u = sort [ getCell g i | i <- u ] == [1 .. 9]
