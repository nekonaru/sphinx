-- | Terminal rendering for sudoku grids.
module Sphinx.Sudoku.Render
  ( renderGrid
  , renderSteps
  ) where

import Data.List (intercalate)

import Sphinx.Sudoku.Solve (Step, renderStep)
import Sphinx.Sudoku.Types

-- | Render a grid as a boxed 9x9 board. Empty cells show as '.'.
renderGrid :: Grid -> String
renderGrid g = intercalate "\n" (concat [border, rowLines 0, border, rowLines 3, border, rowLines 6, border])
  where
    cell i = case getCell g i of
      0 -> "."
      d -> show d
    border = ["+-------+-------+-------+"]
    rowLines start =
      [ "|" ++ intercalate "|" [ colLine r c | c <- [0, 3, 6] ] ++ "|"
      | r <- [start, start + 1, start + 2] ]
    colLine r c = " " ++ cell (r * 9 + c) ++ " " ++ cell (r * 9 + c + 1) ++ " " ++ cell (r * 9 + c + 2) ++ " "

-- | Render the numbered steps collected by @--steps@.
renderSteps :: [Step] -> String
renderSteps steps =
  intercalate "\n" $
    [ "Solving steps:" ] ++
    [ renderStep (i + 1) st | (i, st) <- zip [0 ..] steps ] ++
    [ "Done. " ++ show (length steps) ++ " step(s)." ]
